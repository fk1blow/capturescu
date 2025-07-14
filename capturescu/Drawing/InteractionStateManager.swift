//
//  InteractionStateManager.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

// MARK: - Interaction State Types

enum InteractionState {
    case idle
    case hovering(markerIndex: Int)
    case selecting(markerIndex: Int)
    case dragging(markerIndex: Int)
    case drawing
}

enum InteractionEvent {
    case mouseMove(location: CGPoint)
    case mouseDown(location: CGPoint)
    case mouseUp(location: CGPoint)
    case mouseDrag(location: CGPoint, delta: CGPoint)
    case startDrawing
    case stopDrawing
    case clearSelection
}

// MARK: - Interaction State Manager

class InteractionStateManager: ObservableObject {
    @Published private(set) var currentState: InteractionState = .idle
    @Published private(set) var lastMouseLocation: CGPoint = .zero
    
    private weak var markersManager: MarkersManager?
    private var dragStartPosition: CGPoint = .zero
    private var draggedMarkerID: UUID?
    
    // State validation and debugging
    private var stateHistory: [InteractionState] = []
    private let maxHistorySize = 10
    
    init(markersManager: MarkersManager) {
        self.markersManager = markersManager
    }
    
    // MARK: - Public Interface
    
    func handleEvent(_ event: InteractionEvent) {
        let newState = processEvent(event, currentState: currentState)
        transitionToState(newState)
    }
    
    // MARK: - State Queries
    
    var isHovering: Bool {
        if case .hovering = currentState { return true }
        return false
    }
    
    var isSelecting: Bool {
        if case .selecting = currentState { return true }
        return false
    }
    
    var isDragging: Bool {
        if case .dragging = currentState { return true }
        return false
    }
    
    var isDrawing: Bool {
        if case .drawing = currentState { return true }
        return false
    }
    
    var hoveredMarkerIndex: Int? {
        switch currentState {
        case .hovering(let index), .selecting(let index):
            return index
        default:
            return nil
        }
    }
    
    var selectedMarkerIndex: Int? {
        switch currentState {
        case .selecting(let index), .dragging(let index):
            return index
        default:
            return nil
        }
    }
    
    // MARK: - State Processing
    
    private func processEvent(_ event: InteractionEvent, currentState: InteractionState) -> InteractionState {
        switch (event, currentState) {
        
        // Mouse movement events
        case (.mouseMove(let location), .idle):
            lastMouseLocation = location
            if let hitIndex = findHitMarker(at: location) {
                return .hovering(markerIndex: hitIndex)
            }
            return .idle
            
        case (.mouseMove(let location), .hovering(let currentIndex)):
            lastMouseLocation = location
            if let hitIndex = findHitMarker(at: location) {
                if hitIndex != currentIndex {
                    return .hovering(markerIndex: hitIndex)
                }
                return currentState // Stay hovering same marker
            }
            return .idle
            
        case (.mouseMove(let location), .selecting(let index)):
            lastMouseLocation = location
            // Selection state persists during mouse movement
            return currentState
            
        case (.mouseMove(let location), .dragging):
            lastMouseLocation = location
            // Dragging state persists during mouse movement
            return currentState
            
        // Mouse down events
        case (.mouseDown(let location), .idle):
            lastMouseLocation = location
            if let hitIndex = findHitMarker(at: location) {
                return .selecting(markerIndex: hitIndex)
            }
            return .drawing
            
        case (.mouseDown(let location), .hovering(let index)):
            lastMouseLocation = location
            return .selecting(markerIndex: index)
            
        // Mouse drag events
        case (.mouseDrag(let location, let delta), .selecting(let index)):
            lastMouseLocation = location
            // Always transition to dragging when we get a drag event
            // The GestureCoordinator will handle the drag threshold
            startDragOperation(markerIndex: index)
            return .dragging(markerIndex: index)
            
        case (.mouseDrag(let location, let delta), .dragging(let index)):
            lastMouseLocation = location
            updateDragOperation(delta: delta)
            return currentState
            
        // Mouse up events
        case (.mouseUp(let location), .selecting(let index)):
            lastMouseLocation = location
            // Click without drag - keep selection but check for new hover
            if let hitIndex = findHitMarker(at: location) {
                return .selecting(markerIndex: hitIndex)
            }
            return .idle
            
        case (.mouseUp(let location), .dragging(let index)):
            lastMouseLocation = location
            endDragOperation()
            // After drag, check if we're still over a marker
            if let hitIndex = findHitMarker(at: location) {
                return .hovering(markerIndex: hitIndex)
            }
            return .idle
            
        case (.mouseUp(let location), .drawing):
            lastMouseLocation = location
            // After drawing, check if we're over a marker
            if let hitIndex = findHitMarker(at: location) {
                return .hovering(markerIndex: hitIndex)
            }
            return .idle
            
        // Drawing events
        case (.startDrawing, .idle):
            return .drawing
            
        case (.stopDrawing, .drawing):
            // After drawing stops, check current mouse position
            if let hitIndex = findHitMarker(at: lastMouseLocation) {
                return .hovering(markerIndex: hitIndex)
            }
            return .idle
            
        // Clear selection
        case (.clearSelection, _):
            // Check if we should hover after clearing selection
            if let hitIndex = findHitMarker(at: lastMouseLocation) {
                return .hovering(markerIndex: hitIndex)
            }
            return .idle
            
        default:
            return currentState
        }
    }
    
