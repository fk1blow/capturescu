//
//  SelectionTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

@Observable class SelectionTool: PointerTool {
    let toolName = PointerToolName.SelectionPointer
    
    private let markerFinder: MarkerFinder
    var isDragging = false
    var dragStartPoint: CGPoint = .zero
    var selectedMarkerIndex: Int?
    var selectedMarkerID: UUID?
    private weak var markersManager: MarkersManager?
    
    init(markerFinder: MarkerFinder) {
        self.markerFinder = markerFinder
        self.markersManager = markerFinder.markersManager
    }
    
    func handleEvent(_ event: PointerEvent) -> ToolResponse {
        switch event {
        case .click(let point):
            return handleClick(at: point)
            
        case .doubleClick(let point):
            return handleDoubleClick(at: point)
            
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
        selectedMarkerID = nil
        
        // Clear highlighting when resetting
        markersManager?.clearSelection()
    }
    
    // MARK: - Event Handlers
    
    private func handleClick(at point: CGPoint) -> ToolResponse {
        if let editableMarker = markerFinder.findEditableMarkerAt(point) {
            // In selection mode, always select markers for movement, don't auto-edit
            selectedMarkerIndex = editableMarker.index
            selectedMarkerID = editableMarker.marker.id
            
            // Update highlighting through MarkersManager
            markersManager?.selectMarker(at: point)
            
            return ToolResponse(
                shouldContinue: true,
                cursorUpdate: .move
            )
        } else {
            // Clear selection
            selectedMarkerIndex = nil
            selectedMarkerID = nil
            
            // Clear highlighting through MarkersManager
            markersManager?.clearSelection()
            
            return ToolResponse(
                shouldContinue: true,
                cursorUpdate: .default,
                clearSelection: true
            )
        }
    }
    
    private func handleDoubleClick(at point: CGPoint) -> ToolResponse {
        
        if let editableMarker = markerFinder.findEditableMarkerAt(point) {
            
            if editableMarker.canEdit {
                // Switch to text tool for editing on double-click
                return ToolResponse(
                    shouldContinue: true,
                    toolSwitch: .textTool,
                    editMarker: (editableMarker.marker, editableMarker.index)
                )
            } else {
                // Non-editable marker, just select it
                selectedMarkerIndex = editableMarker.index
                selectedMarkerID = editableMarker.marker.id
                
                // Update highlighting through MarkersManager
                markersManager?.selectMarker(at: point)
                
                return ToolResponse(
                    shouldContinue: true,
                    cursorUpdate: .move
                )
            }
        } else {
            // No marker at double-click location, clear selection
            selectedMarkerIndex = nil
            selectedMarkerID = nil
            
            // Clear highlighting through MarkersManager
            markersManager?.clearSelection()
            
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
            selectedMarkerID = editableMarker.marker.id
            isDragging = true
            dragStartPoint = point
            
            // Update highlighting through MarkersManager
            markersManager?.selectMarker(at: point)
            
            return ToolResponse(
                shouldContinue: true,
                cursorUpdate: .move
            )
        }
        return .empty
    }
    
    private func handleDragUpdate(at point: CGPoint) -> ToolResponse {
        guard isDragging, let markerID = selectedMarkerID, let markersManager = markersManager else { return .empty }
        
        // Calculate movement delta
        let deltaX = point.x - dragStartPoint.x
        let deltaY = point.y - dragStartPoint.y
        
        // Update drag start point for next update
        dragStartPoint = point
        
        // Create move command for this update
        let moveCommand = MoveMarkerCommand(
            markersManager: markersManager,
            markerID: markerID,
            deltaX: deltaX,
            deltaY: deltaY
        )
        
        return ToolResponse(
            shouldContinue: true,
            commands: [moveCommand],
            cursorUpdate: .move
        )
    }
    
    private func handleDragEnd(at point: CGPoint) -> ToolResponse {
        guard isDragging else { return .empty }
        
        // Reset drag state
        isDragging = false
        dragStartPoint = .zero
        
        // Keep the marker selected after drag
        return ToolResponse(
            shouldContinue: true,
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
        guard let markerIndex = selectedMarkerIndex, 
              let markersManager = markersManager,
              markerIndex < markersManager.markers.count else { return .empty }
        
        let markerToDelete = markersManager.markers[markerIndex]
        
        // Create delete command
        let deleteCommand = DeleteMarkerCommand(
            markersManager: markersManager,
            marker: markerToDelete,
            at: markerIndex
        )
        
        // Clear selection and highlighting
        selectedMarkerIndex = nil
        selectedMarkerID = nil
        markersManager.clearSelection()
        
        return ToolResponse(
            shouldContinue: true,
            commands: [deleteCommand],
            cursorUpdate: .default,
            clearSelection: true
        )
    }
}