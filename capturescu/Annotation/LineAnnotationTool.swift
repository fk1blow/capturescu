//
//  LineDrawingTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

@Observable class LineAnnotationTool: AnnotationTool {
    var name = NamedAnnotationTool.line
    var path = Path()

    private var startPoint = CGPointZero

    func begin(at location: CGPoint) {
        startPoint = location
        path.move(to: location)
    }

    func draw(at location: CGPoint) {
        path = Path { path in
            path.move(to: startPoint)
            path.addLine(to: location)
        }
    }

    func end() {
        path.closeSubpath()
        path = Path()
        startPoint = CGPointZero
    }
}
