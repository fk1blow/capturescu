//
//  AnnotationToolManager.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation

// TODO remove in favor of the SelectionManager
@Observable class AnnotationToolManager {
    var tool: AnnotationTool = FreehandAnnotationTool()

    var selectedTool: NamedAnnotationTool = .freehand {
        didSet {
            switch selectedTool {
            case NamedAnnotationTool.arrow:
                tool = ArrowAnnotationTool()
            case NamedAnnotationTool.freehand:
                tool = FreehandAnnotationTool()
            case NamedAnnotationTool.line:
                tool = LineAnnotationTool()
            }
        }
    }
}
