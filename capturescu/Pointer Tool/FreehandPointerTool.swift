//
//  FreehandPointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

// Helper struct to represent a point
private struct Point: Identifiable {
    var id = UUID()
    var x: CGFloat
    var y: CGFloat
}

extension Point {
    // Convert from CGPoint
    init(from cgPoint: CGPoint) {
        self.x = cgPoint.x
        self.y = cgPoint.y
    }

    // Convert to CGPoint
    var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

private class SimplifyPath {
    // Modified RDP algorithm to work with a Path directly
    static func rdp(path: Path, epsilon: CGFloat) -> Path {
        // Extract points from the path
        let points = path.points().map { Point(from: $0) }

        // Apply the RDP algorithm to simplify the points
        let simplifiedPoints = rdp(points: points, epsilon: epsilon)

        // Rebuild and return the simplified Path
        var simplifiedPath = Path()
        if let firstPoint = simplifiedPoints.first {
            simplifiedPath.move(to: firstPoint.cgPoint)
            for point in simplifiedPoints.dropFirst() {
                simplifiedPath.addLine(to: point.cgPoint)
            }
        }

        return simplifiedPath
    }

    // Original RDP function that simplifies an array of Points
    static func rdp(points: [Point], epsilon: CGFloat) -> [Point] {
        guard points.count > 2 else { return points }

        let firstPoint = points.first!
        let lastPoint = points.last!

        var maxDistance: CGFloat = 0
        var index = 0

        for i in 1 ..< points.count - 1 {
            let distance = perpendicularDistance(point: points[i], lineStart: firstPoint, lineEnd: lastPoint)
            if distance > maxDistance {
                maxDistance = distance
                index = i
            }
        }

        if maxDistance > epsilon {
            let leftPoints = rdp(points: Array(points[0 ... index]), epsilon: epsilon)
            let rightPoints = rdp(points: Array(points[index...]), epsilon: epsilon)
            return leftPoints + rightPoints.dropFirst()
        } else {
            return [firstPoint, lastPoint]
        }
    }

    // Helper function for perpendicular distance (same as before)
    private static func perpendicularDistance(point: Point, lineStart: Point, lineEnd: Point) -> CGFloat {
        let x0 = point.x
        let y0 = point.y
        let x1 = lineStart.x
        let y1 = lineStart.y
        let x2 = lineEnd.x
        let y2 = lineEnd.y

        let numerator = abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1)
        let denominator = sqrt(pow(y2 - y1, 2) + pow(x2 - x1, 2))
        return numerator / denominator
    }
}

@Observable class FreehandPointerTool: PointerTool {
    var toolName = PointerToolName.FreehandPointer

    private var marker: DrawingMarker
    private var markerColor: MarkerColor

    init(color: MarkerColor) {
        self.markerColor = color
        self.marker = DrawingMarker(markerColor: color)
    }

    // i was thinking about adding the color as a parameter, but then...
    // it makes sense to "swap" the tool(eg: a pencil) you're using when you want to
    // change the color...
    func beginMarker(at location: CGPoint) {
        marker.path.move(to: location)
    }

    func updateMarker(at location: CGPoint) {
        marker.path.addLine(to: location)
    }

    func endMarker(at _: CGPoint) {
        marker.path.closeSubpath()
        marker = DrawingMarker(markerColor: markerColor)
    }

    func clearMarker() {
        marker = DrawingMarker(markerColor: markerColor)
    }

    func drawMarker(onto graphicsContext: GraphicsContext) {
        // let newPath = SimplifyPath.rdp(path: marker.path, epsilon: 1.2)
        // marker.path = newPath
        marker.draw(onto: graphicsContext)
    }

    func getMarker() -> Marker {
        return marker
    }
}
