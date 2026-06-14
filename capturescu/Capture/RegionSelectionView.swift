//
//  RegionSelectionView.swift
//  capturescu
//
//  Full-screen overlay shown after the screen has been frozen. Displays the
//  frozen capture dimmed, with a live, un-dimmed selection rectangle the user
//  drags out. Reports the selection in top-left view points (matching the
//  CGImage's pixel orientation once multiplied by the backing scale).
//

import SwiftUI
import AppKit

struct RegionSelectionView: View {
    let image: CGImage
    let scale: CGFloat
    let onComplete: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var startPoint: CGPoint?
    @State private var selection: CGRect = .zero

    private var hasSelection: Bool {
        selection.width > 0 && selection.height > 0
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Frozen screen at its natural point size.
            Image(decorative: image, scale: scale)
                .resizable()
                .ignoresSafeArea()

            // Dim everything except the current selection (even-odd cut-out).
            Canvas { ctx, size in
                var dimmed = Path(CGRect(origin: .zero, size: size))
                if hasSelection {
                    dimmed.addRect(selection)
                }
                ctx.fill(dimmed, with: .color(.black.opacity(0.5)), style: FillStyle(eoFill: true))
            }
            .ignoresSafeArea()

            // Selection border + size readout.
            if hasSelection {
                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 1)
                    .frame(width: selection.width, height: selection.height)
                    .position(x: selection.midX, y: selection.midY)

                Text("\(Int(selection.width)) × \(Int(selection.height))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.7)))
                    .position(x: selection.midX, y: max(selection.minY - 14, 12))
            }

            // Mouse tracking sits on top so it receives all events.
            MouseTrackingRepresentable(
                onDown: { p in
                    startPoint = p
                    selection = CGRect(origin: p, size: .zero)
                },
                onDrag: { p in
                    if let s = startPoint { selection = Self.rect(from: s, to: p) }
                },
                onUp: { p in
                    guard let s = startPoint else { return }
                    let r = Self.rect(from: s, to: p)
                    startPoint = nil
                    if r.width >= 4 && r.height >= 4 {
                        onComplete(r)
                    } else {
                        onCancel()
                    }
                },
                onCancel: onCancel
            )
            .ignoresSafeArea()
        }
    }

    private static func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(a.x - b.x),
            height: abs(a.y - b.y)
        )
    }
}

// MARK: - Mouse tracking

/// Flipped NSView (top-left origin) that reports mouse drags as view-local
/// points and Escape as a cancel. More reliable than a SwiftUI DragGesture
/// inside a borderless key window.
final class MouseTrackingNSView: NSView {
    var onDown: ((CGPoint) -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onUp: ((CGPoint) -> Void)?
    var onCancel: (() -> Void)?

    private var cursorTrackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        // Flip to the crosshair the instant the overlay appears — the pointer
        // is already over this full-screen view, so we don't wait for a drag.
        NSCursor.crosshair.set()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let cursorTrackingArea {
            removeTrackingArea(cursorTrackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        cursorTrackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    private func point(for event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil)
    }

    override func mouseDown(with event: NSEvent) { onDown?(point(for: event)) }
    override func mouseDragged(with event: NSEvent) { onDrag?(point(for: event)) }
    override func mouseUp(with event: NSEvent) { onUp?(point(for: event)) }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // escape
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
}

struct MouseTrackingRepresentable: NSViewRepresentable {
    var onDown: (CGPoint) -> Void
    var onDrag: (CGPoint) -> Void
    var onUp: (CGPoint) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> MouseTrackingNSView {
        let view = MouseTrackingNSView()
        apply(to: view)
        return view
    }

    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {
        apply(to: nsView)
    }

    private func apply(to view: MouseTrackingNSView) {
        view.onDown = onDown
        view.onDrag = onDrag
        view.onUp = onUp
        view.onCancel = onCancel
    }
}
