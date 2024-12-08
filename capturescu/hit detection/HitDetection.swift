//
//  HitDetection.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

// Function to check if a point is near the path
func isPointNearPath(testPoint: CGPoint, points: [CGPoint], threshold: CGFloat = 10) -> BoundingBox? {
    // Step 1: Calculate the bounding box
    let boundingBox = getBoundingBox(points: points, margin: threshold)

    // Step 2: Quick check to see if the point is within the bounding box
    if !isPointInBoundingBox(point: testPoint, boundingBox: boundingBox) {
        return nil // The point is outside the bounding box
    }

    // Step 3: If within bounding box, check distance to each line segment
    for i in 0 ..< points.count - 1 {
        let p1 = points[i]
        let p2 = points[i + 1]

        let distance = pointToSegmentDistance(testPoint: testPoint, p1: p1, p2: p2)
        if distance <= threshold {
            return boundingBox // The point is near enough to the path
        }
    }

    return nil
}

// Function to calculate the bounding box for a set of points
private func getBoundingBox(points: [CGPoint], margin: CGFloat = 0) -> BoundingBox {
    var minX: CGFloat = .infinity
    var minY: CGFloat = .infinity
    var maxX: CGFloat = -.infinity
    var maxY: CGFloat = -.infinity

    for point in points {
        if point.x < minX { minX = point.x }
        if point.x > maxX { maxX = point.x }
        if point.y < minY { minY = point.y }
        if point.y > maxY { maxY = point.y }
    }

    return BoundingBox(xMin: minX - margin, xMax: maxX + margin, yMin: minY - margin, yMax: maxY + margin)
}

// Function to check if a point is within the bounding box
private func isPointInBoundingBox(point: CGPoint, boundingBox: BoundingBox) -> Bool {
    return point.x >= boundingBox.xMin &&
        point.x <= boundingBox.xMax &&
        point.y >= boundingBox.yMin &&
        point.y <= boundingBox.yMax
}

// Helper function to calculate the distance from a point to a line segment
private func pointToSegmentDistance(testPoint: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
    let lengthSquared = distanceSquared(p1, p2)
    if lengthSquared == 0 {
        return distance(testPoint, p1) // p1 and p2 are the same point
    }

    // Project the point onto the line (clamped to the segment)
    let t = max(0, min(1, ((testPoint.x - p1.x) * (p2.x - p1.x) + (testPoint.y - p1.y) * (p2.y - p1.y)) / lengthSquared))
    let projection = CGPoint(x: p1.x + t * (p2.x - p1.x), y: p1.y + t * (p2.y - p1.y))

    return distance(testPoint, projection)
}

// Helper function to calculate the distance between two points
private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
    return sqrt((p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y))
}

// Helper function to calculate the squared distance between two points
private func distanceSquared(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
    return (p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y)
}
