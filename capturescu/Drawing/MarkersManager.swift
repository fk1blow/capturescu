//
//  MarkersManager.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI


protocol MarkerCommand {
    func execute()
    func undo()
    var description: String { get }
}

// MARK: - History Manager
class HistoryManager: ObservableObject {
    private var undoStack: [MarkerCommand] = []
    private var redoStack: [MarkerCommand] = []
    
    private let maxHistorySize = 50
    
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    
    // Callback to notify about undo/redo operations
    var onUndoRedo: (() -> Void)?
    
    static let shared = HistoryManager()
    
    private init() {}
    
    func execute(_ command: MarkerCommand) {
        command.execute()
        
        undoStack.append(command)
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }
        
        redoStack.removeAll()
        
        updateCanUndoRedo()
    }
    
    // Add a command to history without executing it (for operations already performed)
    func addToHistory(_ command: MarkerCommand) {
        undoStack.append(command)
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }
        
        redoStack.removeAll()
        
        updateCanUndoRedo()
    }
    
    func undo() {
        guard let command = undoStack.popLast() else { return }
        
        command.undo()
        redoStack.append(command)
        
        updateCanUndoRedo()
        
        // Notify tools about undo operation
        onUndoRedo?()
    }
    
    func redo() {
        guard let command = redoStack.popLast() else { return }
        
        command.execute()
        undoStack.append(command)
        
        updateCanUndoRedo()
        
        // Notify tools about redo operation
        onUndoRedo?()
    }
    
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateCanUndoRedo()
    }
    
    private func updateCanUndoRedo() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    var undoDescription: String? {
        undoStack.last?.description
    }
    
    var redoDescription: String? {
        redoStack.last?.description
    }
}

class MarkersManager: ObservableObject {
    @Published var markers: [Marker] = []
    @Published var selectedMarkerIndex: Int? = nil
    @Published var hoveredMarkerIndex: Int? = nil
    /// Marker currently open in the inline text editor. It's hidden on the
    /// canvas while editing so the editor field is the only thing shown.
    @Published var editingMarkerID: UUID? = nil
    
    // Simplified drag state tracking
    private var isDragging = false
    private var dragStartPosition: CGPoint = .zero
    private var draggedMarkerID: UUID?
    
    
    // Set up undo/redo notification callback
    func setupUndoRedoNotification(toolsManager: ToolsManager) {
        HistoryManager.shared.onUndoRedo = { [weak toolsManager] in
            toolsManager?.pointerTool.onUndoRedo()
        }
    }
    
    
    var hoveredMarker: Marker? {
        guard let index = hoveredMarkerIndex, index < markers.count else { return nil }
        return markers[index]
    }
    
    var selectedMarker: Marker? {
        guard let index = selectedMarkerIndex, index < markers.count else { return nil }
        return markers[index]
    }
    
    var isHovering: Bool {
        return hoveredMarkerIndex != nil
    }

    func addMarker(marker: Marker) {
        let command = AddMarkerCommand(markersManager: self, marker: marker)
        HistoryManager.shared.execute(command)
    }
    
    func updateMarker(at index: Int, with newMarker: Marker) {
        guard index >= 0 && index < markers.count else { return }
        let oldMarker = markers[index]
        let command = UpdateMarkerCommand(markersManager: self, oldMarker: oldMarker, newMarker: newMarker, at: index)
        HistoryManager.shared.execute(command)
    }

    func isMarkerHovered() -> Bool {
        return isHovering
    }

    // Dead simple selection methods
    func selectMarker(at point: CGPoint) {
        let index = findMarkerIndex(at: point)
        selectedMarkerIndex = index
        
        // Update highlighting
        clearAllHighlights()
        if let index = index, index < markers.count {
            markers[index].showHighlight()
        }
    }
    
    func hoverMarker(at point: CGPoint) {
        let index = findMarkerIndex(at: point)

        // Clear the previously hovered marker's flag if hover moved to another
        // marker (or off all markers).
        if let previous = hoveredMarkerIndex, previous != index, previous < markers.count {
            markers[previous].hideHover()
        }

        hoveredMarkerIndex = index
        if let index = index, index < markers.count {
            markers[index].showHover()
        }
    }

    func clearSelection() {
        selectedMarkerIndex = nil
        clearAllHighlights()
    }

    func clearHover() {
        if let previous = hoveredMarkerIndex, previous < markers.count {
            markers[previous].hideHover()
        }
        hoveredMarkerIndex = nil
    }
    
    // Single efficient hit detection method
    private func findMarkerIndex(at point: CGPoint) -> Int? {
        // Iterate in reverse order so top markers are hit first
        return markers.lastIndex { marker in
            marker.contains(point)
        }
    }
    
    // Helper method to clear all marker highlights
    private func clearAllHighlights() {
        for i in 0..<markers.count {
            markers[i].hideHighlight()
        }
    }

    // Simplified single method for marker movement
    func moveMarker(markerID: UUID, by delta: CGPoint) {
        guard markers.firstIndex(where: { $0.id == markerID }) != nil else {
            return
        }
        
        // Create and execute the move command
        let command = MoveMarkerCommand(markersManager: self, markerID: markerID, deltaX: delta.x, deltaY: delta.y)
        HistoryManager.shared.execute(command)
    }
    
    // Start a drag operation - called once when drag begins
    func startDragOperation() {
        guard let selectedIndex = selectedMarkerIndex, selectedIndex < markers.count else {
            return
        }
        
        isDragging = true
        draggedMarkerID = markers[selectedIndex].id
        dragStartPosition = .zero // Reset cumulative delta
    }
    
