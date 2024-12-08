//
//  Path+Points.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

// Path extension to extract CGPoints from a Path
// extension Path {
//     // Function to extract all points in a Path as an array of CGPoints
//     func points() -> [CGPoint] {
//         var points: [CGPoint] = []
//
//         self.forEach { element in
//             switch element {
//             case .move(to: let point):
//                 points.append(point)
//             case .line(to: let point):
//                 points.append(point)
//             case .quadCurve(to: let point, control: _):
//                 points.append(point)
//             case .curve(to: let point, control1: _, control2: _):
//                 points.append(point)
//             case .closeSubpath:
//                 break
//             }
//         }
//         return points
//     }
// }

// This might be more accurate
// Path extension to extract CGPoints from a Path
extension Path {
    // Function to extract all points in a Path as an array of CGPoints
    func points() -> [CGPoint] {
        var points: [CGPoint] = []

        self.forEach { element in
            switch element {
            case .move(to: let point):
                points.append(point)
            case .line(to: let point):
                points.append(point)
            case .quadCurve(to: let endPoint, control: let controlPoint):
                points.append(controlPoint)
                points.append(endPoint)
            case .curve(to: let endPoint, control1: let control1Point, control2: let control2Point):
                points.append(control1Point)
                points.append(control2Point)
                points.append(endPoint)
            case .closeSubpath:
                break
            }
        }
        return points
    }
}
