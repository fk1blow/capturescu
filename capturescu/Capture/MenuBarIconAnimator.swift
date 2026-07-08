//
//  MenuBarIconAnimator.swift
//  capturescu
//
//  Draws the menu-bar icon in code and animates the underline in response to how
//  a capture session ended:
//
//    • .copied    — the annotated shot landed on the clipboard. The line does a
//                   quick wind-up (snaps in to a dot), springs out past full with
//                   overshoot, then a smaller echo bounce. Rendered in coral —
//                   the one moment colour is earned. A confident "captured!".
//    • .dismissed — the editor closed without a copy. A slow, small "sigh": the
//                   line dims, narrows a touch and sinks, holds, then quietly
//                   recovers. Monochrome, a soft downward settle — reads as "aww,
//                   no biggie", the opposite register from the copy spring.
//
//  Colour policy (per Apple's menu-bar guidance): the icon is **monochrome at
//  rest**. The resting and dismiss frames are emitted as a *template* image
//  (`isTemplate = true`) — a monochrome mask the system tints, inverts on the
//  click-highlight, and dims when the app is inactive, exactly like the native
//  menu-bar glyphs. Colour appears only during the copy animation, where it
//  signals a successful outcome; those frames are non-template so the coral
//  survives, with the C tinted to match the menu bar by hand.
//
//  We draw rather than swap in the static asset so every state shares one
//  geometry — rest, copy and dismiss start and settle on the exact same frame,
//  with no position jump when an animation begins or ends.
//

import AppKit
import QuartzCore

/// How an annotation session ended — drives which icon animation plays.
enum CaptureOutcome {
    case copied
    case dismissed
}

@MainActor
final class MenuBarIconAnimator {
    private weak var button: NSStatusBarButton?

    /// The baked asset (C + red line). We only draw its C glyph; the line is
    /// clipped out and redrawn live.
    private let sourceIcon: NSImage?

    // Geometry in the icon's 18pt coordinate space (bottom-left origin). Values
    // derived from the 54px (@3x) artwork: the C sits in the upper band, the line
    // in the lower ~15%, with a clear transparent gap between them.
    private let iconSize = NSSize(width: 18, height: 18)
    /// Clip line for the C: keep everything above the gap, drop the baked line.
    private let cBandMinY: CGFloat = 5.5
    private let lineCenter = CGPoint(x: 9.0, y: 3.3)
    private let fullLineWidth: CGFloat = 14.3
    private let lineHeight: CGFloat = 2.6
    private let accent = NSColor(srgbRed: 0.917, green: 0.399, blue: 0.233, alpha: 1.0)

    private var timer: Timer?
    private var animation: Keyframes?
    private var startTime: CFTimeInterval = 0
    /// The line colour for the running animation: coral for copy, `nil` for
    /// dismiss (and rest), where `nil` means "render as a monochrome template".
    private var currentLineColor: NSColor?

    init(button: NSStatusBarButton) {
        self.button = button
        self.sourceIcon = NSImage(named: "MenuBarIcon")
        installThemeObserver()
        renderIdle()
    }

    // MARK: - Public

    /// Play the animation for how the session ended. Interrupts any in-flight one.
    func play(_ outcome: CaptureOutcome) {
        switch outcome {
        case .copied:
            currentLineColor = accent          // colour is earned by success
            start(.copied)
        case .dismissed:
            currentLineColor = nil             // stay monochrome
            start(.dismissed)
        }
    }

    /// The resting icon: monochrome template (full line), so the system tints,
    /// highlights and dims it like a native glyph. Re-rendered on appearance flips.
    func renderIdle() {
        setImage(lineFraction: 1, lineOpacity: 1, lineDropY: 0, lineColor: nil)
    }

    // MARK: - Rendering