    // Move marker during drag without creating commands - called repeatedly during drag
    func moveSelectedMarkerDirect(deltaX: CGFloat, deltaY: CGFloat) {
        guard let selectedIndex = selectedMarkerIndex, selectedIndex < markers.count else {
            return
        }
        
        // Direct movement without command creation
        markers[selectedIndex].offsetMarkerBy(dx: deltaX, dy: deltaY)
        
        // Track cumulative movement for consolidated command
        if isDragging {
            dragStartPosition = CGPoint(x: dragStartPosition.x + deltaX, y: dragStartPosition.y + deltaY)
        }
    }
    
    // End drag operation and create a single consolidated command
    func endDragOperation() {
        guard isDragging,
              let markerID = draggedMarkerID,
              dragStartPosition.x != 0 || dragStartPosition.y != 0 else {
            // Reset state even if no actual movement occurred
            isDragging = false
            dragStartPosition = .zero
            draggedMarkerID = nil
            return
        }
        
        // Create a single command for the entire drag operation
        // Use addToHistory() instead of execute() since the movement was already performed during drag
        let command = MoveMarkerCommand(markersManager: self, markerID: markerID, deltaX: dragStartPosition.x, deltaY: dragStartPosition.y)
        HistoryManager.shared.addToHistory(command)
        
        // Reset drag state
        isDragging = false
        dragStartPosition = .zero
        draggedMarkerID = nil
    }
    
    // Legacy method - now just calls the direct movement (for backward compatibility)
    func moveSelectedMarker(to location: CGPoint) {
        moveSelectedMarkerDirect(deltaX: location.x, deltaY: location.y)
    }

    func deleteSelectedMarker() {
        guard let selectedIndex = selectedMarkerIndex else { return }

        let markerToDelete = markers[selectedIndex]
        
        markers[selectedIndex].hideHighlight()
        
        let command = DeleteMarkerCommand(markersManager: self, marker: markerToDelete, at: selectedIndex)
        HistoryManager.shared.execute(command)
        
        selectedMarkerIndex = nil
        clearAllHighlights()
    }

    func markersPaths() -> [Path] {
        var paths: [Path] = []

        for marker in markers {
            let representation = marker.getRepresentation()

            switch representation {
            case let .path(path):
                paths.append(path)
            case let .text(textRep):
                // Create a path from the text frame for bounding box calculation
                let textPath = Path(textRep.frame)
                paths.append(textPath)
            default:
                break
            }
        }

        return paths
    }
}

// MARK: - Commands
class AddMarkerCommand: MarkerCommand {
    private let markersManager: MarkersManager
    private let marker: Marker
    
    init(markersManager: MarkersManager, marker: Marker) {
        self.markersManager = markersManager
        self.marker = marker
    }
    
    func execute() {
        markersManager.markers.append(marker)
    }
    
    func undo() {
        if let index = markersManager.markers.firstIndex(where: { $0.id == marker.id }) {
            markersManager.markers.remove(at: index)
        }
    }
    
    var description: String {
        "Add marker"
    }
}

class DeleteMarkerCommand: MarkerCommand {
    private let markersManager: MarkersManager
    private let marker: Marker
    private let index: Int
    
    init(markersManager: MarkersManager, marker: Marker, at index: Int) {
        self.markersManager = markersManager
        self.marker = marker
        self.index = index
    }
    
    func execute() {
        if index < markersManager.markers.count && markersManager.markers[index].id == marker.id {
            markersManager.markers.remove(at: index)
        }
    }
    
    func undo() {
        if index <= markersManager.markers.count {
            markersManager.markers.insert(marker, at: index)
        }
    }
    
    var description: String {
        "Delete marker"
    }
}

class MoveMarkerCommand: MarkerCommand {
    private let markersManager: MarkersManager
    private let markerID: UUID
    private let deltaX: CGFloat
    private let deltaY: CGFloat
    
    init(markersManager: MarkersManager, markerID: UUID, deltaX: CGFloat, deltaY: CGFloat) {
        self.markersManager = markersManager
        self.markerID = markerID
        self.deltaX = deltaX
        self.deltaY = deltaY
    }
    
    func execute() {
        if let index = markersManager.markers.firstIndex(where: { $0.id == markerID }) {
            markersManager.markers[index].offsetMarkerBy(dx: deltaX, dy: deltaY)
        }
    }
    
    func undo() {
        if let index = markersManager.markers.firstIndex(where: { $0.id == markerID }) {
            markersManager.markers[index].offsetMarkerBy(dx: -deltaX, dy: -deltaY)
        }
    }
    
    var description: String {
        "Move marker"
    }
}

class UpdateMarkerCommand: MarkerCommand {
    private let markersManager: MarkersManager
    private let oldMarker: Marker
    private let newMarker: Marker
    private let index: Int
    
    init(markersManager: MarkersManager, oldMarker: Marker, newMarker: Marker, at index: Int) {
        self.markersManager = markersManager
        self.oldMarker = oldMarker
        self.newMarker = newMarker
        self.index = index
    }
    
    func execute() {
        if index < markersManager.markers.count && markersManager.markers[index].id == oldMarker.id {
            markersManager.markers[index] = newMarker
        }
    }
    
    func undo() {
        if index < markersManager.markers.count && markersManager.markers[index].id == newMarker.id {
            markersManager.markers[index] = oldMarker
        }
    }
    
    var description: String {
        "Update marker"
    }
}
