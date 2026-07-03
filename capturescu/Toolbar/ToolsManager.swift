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

    private var toolBeforeTemporaryHold: PointerToolName?

    func selectTool(named toolName: PointerToolName) {
        currentTool = toolName
    }

    /// Temporarily switch to `tool`, remembering the current one so it can be
    /// restored. No-op if a hold is already active or we're already on `tool`.
    func beginTemporaryTool(_ tool: PointerToolName) {
        guard toolBeforeTemporaryHold == nil, currentTool != tool else { return }
        toolBeforeTemporaryHold = currentTool
        selectTool(named: tool)
    }

    /// Revert a temporary hold started by `beginTemporaryTool`, if any.
    func endTemporaryTool() {
        guard let previous = toolBeforeTemporaryHold else { return }
        toolBeforeTemporaryHold = nil
        selectTool(named: previous)
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
