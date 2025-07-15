//
//  SelectionPointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

/// Legacy selection tool implementation for UI compatibility
/// The actual selection logic is handled by NewSelectionTool through EventManager
class SelectionPointerTool: PointerTool {
    let toolName = PointerToolName.SelectionPointer
    private let color: MarkerColor
    
    init(color: MarkerColor) {
        self.color = color
    }
    
    // These methods are not used since the new EventManager handles selection
    func beginMarker(at location: CGPoint) {}
    func updateMarker(at location: CGPoint) {}
    func endMarker(at location: CGPoint) {}
    func drawMarker(onto: GraphicsContext) {}
    func clearMarker() {}
    func getMarker() -> Marker {
        // Return a dummy marker - this shouldn't be called
        return TextMarker(markerColor: color)
    }
    func pointerClicked(at location: CGPoint) {}
    func onUndoRedo() {}
}