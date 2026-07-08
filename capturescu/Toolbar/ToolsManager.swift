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
    @Published var currentTool: PointerToolName = ToolsManager.lastCreationTool

    var selectedTextSize: Float = 12.0
    var selectedStrokeWidth: Float = 1

    private var toolBeforeTemporaryHold: PointerToolName?

    /// The last creation tool the user picked, remembered across captures and app
    /// launches so a fresh annotation window opens in the tool they left off with.
    /// Falls back to Freehand on first launch or if the stored value is stale.
    private static let lastToolDefaultsKey = "capturescu.lastCreationTool"
    static var lastCreationTool: PointerToolName {
        get {
            let raw = UserDefaults.standard.string(forKey: lastToolDefaultsKey)
            return raw.flatMap(PointerToolName.init(rawValue:)) ?? .FreehandPointer
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: lastToolDefaultsKey)
        }
    }

    func selectTool(named toolName: PointerToolName) {
        currentTool = toolName
        // Single choke point for every tool change (UI, EventManager, ⌘-hold),
        // so remembering happens here. Only creation tools are stored — the
        // ⌘-hold's switch to Hand and any Selection are filtered out.
        if toolName.isPersistableDefault {
            ToolsManager.lastCreationTool = toolName
        }
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