    // MARK: - State Transitions
    
    private func transitionToState(_ newState: InteractionState) {
        let oldState = currentState
        
        // Exit old state
        exitState(oldState)
        
        // Update current state
        currentState = newState
        
        // Enter new state
        enterState(newState)
        
        // Track state history for debugging
        addToHistory(newState)
    }
    
    private func exitState(_ state: InteractionState) {
        guard let markersManager = markersManager else { return }
        
        switch state {
        case .hovering(let index):
            if index < markersManager.markers.count {
                markersManager.markers[index].hideHighlight()
            }
        case .selecting(let index):
            if index < markersManager.markers.count {
                markersManager.markers[index].hideHighlight()
            }
        case .dragging(let index):
            if index < markersManager.markers.count {
                markersManager.markers[index].hideHighlight()
            }
        case .drawing, .idle:
            break
        }
    }
    
    private func enterState(_ state: InteractionState) {
        guard let markersManager = markersManager else { return }
        
        switch state {
        case .hovering(let index):
            if index < markersManager.markers.count {
                markersManager.markers[index].showHighlight()
            }
        case .selecting(let index):
            if index < markersManager.markers.count {
                markersManager.markers[index].showHighlight()
            }
        case .dragging(let index):
            if index < markersManager.markers.count {
                markersManager.markers[index].showHighlight()
            }
        case .drawing, .idle:
            break
        }
    }
    
    // MARK: - Hit Detection
    
    private func findHitMarker(at location: CGPoint) -> Int? {
        guard let markersManager = markersManager else { return nil }
        
        print("🔍 findHitMarker at \(location), checking \(markersManager.markers.count) markers")
        
        // Check markers in reverse order (top to bottom)
        for (index, marker) in markersManager.markers.enumerated().reversed() {
            let boundingBox = marker.markerBoundingBox(near: location)
            print("  Marker \(index): \(type(of: marker)) -> \(boundingBox != nil ? "HIT" : "MISS")")
            if boundingBox != nil {
                return index
            }
        }
        print("  No markers hit")
        return nil
    }
    
    // MARK: - Drag Operations
    
    // Removed isDragMinimumMet - drag threshold is now handled by GestureCoordinator
    
    private func startDragOperation(markerIndex: Int) {
        guard let markersManager = markersManager,
              markerIndex < markersManager.markers.count else { return }
        
        draggedMarkerID = markersManager.markers[markerIndex].id
        dragStartPosition = .zero
        markersManager.startDragOperation()
    }
    
    private func updateDragOperation(delta: CGPoint) {
        guard let markersManager = markersManager else { return }
        
        markersManager.moveSelectedMarkerDirect(deltaX: delta.x, deltaY: delta.y)
        dragStartPosition = CGPoint(x: dragStartPosition.x + delta.x, y: dragStartPosition.y + delta.y)
    }
    
    private func endDragOperation() {
        guard let markersManager = markersManager else { return }
        
        markersManager.endDragOperation()
        draggedMarkerID = nil
        dragStartPosition = .zero
    }
    
    // MARK: - Debugging Support
    
    private func addToHistory(_ state: InteractionState) {
        stateHistory.append(state)
        if stateHistory.count > maxHistorySize {
            stateHistory.removeFirst()
        }
    }
    
    func getStateHistory() -> [InteractionState] {
        return stateHistory
    }
    
    func getCurrentStateDescription() -> String {
        switch currentState {
        case .idle:
            return "Idle"
        case .hovering(let index):
            return "Hovering marker \(index)"
        case .selecting(let index):
            return "Selecting marker \(index)"
        case .dragging(let index):
            return "Dragging marker \(index)"
        case .drawing:
            return "Drawing"
        }
    }
}

// MARK: - Extensions for State Description

extension InteractionState: CustomStringConvertible {
    var description: String {
        switch self {
        case .idle:
            return "idle"
        case .hovering(let index):
            return "hovering(\(index))"
        case .selecting(let index):
            return "selecting(\(index))"
        case .dragging(let index):
            return "dragging(\(index))"
        case .drawing:
            return "drawing"
        }
    }
}

extension InteractionEvent: CustomStringConvertible {
    var description: String {
        switch self {
        case .mouseMove(let location):
            return "mouseMove(\(location))"
        case .mouseDown(let location):
            return "mouseDown(\(location))"
        case .mouseUp(let location):
            return "mouseUp(\(location))"
        case .mouseDrag(let location, let delta):
            return "mouseDrag(\(location), \(delta))"
        case .startDrawing:
            return "startDrawing"
        case .stopDrawing:
            return "stopDrawing"
        case .clearSelection:
            return "clearSelection"
        }
    }
}