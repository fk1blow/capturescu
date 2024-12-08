//
//  DrawingShapeProtocol.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct Line {
    var points = [CGPoint]()
    var color: Color = .blue
    var lineWidth: Double = 3.0

    static func from(box: BoundingBox) -> Line {
        return Line(
            points: [
                CGPoint(x: box.xMin, y: box.yMin),
                CGPoint(x: box.xMax, y: box.yMin),
                CGPoint(x: box.xMax, y: box.yMax),
                CGPoint(x: box.xMin, y: box.yMax),
                CGPoint(x: box.xMin, y: box.yMin),
            ],
            color: .red,
            lineWidth: 2
        )
    }

    static func from(line: Line) -> Line {
        return Line(points: line.points, color: line.color, lineWidth: line.lineWidth)
    }
}

protocol DrawableToolProtocol {
    var line: Line { get set }
    func move(at location: CGPoint)
    func draw(at location: CGPoint, modifierKeys: NSEvent.ModifierFlags?)
}
