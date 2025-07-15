//
//  ToolsManager.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

class ToolsManager: ObservableObject {
    @Published var selectedColor: MarkerColor = .red
    @Published var currentTool: PointerToolName = .TextPointer
    
    var selectedTextSize: Float = 12.0
    var selectedStrokeWidth: Float = 1

    func selectTool(named toolName: PointerToolName) {
        currentTool = toolName
    }

    func changeToolColor(with color: MarkerColor) {
        selectedColor = color
    }
}

// MARK: - Legacy Compatibility
// This extension provides compatibility with old code that expects pointerTool property
extension ToolsManager {
    // Dummy object to satisfy legacy code that accesses .toolName
    var pointerTool: LegacyPointerToolCompat {
        return LegacyPointerToolCompat(toolName: currentTool)
    }
}

// Minimal compatibility object for legacy code
struct LegacyPointerToolCompat {
    let toolName: PointerToolName
    
    func onUndoRedo() {
        // No-op for legacy compatibility
    }
}
