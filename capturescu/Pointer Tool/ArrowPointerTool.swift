//
//  ArrowPointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import AppKit
import Foundation
import SwiftUI

@Observable class ArrowPointerTool: PointerTool {
    let toolName = PointerToolName.ArrowPointer
    let needsAccessoryView = false
    
    private var markerColor: MarkerColor
    var strokeWidth: CGFloat = 2
    var startPoint: CGPoint?
    var currentEndPoint: CGPoint?
    var isDrawing = false
    private weak var markersManager: MarkersManager?
    
    init(color: MarkerColor, markersManager: MarkersManager) {
        self.markerColor = color
        self.markersManager = markersManager
    }
    
    func handleEvent(_ event: PointerEvent) -> ToolResponse {
        switch event {
        case .dragStart(let point):
            beginDrawing(at: point)
            return .continue
            
        case .dragUpdate(let point):
            updateDrawing(at: point)
            return .continue
            
        case .dragEnd(let point):
            return endDrawing(at: point)
            
        case .click(let point):
            // Handle single click as a small arrow
            beginDrawing(at: point)
            let endPoint = CGPoint(x: point.x + 20, y: point.y)
            return endDrawing(at: endPoint)
            
        default:
            return .empty
        }
    }
    
    func renderPreview(context: GraphicsContext) {
        guard isDrawing, let start = startPoint, let end = currentEndPoint else { return }

        // Preview the exact marker that will be committed — same silhouette,
        // rounding, and shadow — so there's no pop on release.
        makeArrowMarker(from: start, to: end)?.draw(onto: context)
    }
    
    func reset() {
        startPoint = nil
        currentEndPoint = nil
        isDrawing = false
    }
    
    func updateColor(_ color: MarkerColor) {
        markerColor = color
    }

    func updateStrokeWidth(_ width: CGFloat) {
        strokeWidth = width
    }

    func updateMarkersManager(_ markersManager: MarkersManager) {
        self.markersManager = markersManager
    }
    
    // MARK: - Private Methods
    
    private func beginDrawing(at point: CGPoint) {
        startPoint = point
        currentEndPoint = point
        isDrawing = true
    }
    
    private func updateDrawing(at point: CGPoint) {
        guard isDrawing, let start = startPoint else { return }
        currentEndPoint = NSEvent.modifierFlags.contains(.shift)
            ? snapPointToAngle(from: start, to: point) : point
    }

    private func endDrawing(at point: CGPoint) -> ToolResponse {
        guard isDrawing, let start = startPoint, let markersManager = markersManager else { return .empty }

        let endPoint = NSEvent.modifierFlags.contains(.shift)
            ? snapPointToAngle(from: start, to: point) : point

        guard let marker = makeArrowMarker(from: start, to: endPoint) else {
            reset()
            return .empty
        }

        let command = AddMarkerCommand(
            markersManager: markersManager,
            marker: marker
        )

        // Reset state
        reset()

        return ToolResponse(
            shouldContinue: false,
            commands: [command]
        )
    }

    /// Build the arrow marker for a drag from `start` to `end`. Shared by the live
    /// preview and the committed marker so they're always identical. Returns nil
    /// for a degenerate (zero-length) drag.
    private func makeArrowMarker(from start: CGPoint, to end: CGPoint) -> DrawingMarker? {
        let path = createArrowPath(from: start, to: end)
        guard !path.isEmpty else { return nil }

        // Filled silhouette: no outline stroke (rounding of the tail corners is
        // baked into the path; the head stays sharp), plus a soft shadow for
        // contrast against any background.
        var style = MarkerStyle(strokeColor: markerColor, fillColor: markerColor)
        style.strokeWidth = 0
        style.shadow = MarkerShadow()

        var marker = DrawingMarker(markerStyle: style)
        marker.path = path
        return marker
    }


