//
//  SnapshotEditorModel.swift
//  capturescu
//
//  Geometry source of truth for the resizable snapshot editor.
//
//  The editor shows a *window onto the frozen whole-screen capture*. The single
//  source of truth is `visibleRect` — the portion of the full image currently
//  shown, in IMAGE-POINT space (top-left origin; the full image's point size
//  equals the captured screen's point size). Everything the editor needs derives
//  from it:
//    • `canvasOffset` / `viewportSize` drive the SwiftUI canvas (what's drawn).
//    • `windowFrame` drives the borderless NSWindow (where it sits on screen).
//
//  Because the window is derived from `visibleRect` via the captured `screenFrame`,
//  the editor stays *pinned to the screen*: resizing or moving it reveals the
//  frozen pixels that were actually at those screen positions at capture time —
//  no re-capture, so a video underneath never advances out from under you.
//
//  Resize/move read the absolute cursor via `NSEvent.mouseLocation` rather than
//  SwiftUI gesture translation, so the window moving under the drag never corrupts
//  the math.
//

import AppKit
import SwiftUI

/// Which edge(s) a resize handle drives. Corners drive two adjacent edges.
enum ResizeEdge: Equatable {
    case top, bottom, left, right
    case topLeft, topRight, bottomLeft, bottomRight

    var movesLeft: Bool { self == .left || self == .topLeft || self == .bottomLeft }
    var movesRight: Bool { self == .right || self == .topRight || self == .bottomRight }
    var movesTop: Bool { self == .top || self == .topLeft || self == .topRight }
    var movesBottom: Bool { self == .bottom || self == .bottomLeft || self == .bottomRight }
}

@MainActor
final class SnapshotEditorModel: ObservableObject {
    let fullImage: CGImage
    let scale: CGFloat
    /// Captured screen frame, global AppKit coordinates (bottom-left origin).
    let screenFrame: CGRect
    let border: CGFloat
    let minSize: CGSize
    /// Full image's point size (== `screenFrame.size`).
    let imagePointSize: CGSize
    /// Where the *window* may live, global AppKit (visibleFrame inset by margin).
    let workingArea: CGRect
    /// Where `visibleRect` (the content) may live, in IMAGE-POINT space.
    let allowedBounds: CGRect

    /// The portion of the full image currently shown (image-point space, top-left
    /// origin). Mutating it reflows the windows via `onGeometryChange`.
    @Published var visibleRect: CGRect = .zero {
        didSet { onGeometryChange?() }
    }

    /// Set by the controller to reposition the window + toolbar on every change.
    var onGeometryChange: (() -> Void)?

    // Interaction anchors (captured at the start of a resize/move drag).
    private var anchorRect: CGRect = .zero
    private var resizeStartMouse: CGPoint = .zero
    private var moveStartMouse: CGPoint = .zero

    init(fullImage: CGImage,
         scale: CGFloat,
         screenFrame: CGRect,
         visibleFrame: CGRect,
         edgeMargin: CGFloat,
         border: CGFloat,
         minSize: CGSize) {
        self.fullImage = fullImage
        self.scale = scale
        self.screenFrame = screenFrame
        self.border = border
        self.minSize = minSize
        self.imagePointSize = CGSize(width: CGFloat(fullImage.width) / scale,
                                     height: CGFloat(fullImage.height) / scale)

        let working = visibleFrame.insetBy(dx: edgeMargin, dy: edgeMargin)
        self.workingArea = working

        // The content (inside the border) must stay inside the working area; map
        // that allowance from global AppKit into image-point space, then clip to
        // the image itself (can't reveal beyond the captured screen).
        let contentGlobal = working.insetBy(dx: border, dy: border)
        let allowedFromScreen = CGRect(
            x: contentGlobal.minX - screenFrame.minX,
            y: screenFrame.maxY - contentGlobal.maxY,
            width: contentGlobal.width,
            height: contentGlobal.height
        )
        self.allowedBounds = allowedFromScreen.intersection(CGRect(origin: .zero, size: imagePointSize))
    }

