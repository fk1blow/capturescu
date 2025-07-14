//
//  GestureHandlers.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

// MARK: - Selection Gesture Handler

class SelectionGestureHandler: ObservableObject {
    @Published var isSelecting = false
    @Published var isDragging = false
    
    private var dragStartLocation: CGPoint = .zero
    private var lastDragLocation: CGPoint = .zero
    
    func handleSelectionStart(at location: CGPoint, markersManager: MarkersManager) {
        guard markersManager.isHovering else { return }
        
        isSelecting = true
        isDragging = true  // Start dragging immediately for responsive feel
        dragStartLocation = location
        lastDragLocation = location
        
        // The InteractionStateManager will handle the actual selection
        markersManager.handleInteractionEvent(.mouseDown(location: location))
    }
    
    func handleSelectionDrag(at location: CGPoint, markersManager: MarkersManager) {
        guard isSelecting else { return }
        
        let delta = CGPoint(x: location.x - lastDragLocation.x, y: location.y - lastDragLocation.y)
        lastDragLocation = location
        
        // Always send drag events for immediate feedback
        markersManager.handleInteractionEvent(.mouseDrag(location: location, delta: delta))
    }
    
    func handleSelectionEnd(at location: CGPoint, markersManager: MarkersManager) {
        defer {
            isSelecting = false
            isDragging = false
            dragStartLocation = .zero
            lastDragLocation = .zero
        }
        
        markersManager.handleInteractionEvent(.mouseUp(location: location))
    }
    
    // Removed shouldStartDragging - dragging now starts immediately for better responsiveness
}

// MARK: - Drawing Gesture Handler

class DrawingGestureHandler: ObservableObject {
    @Published var isDrawing = false
    
    private var drawingStartLocation: CGPoint = .zero
    
    func handleDrawingStart(at location: CGPoint, markersManager: MarkersManager, toolsManager: ToolsManager) {
        guard !markersManager.isHovering else { return }
        
        isDrawing = true
        drawingStartLocation = location
        
        // Notify state manager and start drawing
        markersManager.handleInteractionEvent(.startDrawing)
        toolsManager.pointerTool.beginMarker(at: location)
    }
    
    func handleDrawingDrag(at location: CGPoint, toolsManager: ToolsManager) {
        guard isDrawing else { return }
        
        toolsManager.pointerTool.updateMarker(at: location)
    }
    
    func handleDrawingEnd(at location: CGPoint, markersManager: MarkersManager, toolsManager: ToolsManager) {
        defer {
            isDrawing = false
            drawingStartLocation = .zero
        }
        
        guard isDrawing else { return }
        
        // Complete the drawing
        let marker = toolsManager.pointerTool.getMarker()
        toolsManager.pointerTool.endMarker(at: location)
        
        // Add marker to manager and notify state manager
        markersManager.addMarker(marker: marker)
        markersManager.handleInteractionEvent(.stopDrawing)
    }
    
    func cancelDrawing(toolsManager: ToolsManager) {
        guard isDrawing else { return }
        
        isDrawing = false
        drawingStartLocation = .zero
        toolsManager.pointerTool.clearMarker()
    }
}

// MARK: - Unified Gesture Coordinator

class GestureCoordinator: ObservableObject {
    @Published var currentGestureType: GestureType = .none
    
    private let selectionHandler = SelectionGestureHandler()
    private let drawingHandler = DrawingGestureHandler()
    
    enum GestureType {
        case none
        case selection
        case drawing
    }
    
    // MARK: - Gesture Detection
    
    func handleGestureStart(at location: CGPoint, markersManager: MarkersManager, toolsManager: ToolsManager) {
        // Update mouse position first
        markersManager.handleInteractionEvent(.mouseMove(location: location))
        
        // Determine gesture type based on current state
        if markersManager.isHovering {
            currentGestureType = .selection
            selectionHandler.handleSelectionStart(at: location, markersManager: markersManager)
        } else {
            currentGestureType = .drawing
            drawingHandler.handleDrawingStart(at: location, markersManager: markersManager, toolsManager: toolsManager)
        }
    }
    
    func handleGestureDrag(at location: CGPoint, markersManager: MarkersManager, toolsManager: ToolsManager) {
        // Always update mouse position
        markersManager.handleInteractionEvent(.mouseMove(location: location))
        
        switch currentGestureType {
        case .selection:
            selectionHandler.handleSelectionDrag(at: location, markersManager: markersManager)
        case .drawing:
            drawingHandler.handleDrawingDrag(at: location, toolsManager: toolsManager)
        case .none:
            break
        }
    }
    
    func handleGestureEnd(at location: CGPoint, markersManager: MarkersManager, toolsManager: ToolsManager) {
        // Update mouse position
        markersManager.handleInteractionEvent(.mouseMove(location: location))
        
        switch currentGestureType {
        case .selection:
            selectionHandler.handleSelectionEnd(at: location, markersManager: markersManager)
        case .drawing:
            drawingHandler.handleDrawingEnd(at: location, markersManager: markersManager, toolsManager: toolsManager)
        case .none:
            break
        }
        
        currentGestureType = .none
    }
    
    func handleMouseMove(at location: CGPoint, markersManager: MarkersManager) {
        // Only handle mouse movement if no gesture is active
        guard currentGestureType == .none else { return }
        
        markersManager.handleInteractionEvent(.mouseMove(location: location))
    }
    
    func handleMouseExit(markersManager: MarkersManager) {
        // Clear any hover state when mouse leaves the view
        markersManager.handleInteractionEvent(.clearSelection)
    }
    
    // MARK: - Click Handling
    
    func handleClick(at location: CGPoint, markersManager: MarkersManager, toolsManager: ToolsManager) {
        // Update mouse position
        markersManager.handleInteractionEvent(.mouseMove(location: location))
        
        // If clicking on empty space, clear selection
        if !markersManager.isHovering {
            markersManager.handleInteractionEvent(.clearSelection)
        }
        
        // Handle tool-specific click actions
        toolsManager.pointerTool.pointerClicked(at: location)
    }
    
    // MARK: - State Queries
    
    var isProcessingGesture: Bool {
        return currentGestureType != .none
    }
    
    var isSelecting: Bool {
        return selectionHandler.isSelecting
    }
    
    var isDragging: Bool {
        return selectionHandler.isDragging
    }
    
    var isDrawing: Bool {
        return drawingHandler.isDrawing
    }
}