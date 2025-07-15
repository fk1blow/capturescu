//
//  NewSelectionTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

@Observable class NewSelectionTool: NewPointerTool {
    let toolName = PointerToolName.TextPointer // No dedicated selection tool in enum yet
    
    private let markerFinder: MarkerFinder
    var isDragging = false
    var dragStartPoint: CGPoint = .zero
    var selectedMarkerIndex: Int?
    
    init(markerFinder: MarkerFinder) {
        self.markerFinder = markerFinder
    }
    
    func handleEvent(_ event: PointerEvent) -> ToolResponse {
        switch event {
        case .click(let point):
            return handleClick(at: point)
            
        case .dragStart(let point):
            return handleDragStart(at: point)
            
        case .dragUpdate(let point):
            return handleDragUpdate(at: point)
            
        case .dragEnd(let point):
            return handleDragEnd(at: point)
            
        case .hover(let point):
            return handleHover(at: point)
            
        case .hoverEnd:
            return ToolResponse(cursorUpdate: .default)
            
        case .keyPressed(.delete):
            return handleDeleteKey()
            
        default:
            return .empty
        }
    }
    
    func reset() {
        isDragging = false
        dragStartPoint = .zero
        selectedMarkerIndex = nil
    }
    
    // MARK: - Event Handlers
    
    private func handleClick(at point: CGPoint) -> ToolResponse {
        if let editableMarker = markerFinder.findEditableMarkerAt(point) {
            if editableMarker.canEdit {
                // Switch to text tool for editing
                return ToolResponse(
                    shouldContinue: true,
                    toolSwitch: .textTool,
                    editMarker: (editableMarker.marker, editableMarker.index)
                )
            } else {
                // Select marker for movement
                selectedMarkerIndex = editableMarker.index
                return ToolResponse(
                    shouldContinue: true,
                    cursorUpdate: .move
                )
            }
        } else {
            // Clear selection
            selectedMarkerIndex = nil
            return ToolResponse(
                shouldContinue: true,
                cursorUpdate: .default,
                clearSelection: true
            )
        }
    }
    
    private func handleDragStart(at point: CGPoint) -> ToolResponse {
        if let editableMarker = markerFinder.findEditableMarkerAt(point) {
            selectedMarkerIndex = editableMarker.index
            isDragging = true
            dragStartPoint = point
            return ToolResponse(
                shouldContinue: true,
                cursorUpdate: .move
            )
        }
        return .empty
    }
    
    private func handleDragUpdate(at point: CGPoint) -> ToolResponse {
        guard isDragging, let _ = selectedMarkerIndex else { return .empty }
        
        // Calculate movement delta
        let _ = point.x - dragStartPoint.x
        let _ = point.y - dragStartPoint.y
        
        // Update drag start point for next update
        dragStartPoint = point
        
        // Return movement command
        // Note: This will need to be handled by EventManager to create proper move commands
        return ToolResponse(
            shouldContinue: true,
            cursorUpdate: .move
        )
    }
    
    private func handleDragEnd(at point: CGPoint) -> ToolResponse {
        guard isDragging, let _ = selectedMarkerIndex else { return .empty }
        
        // Calculate total movement
        let totalDeltaX = point.x - dragStartPoint.x
        let totalDeltaY = point.y - dragStartPoint.y
        
        // Reset drag state
        isDragging = false
        dragStartPoint = .zero
        
        // Create move command if there was actual movement
        if abs(totalDeltaX) > 1 || abs(totalDeltaY) > 1 {
            // This would need to be handled by EventManager
            // For now, return empty - will be improved in integration
            return ToolResponse(
                shouldContinue: false,
                cursorUpdate: .pointer
            )
        }
        
        return ToolResponse(
            shouldContinue: false,
            cursorUpdate: .pointer
        )
    }
    
    private func handleHover(at point: CGPoint) -> ToolResponse {
        if markerFinder.findMarkerAt(point) != nil {
            return ToolResponse(
                shouldContinue: true,
                cursorUpdate: .pointer
            )
        } else {
            return ToolResponse(
                shouldContinue: true,
                cursorUpdate: .default
            )
        }
    }
    
    private func handleDeleteKey() -> ToolResponse {
        guard let markerIndex = selectedMarkerIndex else { return .empty }
        
        // Create delete command
        // This would need marker reference from EventManager
        // For now, return empty - will be improved in integration
        selectedMarkerIndex = nil
        
        return ToolResponse(
            shouldContinue: false,
            cursorUpdate: .default,
            clearSelection: true
        )
    }
}