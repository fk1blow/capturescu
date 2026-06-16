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
    /// Thickness of the edge grab strips and size of the corner grab squares.
    private let edgeGrab: CGFloat = 8
    private let cornerGrab: CGFloat = 16

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
            .overlay(resizeHandles)
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
