//
//  CaptureAnnotationView.swift
//  capturescu
//
//  The "snapshot editor" surface. It reuses the existing DrawingSurfaceView,
//  rendered at the viewport size that the SnapshotEditorModel publishes (the
//  visible portion of the frozen full-screen image). A dashed/interrupted white
//  border always frames the snapshot — drawn as a stroke in a 2px padding ring
//  around the viewport, so it never covers the image.
//
//  Eight resize handles (4 corners + 4 edges) sit on that border ring. Dragging
//  one resizes the editor, revealing/hiding more of the frozen screen. The drag
//  only signals "resize active" — the actual geometry comes from the absolute
//  cursor position inside the model, so the window moving under the drag never
//  corrupts the math. Tool/marker state comes from the injected environment
//  objects; the hand tool / space-drag moves the whole editor.
//

import SwiftUI
import AppKit

struct CaptureAnnotationView: View {
    let capturedImage: CapturedPasteboardImage
    @EnvironmentObject var editorModel: SnapshotEditorModel

    @State private var isResizing = false

    private let borderWidth: CGFloat = 2
    /// How far the grab strips reach inward from the window edge: across the
    /// transparent ring (+ border) plus a few px so the snapshot edge itself is
    /// grabbable. Most of the zone sits in the ring, outside the snapshot.
    private var edgeGrab: CGFloat { editorModel.grabMargin + borderWidth + 2 }
    private var cornerGrab: CGFloat { editorModel.grabMargin + borderWidth + 10 }

    var body: some View {
        DrawingSurfaceView(capturedImage: capturedImage)
            .frame(width: editorModel.viewportSize.width, height: editorModel.viewportSize.height)
            .clipped()
            .padding(borderWidth)
            .overlay(
                Rectangle().strokeBorder(
                    Color.white,
                    style: StrokeStyle(lineWidth: borderWidth, dash: [6, 4])
                )
            )
            .overlay(cornerBrackets)
            // Transparent grab ring around the snapshot: the resize handles live
            // out here, so you grab from *outside* the dashed border.
            .padding(editorModel.grabMargin)
            .overlay(resizeHandles)
    }

    // MARK: - Corner emphasis

    /// Heavy L-shaped marks on all four corners — a persistent "this is resizable"
    /// affordance, always shown regardless of where the mouse is. Purely cosmetic:
    /// it must never intercept the corner grab handles underneath it.
    private var cornerBrackets: some View {
        // Arm length stays put; only the stroke gets heavier. Inset by half the
        // line width so the thicker stroke sits flush to the corner rather than
        // spilling outside the frame.
        let lineWidth: CGFloat = 6
        return CornerBrackets(arm: 24, inset: lineWidth / 2)
            .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt, lineJoin: .miter))
            .shadow(color: Color.black.opacity(0.45), radius: 1)
            .allowsHitTesting(false)
    }

    // MARK: - Resize handles

    private var resizeHandles: some View {
        ZStack {
            // Edge strips first; corners layered on top so they win the overlap.
            edgeStrip(.top)
            edgeStrip(.bottom)
            edgeStrip(.left)
            edgeStrip(.right)
            cornerSquare(.topLeft)
            cornerSquare(.topRight)
            cornerSquare(.bottomLeft)
            cornerSquare(.bottomRight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func edgeStrip(_ edge: ResizeEdge) -> some View {
        let horizontal = (edge == .top || edge == .bottom)
        let alignment: Alignment = {
            switch edge {
            case .top: return .top
            case .bottom: return .bottom
            case .left: return .leading
            default: return .trailing
            }
        }()
        return grabArea(
            width: horizontal ? nil : edgeGrab,
            height: horizontal ? edgeGrab : nil,
            cursor: horizontal ? .resizeUpDown : .resizeLeftRight,
            edge: edge
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    private func cornerSquare(_ edge: ResizeEdge) -> some View {
        let alignment: Alignment = {
            switch edge {
            case .topLeft: return .topLeading
            case .topRight: return .topTrailing
            case .bottomLeft: return .bottomLeading
            default: return .bottomTrailing
            }
        }()
        let diagonal: NSCursor = (edge == .topLeft || edge == .bottomRight)
            ? ResizeCursor.northWestSouthEast
            : ResizeCursor.northEastSouthWest
        return grabArea(width: cornerGrab, height: cornerGrab, cursor: diagonal, edge: edge)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    /// A transparent, hit-testable grab region wired to drive the model's resize.
    private func grabArea(width: CGFloat?, height: CGFloat?, cursor: NSCursor, edge: ResizeEdge) -> some View {
        Color.white.opacity(0.001)
            .frame(maxWidth: width == nil ? .infinity : nil,
                   maxHeight: height == nil ? .infinity : nil)
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { cursor.set() } else { NSCursor.arrow.set() }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isResizing {
                            isResizing = true
                            editorModel.beginResize()
                        }
                        editorModel.updateResize(edge: edge)
                    }
                    .onEnded { _ in isResizing = false }
            )
    }
}

/// L-shaped brackets at all four corners of a rect: for each corner, draw one arm
/// along each edge meeting at the corner.
private struct CornerBrackets: Shape {
    var arm: CGFloat
    var inset: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect.insetBy(dx: inset, dy: inset)
        // Don't let opposite arms meet on a tiny editor — cap at ~40% of the
        // shorter side so the brackets stay distinct corner marks.
        let arm = min(self.arm, min(r.width, r.height) * 0.4)
        // Each corner: end of vertical arm → corner → end of horizontal arm.
        // top-left
        p.move(to: CGPoint(x: r.minX, y: r.minY + arm))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + arm, y: r.minY))
        // top-right
        p.move(to: CGPoint(x: r.maxX - arm, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + arm))
        // bottom-right
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - arm))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - arm, y: r.maxY))
        // bottom-left
        p.move(to: CGPoint(x: r.minX + arm, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - arm))
        return p
    }
}

/// Diagonal resize cursors aren't part of NSCursor's public API; fall back to the
/// straight resize cursors if the (long-stable) private ones aren't available.
enum ResizeCursor {
    static var northWestSouthEast: NSCursor { named("_windowResizeNorthWestSouthEastCursor") ?? .resizeLeftRight }
    static var northEastSouthWest: NSCursor { named("_windowResizeNorthEastSouthWestCursor") ?? .resizeLeftRight }

    private static func named(_ selectorName: String) -> NSCursor? {
        let selector = NSSelectorFromString(selectorName)
        guard NSCursor.responds(to: selector),
              let result = NSCursor.perform(selector)?.takeUnretainedValue() as? NSCursor else {
            return nil
        }
        return result
    }
}
