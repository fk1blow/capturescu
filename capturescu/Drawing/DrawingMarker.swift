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
        graphicsContext.stroke(path, with: .color(style.strokeColor.color), lineWidth: style.strokeWidth)

        if style.fillColor != nil {
            graphicsContext.fill(path, with: .color(style.fillColor!.color))
        }

        if isHighlighted {
            drawHighlight(onto: graphicsContext)
        }
    }

    func changeStyle(with _: MarkerStyle) {
        // TODO
    }

    func getRepresentation() -> MarkerRepresentation {
        return .path(path)
    }

    func markerBoundingBox(near location: CGPoint) -> BoundingBox? {
        return isPointNearPathAlt(testPoint: location, path: path, threshold: 20)
    }

    mutating func offsetMarkerBy(dx: CGFloat, dy: CGFloat) {
        path = path.offsetBy(dx: dx, dy: dy)
    }
}
