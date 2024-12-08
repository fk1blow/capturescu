//
//  FreehandDrawingTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

@Observable class FreehandAnnotationTool: AnnotationTool {
    var name = NamedAnnotationTool.freehand
    var path = Path()

    func begin(at location: CGPoint) {
        path.move(to: location)
    }

    func draw(at location: CGPoint) {
        path.addLine(to: location)
    }

    func end() {
        path.closeSubpath()
        path = Path()
    }
}