    /// - Parameters:
    ///   - lineFraction: line width as a fraction of full (0 collapses to a dot).
    ///   - lineOpacity: line opacity.
    ///   - lineDropY: vertical offset in points; negative sinks the line (used by
    ///     the dismiss "sigh").
    ///   - lineColor: the line's colour, or `nil` to emit a monochrome *template*
    ///     image (the whole glyph becomes a mask the system tints). `nil` is used
    ///     for rest and dismiss; coral is passed for the copy animation.
    private func setImage(lineFraction: CGFloat, lineOpacity: CGFloat, lineDropY: CGFloat, lineColor: NSColor?) {
        guard let button else { return }

        let template = lineColor == nil
        // Template: draw the whole glyph opaque black — only the alpha mask matters,
        // the system supplies the colour. Non-template: tint the C to the menu bar
        // by hand so the coral line reads against it.
        let cFill: NSColor = template ? .black : glyphTint(for: button)
        let lineFill: NSColor = lineColor ?? .black

        // Capture everything the drawing handler needs so it stays a pure closure.
        let source = sourceIcon
        let size = iconSize
        let cBandMinY = cBandMinY
        let center = lineCenter
        let fullW = fullLineWidth
        let h = lineHeight

        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current else { return true }

            // --- The C: draw the source clipped to its band, then tint it in place
            // with .sourceAtop so only the glyph's opaque pixels take the colour. ---
            if let source {
                ctx.saveGraphicsState()
                let cBand = NSRect(x: 0, y: cBandMinY,
                                   width: size.width, height: size.height - cBandMinY)
                NSBezierPath(rect: cBand).setClip()
                source.draw(in: NSRect(origin: .zero, size: size))
                ctx.compositingOperation = .sourceAtop
                cFill.setFill()
                NSBezierPath(rect: cBand).fill()
                ctx.restoreGraphicsState()
            }

            // --- The line: a capsule whose width tracks `lineFraction` (fraction 0
            // collapses to a dot: width == height == a circle). In template mode the
            // opacity becomes mask alpha, so the system dims the line for us. ---
            ctx.saveGraphicsState()
            ctx.compositingOperation = .sourceOver
            let w = max(h, lineFraction * fullW)
            let rect = NSRect(x: center.x - w / 2, y: center.y - h / 2 + lineDropY, width: w, height: h)
            let path = NSBezierPath(roundedRect: rect, xRadius: h / 2, yRadius: h / 2)
            lineFill.withAlphaComponent(lineOpacity).setFill()
            path.fill()
            ctx.restoreGraphicsState()

            return true
        }
        image.isTemplate = template
        image.accessibilityDescription = "Capturescu"
        button.image = image
    }

    /// The colour the system tints a template glyph to at rest, resolved for the
    /// button's appearance. Used to hand-tint the C (and the line's fade target) on
    /// the non-template copy frames, so the C matches the template rest image and
    /// the copy→rest handoff shows no jump. `labelColor` — not pure black/white —
    /// is what the menu bar actually renders template icons as.
    private func glyphTint(for button: NSStatusBarButton) -> NSColor {
        var resolved = NSColor.labelColor
        button.effectiveAppearance.performAsCurrentDrawingAppearance {
            resolved = NSColor.labelColor.usingColorSpace(.sRGB) ?? NSColor.labelColor
        }
        return resolved
    }

    // MARK: - Animation loop

    private func start(_ frames: Keyframes) {
        timer?.invalidate()
        animation = frames
        startTime = CACurrentMediaTime()
        tick() // render the first frame now, don't wait a tick

        // .common mode so the icon keeps animating even while a menu is tracking.
        let t = Timer(timeInterval: 1.0 / 60.0, target: self,
                      selector: #selector(tickTimer), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func tickTimer() { tick() }

    /// A short tail that fades the coral line to the monochrome tint after a copy
    /// finishes, so colour dissolves back to the resting glyph instead of snapping.
    /// Zero for dismiss, which is already monochrome.
    private let colorFadeOut: CFTimeInterval = 0.18

    private func tick() {
        guard let animation, let button else { return }
        let elapsed = CACurrentMediaTime() - startTime
        // Only the copy path (coloured) needs a fade back to monochrome.
        let fade = currentLineColor == nil ? 0 : colorFadeOut

        if elapsed >= animation.duration + fade {
            self.animation = nil
            timer?.invalidate()
            timer = nil
            renderIdle() // settle exactly on the resting (template) frame
            return
        }

        if elapsed < animation.duration {
            let frame = animation.sample(elapsed)
            setImage(lineFraction: frame.fraction, lineOpacity: frame.opacity,
                     lineDropY: frame.dy, lineColor: currentLineColor)
        } else if let coral = currentLineColor {
            // Fade tail: hold the settled full line, cross-fade coral -> mono tint.
            let p = CGFloat((elapsed - animation.duration) / fade)
            let mono = glyphTint(for: button)
            setImage(lineFraction: 1, lineOpacity: 1, lineDropY: 0,
                     lineColor: blend(coral, mono, easeOut(p)))
        }
    }

    /// Linear RGBA interpolation between two colours (in sRGB).
    private func blend(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
        guard let a = a.usingColorSpace(.sRGB), let b = b.usingColorSpace(.sRGB) else { return a }
        let t = max(0, min(1, t))
        return NSColor(srgbRed: a.redComponent + (b.redComponent - a.redComponent) * t,
                       green: a.greenComponent + (b.greenComponent - a.greenComponent) * t,
                       blue: a.blueComponent + (b.blueComponent - a.blueComponent) * t,
                       alpha: a.alphaComponent + (b.alphaComponent - a.alphaComponent) * t)
    }

    // MARK: - Appearance

    private func installThemeObserver() {
        DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.animation == nil else { return }
                self.renderIdle()
            }
        }
    }
}

