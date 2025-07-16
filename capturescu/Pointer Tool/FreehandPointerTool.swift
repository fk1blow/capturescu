//
//  FreehandPointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

@Observable class FreehandPointerTool: PointerTool {
    let toolName = PointerToolName.FreehandPointer
    
    private var markerColor: MarkerColor
    var currentMarker: DrawingMarker?
    private var isDrawing = false
    private weak var markersManager: MarkersManager?
    private var onStateChange: (() -> Void)?
    
    init(color: MarkerColor, markersManager: MarkersManager) {
        self.markerColor = color
        self.markersManager = markersManager
    }
    
    func handleEvent(_ event: PointerEvent) -> ToolResponse {
        // Skip logging hover events to reduce noise
        if case .hover = event { return .empty }
        if case .hoverEnd = event { return .empty }
        
        switch event {
        case .dragStart(let point):
            beginDrawing(at: point)
            return .continue
            
        case .dragUpdate(let point):
            updateDrawing(at: point)
            return .continue
            
        case .dragEnd(let point):
            return endDrawing(at: point)
            
        case .click(let point):
            // Handle single click as a small dot
            beginDrawing(at: point)
            return endDrawing(at: point)
            
        default:
            return .empty
        }
    }
    
    func renderPreview(context: GraphicsContext) {
        if let marker = currentMarker {
            
            
            marker.draw(onto: context)
        }
    }
    
    func reset() {
        currentMarker = nil
        isDrawing = false
        onStateChange?()
    }
    
    func updateColor(_ color: MarkerColor) {
        markerColor = color
    }
    
    func updateMarkersManager(_ markersManager: MarkersManager) {
        self.markersManager = markersManager
    }
    
    func setStateChangeHandler(_ handler: @escaping () -> Void) {
        onStateChange = handler
    }
    
    // MARK: - Private Methods
    
    private func beginDrawing(at point: CGPoint) {
        var marker = DrawingMarker(markerColor: markerColor)
        marker.path.move(to: point)
        currentMarker = marker
        isDrawing = true
        onStateChange?()
    }
    
    private func updateDrawing(at point: CGPoint) {
        guard isDrawing, var marker = currentMarker else { 
            return 
        }
        
        // Create a new path with the additional point
        var newPath = marker.path
        let pathBoundsBefore = newPath.boundingRect
        newPath.addLine(to: point)
        let pathBoundsAfter = newPath.boundingRect
        
        
        marker.path = newPath
        currentMarker = marker
        
        onStateChange?()
    }
    
    private func endDrawing(at point: CGPoint) -> ToolResponse {
        guard isDrawing, var marker = currentMarker, let markersManager = markersManager else { return .empty }
        
        // Finish the path
        marker.path.addLine(to: point)
        
        // Create command to add marker
        let command = AddMarkerCommand(
            markersManager: markersManager,
            marker: marker
        )
        
        // Reset state AFTER creating the command, but keep the marker reference
        currentMarker = nil
        isDrawing = false
        onStateChange?()
        
        return ToolResponse(
            shouldContinue: false,
            commands: [command]
        )
    }
}

