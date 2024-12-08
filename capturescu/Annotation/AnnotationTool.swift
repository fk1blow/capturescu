//
//  AnnotationTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

// TODO: implement this to the tools, canvas, toolbar
protocol AnnotationDrawing {
    var path: Path { get set }
    var strokeColor: Color { get set }
    var fillColor: Color { get set }
}

protocol AnnotationTool {
    var name: NamedAnnotationTool { get }
    var path: Path { get set }

    func begin(at location: CGPoint)
    func draw(at location: CGPoint)
    func end()
}

enum NamedAnnotationTool: String, CaseIterable {
    case line
    case freehand
    case arrow

    var icon: String {
        switch self {
        case .line: return "line.diagonal"
        case .freehand: return "pencil.and.scribble"
        case .arrow: return "arrow.down.left"
        }
    }
}

extension AnnotationTool {
    func hasFill() -> Bool {
        switch self.name {
        case .arrow:
            return true
        default:
            return false
        }
    }
}
