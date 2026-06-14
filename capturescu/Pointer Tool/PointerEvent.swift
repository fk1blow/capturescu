//
//  PointerEvent.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

/// Events that can be sent to pointer tools
enum PointerEvent {
    // Basic interaction events
    case click(CGPoint)
    case doubleClick(CGPoint)
    case dragStart(CGPoint)
    case dragUpdate(CGPoint)
    case dragEnd(CGPoint)
    case hover(CGPoint)
    case hoverEnd
    
    // Editing-specific events
    case editMarker(Marker, at: CGPoint, index: Int)
    case cancelEdit
    case accessoryAction(AccessoryAction)
    
    // Keyboard events
    case keyPressed(KeyEvent)
}

/// Actions from accessory views (like text input)
enum AccessoryAction {
    case show(CGPoint)
    case hide
    case textSubmitted(String, CGRect)
    case textCancelled
    case resize(CGRect)
    case move(CGPoint)
}

/// Keyboard events
enum KeyEvent {
    case delete
    case escape
    case enter
    case tab
    case space
}

/// Cursor types for visual feedback
enum CursorType {
    case `default`
    case pointer
    case text
    case crosshair
    case move
    case resize
}

/// Tool switching requests
enum ToolSwitchRequest {
    case textTool
    case freehandTool
    case lineTool
    case arrowTool
    case selectionTool
    case handTool
}

/// Response from a tool after handling an event
struct ToolResponse {
    let shouldContinue: Bool
    let commands: [MarkerCommand]
    let accessoryView: AnyView?
    let cursorUpdate: CursorType?
    let clearSelection: Bool
    let toolSwitch: ToolSwitchRequest?
    let editMarker: (Marker, Int)?
    
    init(
        shouldContinue: Bool = false,
        commands: [MarkerCommand] = [],
        accessoryView: AnyView? = nil,
        cursorUpdate: CursorType? = nil,
        clearSelection: Bool = false,
        toolSwitch: ToolSwitchRequest? = nil,
        editMarker: (Marker, Int)? = nil
    ) {
        self.shouldContinue = shouldContinue
        self.commands = commands
        self.accessoryView = accessoryView
        self.cursorUpdate = cursorUpdate
        self.clearSelection = clearSelection
        self.toolSwitch = toolSwitch
        self.editMarker = editMarker
    }
}

/// Helper for empty responses
extension ToolResponse {
    static let empty = ToolResponse()
    static let `continue` = ToolResponse(shouldContinue: true)
}