//
//  NewPointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

/// New event-driven pointer tool protocol
protocol NewPointerTool: AnyObject {
    var toolName: PointerToolName { get }
    var needsAccessoryView: Bool { get }
    
    /// Handle an event and return a response
    func handleEvent(_ event: PointerEvent) -> ToolResponse
    
    /// Render any preview or temporary drawing
    func renderPreview(context: GraphicsContext)
    
    /// Reset tool state (called when switching tools)
    func reset()
}

/// Default implementations for common functionality
extension NewPointerTool {
    var needsAccessoryView: Bool { false }
    
    func renderPreview(context: GraphicsContext) {
        // Default: no preview
    }
    
    func reset() {
        // Default: no state to reset
    }
}

/// Helper for finding markers at points
struct MarkerFinder {
    let markersManager: MarkersManager
    
    init(markersManager: MarkersManager) {
        self.markersManager = markersManager
    }
    
    func findMarkerAt(_ point: CGPoint) -> (Marker, Int)? {
        // Iterate in reverse order so top markers are hit first
        for (index, marker) in markersManager.markers.enumerated().reversed() {
            if marker.contains(point) {
                return (marker, index)
            }
        }
        return nil
    }
    
    func findEditableMarkerAt(_ point: CGPoint) -> EditableMarker? {
        guard let (marker, index) = findMarkerAt(point) else { return nil }
        return EditableMarker(marker: marker, index: index)
    }
}

/// Wrapper for markers that can be edited
struct EditableMarker {
    let marker: Marker
    let index: Int
    
    var canEdit: Bool {
        return marker is TextMarker
    }
    
    var centerPoint: CGPoint {
        let representation = marker.getRepresentation()
        switch representation {
        case .text(let textRep):
            return CGPoint(
                x: textRep.frame.midX,
                y: textRep.frame.midY
            )
        case .path(let path):
            return path.boundingRect.center
        default:
            return .zero
        }
    }
}

/// Extension to get center point of CGRect
extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}