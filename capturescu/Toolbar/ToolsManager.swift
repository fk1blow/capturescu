//
//  SelectionManager.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

class ToolsManager: ObservableObject {
    @Published var selectedColor: MarkerColor = .red
    // @Published var pointerTool: any PointerTool = FreehandPointerTool(color: MarkerColor.red)
    @Published var pointerTool: any PointerTool = TextPointerTool(color: MarkerColor.red)

    var selectedTextSize: Float = 12.0
    var selectedStrokeWidth: Float = 1

    func selectTool(named toolName: PointerToolName) {
        switch toolName {
        case .FreehandPointer:
            pointerTool = FreehandPointerTool(color: selectedColor)
        case .ArrowPointer:
            pointerTool = ArrowPointerTool(color: selectedColor)
        case .LinePointer:
            pointerTool = LinePointerTool(color: selectedColor)
        case .TextPointer:
            pointerTool = TextPointerTool(color: selectedColor)
        }
    }

    func changeToolColor(with color: MarkerColor) {
        selectedColor = color
        // when you want to change colors, it makes sense to swap
        // a pencil(of a specific color) with another one(of a different color)
        selectTool(named: pointerTool.toolName)
    }
}
