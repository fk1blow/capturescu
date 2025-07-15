//
//  PointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

enum PointerToolName {
    case FreehandPointer
    case LinePointer
    case ArrowPointer
    case TextPointer
    case SelectionPointer
}

protocol PointerTool {
    var toolName: PointerToolName { get }

    func beginMarker(at location: CGPoint)
    func updateMarker(at location: CGPoint)
    func endMarker(at location: CGPoint)

    func drawMarker(onto _: GraphicsContext)
    func clearMarker()
    func getMarker() -> Marker

    func renderAccessoryView(onDone: @escaping (_ marker: Marker) -> Void) -> AnyView
    func pointerClicked(at location: CGPoint)
    
    // Called when undo/redo operations might affect the tool's state
    func onUndoRedo()
}

extension PointerTool {
    func renderAccessoryView(onDone _: @escaping (_ marker: Marker) -> Void) -> AnyView {
        return AnyView(EmptyView())
    }

    func pointerClicked(at _: CGPoint) {}

    func beginMarker(at _: CGPoint) {}
    func updateMarker(at _: CGPoint) {}
    func endMarker(at _: CGPoint) {}
    
    func onUndoRedo() {}
}

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
