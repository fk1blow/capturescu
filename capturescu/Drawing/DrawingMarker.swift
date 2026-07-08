//
//  DrawingMarker.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct DrawingMarker: Marker {
    var id = UUID()

    // var style = MarkerStyle(strokeColor: Color.orange)
    var style: MarkerStyle
    var path: Path
    var isHighlighted: Bool = false

    init(markerColor: MarkerColor) {
        style = MarkerStyle(strokeColor: markerColor)
        path = Path()
    }

    init(markerStyle: MarkerStyle) {
        style = markerStyle
        path = Path()
    }

    func draw(onto graphicsContext: GraphicsContext) {
        // Ensure we have a valid path before drawing.
        // Guard on `path.isEmpty` (no elements) rather than `boundingRect.isEmpty`,
        // since a perfectly horizontal/vertical line has a zero-area bounding rect
        // but is still a valid stroke.
        if !path.isEmpty {
            graphicsContext.stroke(path, with: .color(style.strokeColor.color), lineWidth: style.strokeWidth)
            
            if style.fillColor != nil {
                graphicsContext.fill(path, with: .color(style.fillColor!.color))
            }
        }

        drawHighlight(onto: graphicsContext)
    }

    func changeStyle(with _: MarkerStyle) {
        // TODO
    }

    func getRepresentation() -> MarkerRepresentation {
        return .path(path)
    }

    func markerBoundingBox(near location: CGPoint) -> BoundingBox? {
        return HitDetectionManager.shared.isPointNearPath(location, path: path, threshold: 20)
    }

    mutating func offsetMarkerBy(dx: CGFloat, dy: CGFloat) {
        path = path.offsetBy(dx: dx, dy: dy)
    }
}
