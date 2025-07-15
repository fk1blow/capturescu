//
//  NewFreehandPointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

@Observable class NewFreehandPointerTool: NewPointerTool {
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
        
        print("🖍️ FreehandTool handling event: \(event)")
        switch event {
        case .dragStart(let point):
            print("   Starting freehand drawing at: \(point)")
            beginDrawing(at: point)
            return .continue
            
        case .dragUpdate(let point):
            updateDrawing(at: point)
            return .continue
            
        case .dragEnd(let point):
            print("   Ending freehand drawing at: \(point)")
            return endDrawing(at: point)
            
        case .click(let point):
            print("   Freehand click at: \(point)")
            // Handle single click as a small dot
            beginDrawing(at: point)
            return endDrawing(at: point)
            
        default:
            print("   Freehand tool ignoring event")
            return .empty
        }
    }
    
    func renderPreview(context: GraphicsContext) {
        if let marker = currentMarker {
            print("🖌️ FreehandTool rendering preview - path bounds: \(marker.path.boundingRect), isDrawing: \(isDrawing)")
            
            // Debug: Draw a test circle at the current path end to verify rendering
            if isDrawing {
                let pathBounds = marker.path.boundingRect
                if !pathBounds.isEmpty {
                    let testCircle = Path(ellipseIn: CGRect(x: pathBounds.maxX - 3, y: pathBounds.maxY - 3, width: 6, height: 6))
                    context.fill(testCircle, with: .color(.blue))
                }
            }
            
            marker.draw(onto: context)
        } else {
            print("🖌️ FreehandTool renderPreview - no current marker")
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
            print("🖍️ updateDrawing failed - isDrawing: \(isDrawing), currentMarker: \(currentMarker != nil)")
            return 
        }
        
        // Create a new path with the additional point
        var newPath = marker.path
        let pathBoundsBefore = newPath.boundingRect
        newPath.addLine(to: point)
        let pathBoundsAfter = newPath.boundingRect
        
        print("🖍️ updateDrawing - point: \(point)")
        print("   Path bounds before: \(pathBoundsBefore)")
        print("   Path bounds after: \(pathBoundsAfter)")
        print("   Path isEmpty before: \(pathBoundsBefore.isEmpty)")
        print("   Path isEmpty after: \(pathBoundsAfter.isEmpty)")
        
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

