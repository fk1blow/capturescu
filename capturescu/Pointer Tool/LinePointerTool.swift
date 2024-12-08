//
//  LinePointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

@Observable class LinePointerTool: PointerTool {
    var toolName = PointerToolName.LinePointer

    private var marker: DrawingMarker
    private var markerColor: MarkerColor

    private var startPoint = CGPointZero

    init(color: MarkerColor) {
        self.markerColor = color
        self.marker = DrawingMarker(markerColor: color)
    }

    func beginMarker(at location: CGPoint) {
        startPoint = location
        marker.path.move(to: location)
    }

    func updateMarker(at location: CGPoint) {
        marker.path = Path { path in
            path.move(to: startPoint)
            path.addLine(to: location)
        }
    }

    func endMarker(at _: CGPoint) {
        marker.path.closeSubpath()
        marker = DrawingMarker(markerColor: markerColor)
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
}