    /// Minimum arrow length. A drag shorter than this still yields a real, legible
    /// arrow in the drag direction instead of a speck.
    private let minLength: CGFloat = 24

    /// Build the arrow as a single closed silhouette — a rectangular shaft that
    /// flares into a triangular head — traced as one non-self-intersecting outline
    /// so it fills cleanly at any size. `strokeWidth` sets the shaft thickness; the
    /// head has its own base size (decoupled from the shaft) so thin arrows stay
    /// bold and thick ones don't grow an absurdly long head.
    private func createArrowPath(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()

        let dx = end.x - start.x
        let dy = end.y - start.y
        let rawLength = hypot(dx, dy)

        // Degenerate drag — no direction to point in.
        guard rawLength > 0.5 else { return path }

        // Direction from the actual drag, but clamp the length up to a minimum so
        // a tiny drag still draws a proper arrow rather than a speck.
        let ux = dx / rawLength, uy = dy / rawLength
        let px = -uy, py = ux
        let length = max(rawLength, minLength)
        let tip = CGPoint(x: start.x + ux * length, y: start.y + uy * length)

        let shaftWidth = max(strokeWidth, 1)
        let halfShaft = shaftWidth / 2
        // Head size is largely independent of the shaft: a solid base length keeps
        // thin arrows readable, with only gentle growth for very thick shafts, and
        // it never eats more than most of the arrow's length. The half-width flares
        // wider than the shaft so the barbs always stick out past the sides.
        let headLength = min(max(18, shaftWidth * 2.0), length * 0.8)
        let headHalfWidth = max(headLength * 0.5, halfShaft + shaftWidth)

        // Where the head meets the shaft.
        let baseX = tip.x - ux * headLength
        let baseY = tip.y - uy * headLength

        func p(_ ax: CGFloat, _ ay: CGFloat, _ scale: CGFloat) -> CGPoint {
            CGPoint(x: ax + px * scale, y: ay + py * scale)
        }

        // Silhouette vertices (see comment below for traversal order).
        let tailPlus = p(start.x, start.y, halfShaft)          // tail, +side
        let junctionPlus = p(baseX, baseY, halfShaft)          // shaft/head junction, +side
        let barbPlus = p(baseX, baseY, headHalfWidth)          // barb tip, +side
        let barbMinus = p(baseX, baseY, -headHalfWidth)        // barb tip, -side
        let junctionMinus = p(baseX, baseY, -halfShaft)        // shaft/head junction, -side
        let tailMinus = p(start.x, start.y, -halfShaft)        // tail, -side
        let tailMid = start                                    // midpoint of the tail edge

        // Round only the two tail corners; the head (barbs + point) stays sharp.
        // The radius can't exceed half the shaft width or eat into the shaft length.
        let shaftLength = max(0, length - headLength)
        let tailRadius = min(halfShaft, max(2, shaftWidth * 0.45), shaftLength * 0.4)

        // Trace the perimeter with tangent arcs. A radius of 0 yields a sharp
        // corner (a plain line to the vertex); the two tail corners use tailRadius.
        // Start at the tail-edge midpoint so both tail corners are interior to the
        // traversal and round cleanly.
        path.move(to: tailMid)
        path.addArc(tangent1End: tailPlus,     tangent2End: junctionPlus,  radius: tailRadius)
        path.addArc(tangent1End: junctionPlus, tangent2End: barbPlus,      radius: 0)
        path.addArc(tangent1End: barbPlus,     tangent2End: tip,           radius: 0)
        path.addArc(tangent1End: tip,          tangent2End: barbMinus,     radius: 0)
        path.addArc(tangent1End: barbMinus,    tangent2End: junctionMinus, radius: 0)
        path.addArc(tangent1End: junctionMinus, tangent2End: tailMinus,    radius: 0)
        path.addArc(tangent1End: tailMinus,    tangent2End: tailPlus,      radius: tailRadius)
        path.closeSubpath()

        return path
    }
}