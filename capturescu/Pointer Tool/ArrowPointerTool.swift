//
//  ArrowPointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

@Observable class ArrowPointerTool: PointerTool {
    let toolName = PointerToolName.ArrowPointer
    
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
            // Handle single click as a small arrow
            beginDrawing(at: point)
            let endPoint = CGPoint(x: point.x + 20, y: point.y)
            return endDrawing(at: endPoint)
            
        default:
            return .empty
        }
    }
    
    func renderPreview(context: GraphicsContext) {
        guard isDrawing, let start = startPoint, let end = currentEndPoint else { return }
        
        // Draw preview arrow
        let arrowPath = createArrowPath(from: start, to: end)
        let strokeColor = markerColor.color
        context.stroke(arrowPath, with: .color(strokeColor), lineWidth: 2.0)
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
        
        // Create arrow marker using DrawingMarker
        var marker = DrawingMarker(markerColor: markerColor)
        marker.path = createArrowPath(from: start, to: point)
        
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
    
    private func createArrowPath(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        
        // Main line
        path.move(to: start)
        path.addLine(to: end)
        
        // Arrow head
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = 0.5
        
        let angle = atan2(end.y - start.y, end.x - start.x)
        
        let arrowPoint1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        
        let arrowPoint2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        path.move(to: end)
        path.addLine(to: arrowPoint1)
        path.move(to: end)
        path.addLine(to: arrowPoint2)
        
        return path
    }
}