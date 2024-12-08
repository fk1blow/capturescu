//
//  LineTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

@Observable class LineDrawTool: DrawableToolProtocol {
    var line = Line()

    func move(at location: CGPoint) {
        line = Line()
        line.points.append(location)
    }

    func draw(at location: CGPoint, modifierKeys: NSEvent.ModifierFlags? = nil) {
        if let firstPoint = line.points.first {
            if modifierKeys?.contains(.shift) != nil {
                let endPoint = adjustedEndPoint(from: firstPoint, to: location)
                line.points = [firstPoint, endPoint]
            }
            else {
                line.points = [firstPoint, location]
            }
        }
    }

    private func adjustedEndPoint(from startPoint: CGPoint, to currentPoint: CGPoint) -> CGPoint {
        let deltaX = currentPoint.x - startPoint.x
        let deltaY = currentPoint.y - startPoint.y
        let angle = atan2(deltaY, deltaX)

        let snapAngle = closestSnapAngle(for: angle)

        let length = hypot(deltaX, deltaY) // Distance between start and current points
        let snappedEndX = startPoint.x + length * cos(snapAngle)
        let snappedEndY = startPoint.y + length * sin(snapAngle)

        return CGPoint(x: snappedEndX, y: snappedEndY)
    }

    private func closestSnapAngle(for angle: CGFloat) -> CGFloat {
        // Normalize the input angle to the range [0, 2π]
        var normalizedAngle = angle.truncatingRemainder(dividingBy: 2 * .pi)

        // Handle negative angles to ensure they are in the range [0, 2π]
        if normalizedAngle < 0 {
            normalizedAngle += 2 * .pi
        }

        // Snap angles that cover a full circle (360° in radians)
        let snapAngles: [CGFloat] = [0, .pi / 4, .pi / 2, 3 * .pi / 4, .pi, 5 * .pi / 4, 3 * .pi / 2, 7 * .pi / 4, 2 * .pi]

        // Return the closest snap angle
        return snapAngles.min(by: { abs($0 - normalizedAngle) < abs($1 - normalizedAngle) }) ?? 0
    }
}