    // MARK: - Derived display state

    /// The canvas (which draws the full image at origin) is translated by this so
    /// `visibleRect.origin` lands at the viewport's top-left.
    var canvasOffset: CGPoint { CGPoint(x: -visibleRect.minX, y: -visibleRect.minY) }

    var viewportSize: CGSize { visibleRect.size }

    /// The borderless window's frame in global AppKit coords (content + border).
    var windowFrame: CGRect {
        let contentX = screenFrame.minX + visibleRect.minX
        let contentY = screenFrame.maxY - visibleRect.maxY // AppKit minY = bottom edge
        return CGRect(
            x: contentX - border,
            y: contentY - border,
            width: visibleRect.width + 2 * border,
            height: visibleRect.height + 2 * border
        )
    }

    // MARK: - Initial placement

    func setInitialVisibleRect(_ rect: CGRect) {
        visibleRect = clamped(rect)
    }

    // MARK: - Resize (driven by edge/corner handles)

    func beginResize() {
        anchorRect = visibleRect
        resizeStartMouse = rawMouseImagePoint()
    }

    func updateResize(edge: ResizeEdge) {
        let cur = rawMouseImagePoint()
        let dx = cur.x - resizeStartMouse.x
        let dy = cur.y - resizeStartMouse.y

        var minX = anchorRect.minX, maxX = anchorRect.maxX
        var minY = anchorRect.minY, maxY = anchorRect.maxY

        // Move the dragged edge by the cursor delta; clamp it within the allowed
        // bounds while preserving the minimum size against the fixed opposite edge.
        if edge.movesLeft  { minX = min(max(anchorRect.minX + dx, allowedBounds.minX), maxX - minSize.width) }
        if edge.movesRight { maxX = max(min(anchorRect.maxX + dx, allowedBounds.maxX), minX + minSize.width) }
        if edge.movesTop    { minY = min(max(anchorRect.minY + dy, allowedBounds.minY), maxY - minSize.height) }
        if edge.movesBottom { maxY = max(min(anchorRect.maxY + dy, allowedBounds.maxY), minY + minSize.height) }

        visibleRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: - Move (driven by the hand tool / space-drag)

    func moveBegan() {
        anchorRect = visibleRect
        moveStartMouse = NSEvent.mouseLocation
    }

    func moveUpdated() {
        let g = NSEvent.mouseLocation
        let dx = g.x - moveStartMouse.x
        let dy = g.y - moveStartMouse.y // screen y grows up; image y grows down
        let origin = clampedOrigin(CGPoint(x: anchorRect.minX + dx, y: anchorRect.minY - dy),
                                   size: anchorRect.size)
        visibleRect = CGRect(origin: origin, size: anchorRect.size)
    }

    /// Two-finger / wheel scroll nudges the whole editor (same direction the
    /// canvas used to pan), keeping it pinned to the frozen screen.
    func moveByScroll(dx: CGFloat, dy: CGFloat) {
        let origin = clampedOrigin(CGPoint(x: visibleRect.minX - dx, y: visibleRect.minY - dy),
                                   size: visibleRect.size)
        visibleRect = CGRect(origin: origin, size: visibleRect.size)
    }

    // MARK: - Helpers

    /// Current cursor position in image-point space (unclamped — used for deltas).
    private func rawMouseImagePoint() -> CGPoint {
        let g = NSEvent.mouseLocation
        return CGPoint(x: g.x - screenFrame.minX, y: screenFrame.maxY - g.y)
    }

    private func clampedOrigin(_ origin: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, allowedBounds.minX), allowedBounds.maxX - size.width),
            y: min(max(origin.y, allowedBounds.minY), allowedBounds.maxY - size.height)
        )
    }

    private func clamped(_ rect: CGRect) -> CGRect {
        var r = rect
        r.size.width = min(max(r.width, minSize.width), allowedBounds.width)
        r.size.height = min(max(r.height, minSize.height), allowedBounds.height)
        r.origin = clampedOrigin(r.origin, size: r.size)
        return r
    }
}
