//
//  File.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation

struct BoundingBox {
    var xMin: Double
    var xMax: Double
    var yMin: Double
    var yMax: Double

    static func zero() -> BoundingBox {
        return BoundingBox(xMin: 0, xMax: 0, yMin: 0, yMax: 0)
    }
}
