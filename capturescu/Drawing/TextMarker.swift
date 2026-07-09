//
//  TextMarker.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI
import AppKit
import CoreText

/// Single source of truth for the text-marker font, shared by the inline
/// editor, the on-canvas draw, size measurement, and the PNG exporter. Keeping
/// one definition guarantees the input field, the on-screen marker, and the
/// exported image all use identical metrics.
enum TextMarkerFont {
    /// Default point size for a freshly placed text marker. The actual size is
    /// stored per-marker so different markers can carry different sizes.
    static let defaultSize: CGFloat = 16

    /// Weight shared by the editor, on-canvas draw, and export. Semibold so
    /// annotations stay legible on top of busy screenshots (which carry their
    /// own UI text) instead of blending in. Keep the AppKit and SwiftUI weights
    /// in sync — dial both back to `.medium`/`.regular` together if too heavy.
    static let weight: NSFont.Weight = .semibold
    static let swiftUIWeight: Font.Weight = .semibold

    /// The system font on macOS is San Francisco (SF Pro), which also auto-picks
    /// the right optical variant (Text vs Display) for `size`.
    static func nsFont(size: CGFloat = defaultSize) -> NSFont { .systemFont(ofSize: size, weight: weight) }
    static func swiftUIFont(size: CGFloat = defaultSize) -> Font { .system(size: size, weight: swiftUIWeight) }
    /// NSFont and CTFont are toll-free bridged, so the exporter renders the
    /// exact same face as the on-screen SwiftUI text.
    static func ctFont(size: CGFloat = defaultSize) -> CTFont { nsFont(size: size) as CTFont }

    /// The maximum width a text marker wraps at before adding a new line.
    static let maxWidth: CGFloat = 280

    /// Convert the soft-wrapping the user saw in the inline editor into explicit
    /// line breaks. The editor's `TextField` wraps text visually at `maxWidth`
    /// but leaves the underlying string on a single line, so the committed marker
    /// would otherwise "unwrap" when drawn at its natural width. We re-run the
    /// same font (at `size`) + `maxWidth` layout Core Text uses (matching the
    /// editor and `measureSize`) and insert real newlines at the break points, so
    /// the on-canvas draw and the PNG export — both of which honor explicit `\n` —
    /// reproduce exactly what was on screen while typing.
    ///
    /// Any newlines the user typed explicitly are preserved: Core Text treats
    /// them as paragraph breaks and simply wraps each paragraph in turn.
    static func hardWrapped(_ text: String, size: CGFloat = defaultSize) -> String {
        guard !text.isEmpty else { return text }

        let attributed = NSAttributedString(string: text, attributes: [.font: nsFont(size: size)])
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        // A very tall box so wrapping is driven purely by width, never height.
        let path = CGPath(
            rect: CGRect(x: 0, y: 0, width: maxWidth, height: 1_000_000),
            transform: nil
        )
        let frame = CTFramesetterCreateFrame(
            framesetter, CFRange(location: 0, length: 0), path, nil
        )
        guard let ctLines = CTFrameGetLines(frame) as? [CTLine], !ctLines.isEmpty else {
            return text
        }

        let ns = text as NSString
        var lines: [String] = []
        for line in ctLines {
            let range = CTLineGetStringRange(line)
            guard range.length > 0 else { continue }
            var substring = ns.substring(
                with: NSRange(location: range.location, length: range.length)
            )
            // A line ending on an explicit newline includes that newline in its
            // range; drop it so re-joining with "\n" doesn't double it up.
            if substring.hasSuffix("\n") {
                substring.removeLast()
            }
            lines.append(substring)
        }
        return lines.joined(separator: "\n")
    }

    /// Measured bounds for `text` laid out in the marker font at `size`. Only the
    /// size is returned; the caller supplies the origin. A small padding and a
    /// minimum size keep the hit box / highlight comfortable for short or empty text.
    static func measureSize(of text: String, size: CGFloat = defaultSize) -> CGSize {
        let attributed = NSAttributedString(string: text, attributes: [.font: nsFont(size: size)])
        let bounds = attributed.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return CGSize(
            width: max(ceil(bounds.width) + 4, 20),
            height: max(ceil(bounds.height) + 4, 16)
        )
    }
}

struct TextMarker: Marker {
    var id = UUID()

    var style: MarkerStyle
    var isHighlighted: Bool = false
    var isHovered: Bool = false

    var textValueRepresentation: String = ""
    var frameRepresentation: CGRect = .zero
    /// Point size for this marker's text, captured at creation so each marker
    /// keeps its own size independent of the current tool setting.
    var fontSize: CGFloat = TextMarkerFont.defaultSize

    init(markerColor: MarkerColor, textValue: String, frame: CGRect, fontSize: CGFloat = TextMarkerFont.defaultSize) {
        style = MarkerStyle(strokeColor: markerColor)
        textValueRepresentation = textValue
        frameRepresentation = frame
        self.fontSize = fontSize
    }

    init(markerColor: MarkerColor) {
        self.init(markerColor: markerColor, textValue: "", frame: .zero)
    }

    /// Build a marker for `text` anchored at `origin` (top-left, canvas space).
    /// The frame size is measured from the text at `fontSize` so the hit box
    /// matches what is drawn.
    init(markerColor: MarkerColor, textValue: String, origin: CGPoint, fontSize: CGFloat = TextMarkerFont.defaultSize) {
        let size = TextMarkerFont.measureSize(of: textValue, size: fontSize)
        self.init(
            markerColor: markerColor,
            textValue: textValue,
            frame: CGRect(origin: origin, size: size),
            fontSize: fontSize
        )
    }

    func draw(onto ctx: GraphicsContext) {
        let text = Text(verbatim: textValueRepresentation).font(TextMarkerFont.swiftUIFont(size: fontSize))
        var resolvedText = ctx.resolve(text)
        resolvedText.shading = .color(style.strokeColor.color)
        // Anchor at the frame's top-left using the text's natural size (no
        // scaling), so the rendered glyphs sit exactly where the inline editor
        // placed them.
        ctx.draw(resolvedText, at: frameRepresentation.origin, anchor: .topLeading)

        drawHighlight(onto: ctx)
        drawHoverHighlight(onto: ctx)
    }

    func changeStyle(with _: MarkerStyle) {
        // TODO:
    }

    func getRepresentation() -> MarkerRepresentation {
        return MarkerRepresentation.text(
            TextMarkerRepresentation(frame: frameRepresentation, text: textValueRepresentation, fontSize: fontSize)
        )
    }

    func markerBoundingBox(near location: CGPoint) -> BoundingBox? {
        return HitDetectionManager.shared.isPointNearRect(location, rect: frameRepresentation)
    }

    mutating func offsetMarkerBy(dx: CGFloat, dy: CGFloat) {
        frameRepresentation = frameRepresentation.offsetBy(dx: dx, dy: dy)
    }
}
