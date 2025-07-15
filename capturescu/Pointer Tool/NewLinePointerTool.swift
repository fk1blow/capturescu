//
//  NewLinePointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

@Observable class NewLinePointerTool: NewPointerTool {
    let toolName = PointerToolName.LinePointer
    
    private var markerColor: MarkerColor
    var startPoint: CGPoint?
    var currentEndPoint: CGPoint?
    var isDrawing = false
    private weak var markersManager: MarkersManager?
    
    init(color: MarkerColor, markersManager: MarkersManager) {
        self.markerColor = color
        self.markersManager = markersManager
    }
    
    func handleEvent(_ event: PointerEvent) -> ToolResponse {
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
        guard isDrawing, let start = startPoint, let end = currentEndPoint else { return }
        
        // Draw preview line
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        
        let strokeColor = markerColor.color
        context.stroke(path, with: .color(strokeColor), lineWidth: 2.0)
    }
    
    func reset() {
        startPoint = nil
        currentEndPoint = nil
        isDrawing = false
    }
    
    func updateColor(_ color: MarkerColor) {
        markerColor = color
    }
    
    func updateMarkersManager(_ markersManager: MarkersManager) {
        self.markersManager = markersManager
    }
    
    // MARK: - Private Methods
    
    private func beginDrawing(at point: CGPoint) {
        startPoint = point
        currentEndPoint = point
        isDrawing = true
    }
    
    private func updateDrawing(at point: CGPoint) {
        guard isDrawing else { return }
        currentEndPoint = point
    }
    
    private func endDrawing(at point: CGPoint) -> ToolResponse {
        guard isDrawing, let start = startPoint, let markersManager = markersManager else { return .empty }
        
        // Create line marker using DrawingMarker
        var marker = DrawingMarker(markerColor: markerColor)
        marker.path.move(to: start)
        marker.path.addLine(to: point)
        
        // Create command to add marker
        let command = AddMarkerCommand(
            markersManager: markersManager,
            marker: marker
        )
        
        // Reset state
        reset()
        
        return ToolResponse(
            shouldContinue: false,
            commands: [command]
        )
    }
}