// MARK: - Keyframes

/// A time-parameterised animation: `sample(t)` gives the line's width fraction
/// (0 = dot, 1 = full), opacity, and vertical drop (points, negative = down) at
/// elapsed time `t`, up to `duration`.
private struct Keyframes {
    let duration: CFTimeInterval
    let sample: (CFTimeInterval) -> (fraction: CGFloat, opacity: CGFloat, dy: CGFloat)

    /// Success: quick wind-up to a dot, then spring out past full — then a second,
    /// smaller echo bounce that dips to ~60% and springs back. A decaying double
    /// bounce (energy fading like a real bounce), snappy and horizontal — a
    /// confident "captured!".
    static let copied = Keyframes(duration: 0.90) { t in
        let windUp = 0.10
        let firstEnd = 0.52
        let floor: CGFloat = 0.45   // shortest the line gets — a stub, never a dot
        if t < windUp {
            let p = easeIn(CGFloat(t / windUp))
            return (1 - (1 - floor) * p, 1, 0)               // full -> floor
        }
        if t < firstEnd {
            let p = CGFloat((t - windUp) / (firstEnd - windUp))
            return (floor + (1 - floor) * backOut(p, s: 2.6), 1, 0) // floor -> big overshoot -> full
        }
        // Echo: a shallower, lower-energy second bounce.
        let p = min(1, CGFloat((t - firstEnd) / (0.90 - firstEnd)))
        let dip: CGFloat = 0.70
        if p < 0.35 {
            let q = easeOut(p / 0.35)
            return (1 - (1 - dip) * q, 1, 0)              // full -> 0.70
        }
        let q = CGFloat((p - 0.35) / (1 - 0.35))
        return (dip + (1 - dip) * backOut(q, s: 1.1), 1, 0) // 0.70 -> small overshoot -> full
    }

    /// Dismiss: a slow, small "sigh". The line dims, narrows to ~0.55 and sinks
    /// ~1pt, holds a beat, then softly settles back with an ease-in-out (no snap,
    /// no overshoot, no dot). Half the energy of copy, on a different axis.
    static let dismissed = Keyframes(duration: 0.70) { t in
        let sink = 0.26, hold = 0.36, dur = 0.70
        let drop: CGFloat = -2.0
        let minFraction: CGFloat = 0.55
        let minOpacity: CGFloat = 0.40
        if t < sink {
            let p = easeOut(CGFloat(t / sink))
            return (1 - (1 - minFraction) * p,
                    1 - (1 - minOpacity) * p,
                    drop * p)                            // ease down into the sigh
        } else if t < hold {
            return (minFraction, minOpacity, drop)       // linger, deflated
        }
        let p = easeInOut(CGFloat((t - hold) / (dur - hold)))
        return (minFraction + (1 - minFraction) * p,
                minOpacity + (1 - minOpacity) * p,
                drop * (1 - p))                          // quietly recover
    }
}

// Easing helpers (normalised t in 0...1).
private func easeIn(_ t: CGFloat) -> CGFloat { t * t * t }
private func easeOut(_ t: CGFloat) -> CGFloat { 1 - pow(1 - t, 3) }
/// Slow-in, slow-out — gives the dismiss recovery its un-energetic, settling feel.
private func easeInOut(_ t: CGFloat) -> CGFloat {
    t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
}
/// Overshoot ease: rises past 1 near the end, then settles back to 1. Larger `s`
/// overshoots more.
private func backOut(_ t: CGFloat, s: CGFloat) -> CGFloat {
    let u = t - 1
    return u * u * ((s + 1) * u + s) + 1
}
