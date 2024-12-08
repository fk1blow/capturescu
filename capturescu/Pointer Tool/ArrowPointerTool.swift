//
//  ArrowPointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

@Observable class ArrowPointerTool: PointerTool {
    var toolName = PointerToolName.ArrowPointer
    
    private var marker: DrawingMarker
    private var markerColor: MarkerColor

    private var startPoint = CGPointZero
    
    init(color: MarkerColor) {
        self.markerColor = color
        // self.marker = DrawingMarker(markerColor: color)
        self.marker = DrawingMarker(markerStyle: MarkerStyle(strokeColor: color, fillColor: color))
    }

    func beginMarker(at location: CGPoint) {
        startPoint = location
        marker.path.move(to: location)
    }
    
    func updateMarker(at location: CGPoint) {
        marker.path = buildArrowShape(startPoint: startPoint, endPoint: location)
    }
    
    func endMarker(at _: CGPoint) {
        marker.path.closeSubpath()
        marker = DrawingMarker(markerStyle: MarkerStyle(strokeColor: markerColor, fillColor: markerColor))
        startPoint = CGPointZero
    }
    
    // To avoid repetition, this could be declared through an extension
    func drawMarker(onto graphicsContext: GraphicsContext) {
        marker.draw(onto: graphicsContext)
    }
    
    // To avoid repetition, this could be declared through an extension
    func getMarker() -> Marker {
        return marker
    }
    
    func clearMarker() {
        marker = DrawingMarker(markerColor: markerColor)
    }

    private func buildArrowShape(startPoint: CGPoint, endPoint: CGPoint) -> Path {
        var path = Path()
        
        // Calculate the direction vector
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        
        // Calculate the length of the arrow
        let totalLength = sqrt(dx * dx + dy * dy)
        
        // Normalize the direction vector
        let unitDx = dx / totalLength
        let unitDy = dy / totalLength
        
        // Define the arrowhead size and shaft width
        let arrowHeadLength: CGFloat = 20
        let arrowHeadWidth: CGFloat = 25
        let arrowShaftWidth: CGFloat = 6
        
        // Calculate the base of the arrowhead
        let arrowHeadBase = CGPoint(
            x: endPoint.x - unitDx * arrowHeadLength,
            y: endPoint.y - unitDy * arrowHeadLength
        )
        
        // Calculate the arrowhead points
        let arrowHeadLeft = CGPoint(
            x: arrowHeadBase.x - unitDy * arrowHeadWidth / 2,
            y: arrowHeadBase.y + unitDx * arrowHeadWidth / 2
        )
        
        let arrowHeadRight = CGPoint(
            x: arrowHeadBase.x + unitDy * arrowHeadWidth / 2,
            y: arrowHeadBase.y - unitDx * arrowHeadWidth / 2
        )

        // Calculate the shaft points starting from startPoint to arrowHeadBase
        let arrowShaftLeftStart = CGPoint(
            x: startPoint.x - unitDy * arrowShaftWidth / 2,
            y: startPoint.y + unitDx * arrowShaftWidth / 2
        )
        
        let arrowShaftRightStart = CGPoint(
            x: startPoint.x + unitDy * arrowShaftWidth / 2,
            y: startPoint.y - unitDx * arrowShaftWidth / 2
        )
        
        let arrowShaftLeftEnd = CGPoint(
            x: arrowHeadBase.x - unitDy * arrowShaftWidth / 2,
            y: arrowHeadBase.y + unitDx * arrowShaftWidth / 2
        )
        
        let arrowShaftRightEnd = CGPoint(
            x: arrowHeadBase.x + unitDy * arrowShaftWidth / 2,
            y: arrowHeadBase.y - unitDx * arrowShaftWidth / 2
        )

        // Draw the arrow shaft and head
        path.move(to: arrowShaftLeftStart)
        path.addLine(to: arrowShaftLeftEnd)
        path.addLine(to: arrowHeadLeft)
        path.addLine(to: endPoint) // Arrow tip
        path.addLine(to: arrowHeadRight)
        path.addLine(to: arrowShaftRightEnd)
        path.addLine(to: arrowShaftRightStart)
        path.addLine(to: arrowShaftLeftStart)
        
        return path
    }
}
