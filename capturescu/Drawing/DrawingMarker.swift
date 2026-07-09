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
            // Cast the shadow in its own pass, then paint the body cleanly on top.
            // Drawing the body only inside the shadow layer would let its rounding
            // stroke cast a shadow onto its own fill, leaving a lighter seam down
            // the middle; the opaque top pass covers that, keeping just the outer
            // shadow.
            if let shadow = style.shadow {
                graphicsContext.drawLayer { layer in
                    layer.addFilter(.shadow(color: shadow.color, radius: shadow.radius,
                                            x: shadow.offset.width, y: shadow.offset.height))
                    paintBody(into: layer)
                }
            }
            paintBody(into: graphicsContext)
        }

        drawHighlight(onto: graphicsContext)
    }

    /// Paint the marker's fill and/or outline. A zero stroke width means "no
    /// outline" — filled shapes (e.g. the arrow) are defined by their fill. Strokes
    /// use round caps and joins so line ends and freehand corners are rounded.
    private func paintBody(into ctx: GraphicsContext) {
        if let fillColor = style.fillColor {
            ctx.fill(path, with: .color(fillColor.color))
        }

        if style.strokeWidth > 0 {
            ctx.stroke(path, with: .color(style.strokeColor.color),
                       style: StrokeStyle(lineWidth: style.strokeWidth, lineCap: .round, lineJoin: .round))
        }
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
