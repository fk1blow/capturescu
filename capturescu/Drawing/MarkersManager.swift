//
//  MarkersManager.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct MarkerSelection {
    var atIndex: Int
    var marker: Marker
}

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
    
    func undo() {
        guard let command = undoStack.popLast() else { return }
        
        command.undo()
        redoStack.append(command)
        
        updateCanUndoRedo()
    }
    
    func redo() {
        guard let command = redoStack.popLast() else { return }
        
        command.execute()
        undoStack.append(command)
        
        updateCanUndoRedo()
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
    @Published var hoveredMarker: MarkerSelection?
    @Published var selectedMarker: MarkerSelection?

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
        return hoveredMarker != nil
    }

    // - if theres already a selected marker, remove it and the highlight
    // - if theres an active marker, selected == active marker
    func selectHoveredMarker() {
        if selectedMarker != nil {
            markers[selectedMarker!.atIndex].hideHighlight()
            selectedMarker = nil
        }
        if hoveredMarker != nil {
            selectedMarker = hoveredMarker!
            markers[selectedMarker!.atIndex].showHighlight()
        }
    }

    func clearSelectedMarker() {
        if selectedMarker != nil {
            markers[selectedMarker!.atIndex].hideHighlight()
        }
        selectedMarker = nil
    }

    func setHoveredMarker(on marker: Marker, atIndex: Int) {
        // NSCursor.openHand.set()
        hoveredMarker = MarkerSelection(atIndex: atIndex, marker: marker)
        markers[hoveredMarker!.atIndex].showHighlight()
    }

    func clearHoveredMarker() {
        // NSCursor.arrow.set()

        guard hoveredMarker != nil else { return }

        // clear the highlight if it's not the selected one
        if hoveredMarker?.marker.id != selectedMarker?.marker.id {
            markers[hoveredMarker!.atIndex].hideHighlight()
        }
        hoveredMarker = nil
    }

    func moveSelectedMarker(to location: CGPoint) {
        guard let selectedMarker = selectedMarker, selectedMarker.atIndex < markers.count else {
            return
        }

        let marker = markers[selectedMarker.atIndex]
        let command = MoveMarkerCommand(markersManager: self, markerID: marker.id, deltaX: location.x, deltaY: location.y)
        HistoryManager.shared.execute(command)
    }

    func deleteSelectedMarker() {
        guard selectedMarker != nil else { return }

        let markerToDelete = markers[selectedMarker!.atIndex]
        let indexToDelete = selectedMarker!.atIndex
        
        markers[selectedMarker!.atIndex].hideHighlight()
        
        let command = DeleteMarkerCommand(markersManager: self, marker: markerToDelete, at: indexToDelete)
        HistoryManager.shared.execute(command)
        
        selectedMarker = nil
        hoveredMarker = nil
    }

    func markersPaths() -> [Path] {
        var paths: [Path] = []

        for marker in markers {
            let representation = marker.getRepresentation()

            switch representation {
            case let .path(path):
                paths.append(path)
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
