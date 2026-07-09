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

    /// Stroke width for freehand / line / arrow, and font size for text. Both are
    /// @Published so the toolbar's size control and the canvas react live. The text
    /// default tracks `TextMarkerFont.defaultSize` so there's a single source of
    /// truth for the starting font size.
    @Published var selectedTextSize: CGFloat = TextMarkerFont.defaultSize
    @Published var selectedStrokeWidth: CGFloat = 3

    /// Allowed ranges for the contextual size control, shared by the toolbar
    /// slider and the +/- keyboard shortcuts so both stay clamped identically.
    static let textSizeRange: ClosedRange<CGFloat> = 10 ... 48
    static let strokeWidthRange: ClosedRange<CGFloat> = 1 ... 20

    /// Nudge the current tool's size by `delta` points, clamped to its range.
    /// Adjusts font size for the text tool, stroke width for freehand/line/arrow,
    /// and is a no-op for tools without an adjustable size (Hand, Selection).
    func adjustCurrentToolSize(by delta: CGFloat) {
        if currentTool.usesFontSize {
            let r = Self.textSizeRange
            selectedTextSize = min(max(selectedTextSize + delta, r.lowerBound), r.upperBound)
        } else if currentTool.usesStrokeWidth {
            let r = Self.strokeWidthRange
            selectedStrokeWidth = min(max(selectedStrokeWidth + delta, r.lowerBound), r.upperBound)
        }
    }

    private var toolBeforeTemporaryHold: PointerToolName?

    /// The tool whose contextual size the toolbar should reflect. During a
    /// temporary hold (⌘-pan) `currentTool` is Hand, but we keep showing the size
    /// of the creation tool being held so the picker doesn't blink out of the
    /// toolbar every time the user grabs ⌘ to reposition a marker.
    var sizingTool: PointerToolName {
        toolBeforeTemporaryHold ?? currentTool
    }

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
