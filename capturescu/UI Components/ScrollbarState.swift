//
//  ScrollbarState.swift
//  capturescu
//
//  State management for scrollbar visibility, sizing, and coordinate mapping
//

import SwiftUI
import Combine

/// Manages scrollbar state and coordinates between Canvas and scrollbar components
class ScrollbarState: ObservableObject {
    // Canvas content bounds (what's actually drawable)
    @Published var contentBounds: CGRect = .zero
    
    // Viewport bounds (visible area)
    @Published var viewportBounds: CGRect = .zero
    
    // Current pan offset from DrawingSurfaceView
    @Published var canvasOffset: CGPoint = .zero
    
    // Visibility state
    @Published var showHorizontalScrollbar: Bool = false
    @Published var showVerticalScrollbar: Bool = false
    
    // Auto-hide timer
    private var hideTimer: Timer?
    private let hideDelay: TimeInterval = 2.0
    
    /// Calculate content bounds based on image and markers
    func updateContentBounds(image: CapturedPasteboardImage?, markers: [Marker]) {
        var newBounds = CGRect.zero
        
        // Start with image bounds if available
        if let image = image {
            newBounds = CGRect(
                x: image.position.x,
                y: image.position.y,
                width: image.naturalSize.width,
                height: image.naturalSize.height
            )
        }
        
        // Expand to include all markers
        for marker in markers {
            let markerRepresentation = marker.getRepresentation()
            let markerBounds: CGRect
            
            switch markerRepresentation {
            case .path(let path):
                markerBounds = path.boundingRect
            case .text(let textRep):
                markerBounds = textRep.frame
            default:
                continue
            }
            
            if newBounds == .zero {
                newBounds = markerBounds
            } else {
                newBounds = newBounds.union(markerBounds)
            }
        }
        
        // Add padding around content
        if newBounds != .zero {
            let padding: CGFloat = 100
            newBounds = newBounds.insetBy(dx: -padding, dy: -padding)
        }
        
        self.contentBounds = newBounds
        updateScrollbarVisibility()
    }
    
    /// Update viewport bounds from GeometryReader
    func updateViewportBounds(_ bounds: CGRect) {
        self.viewportBounds = bounds
        updateScrollbarVisibility()
    }
    
    /// Update canvas offset from DrawingSurfaceView panning
    func updateCanvasOffset(_ offset: CGPoint) {
        self.canvasOffset = offset
        resetHideTimer()
    }
    
    /// Check if scrollbars should be visible
    private func updateScrollbarVisibility() {
        let needsHorizontalScroll = contentBounds.width > viewportBounds.width
        let needsVerticalScroll = contentBounds.height > viewportBounds.height
        
        showHorizontalScrollbar = needsHorizontalScroll
        showVerticalScrollbar = needsVerticalScroll
        
        if showHorizontalScrollbar || showVerticalScrollbar {
            resetHideTimer()
        }
    }
    
    /// Reset the auto-hide timer
    private func resetHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: hideDelay, repeats: false) { _ in
            // Keep scrollbars visible (disable auto-hide as requested)
            // This timer structure is kept for future customization
        }
    }
    
    /// Convert scrollbar position to canvas offset
    func scrollToHorizontalPosition(_ position: CGFloat) {
        let maxScroll = max(0, contentBounds.width - viewportBounds.width)
        let newOffset = CGPoint(x: -position, y: canvasOffset.y)
        canvasOffset = CGPoint(
            x: max(-maxScroll, min(0, newOffset.x)),
            y: newOffset.y
        )
    }
    
    /// Convert scrollbar position to canvas offset
    func scrollToVerticalPosition(_ position: CGFloat) {
        let maxScroll = max(0, contentBounds.height - viewportBounds.height)
        let newOffset = CGPoint(x: canvasOffset.x, y: -position)
        canvasOffset = CGPoint(
            x: newOffset.x,
            y: max(-maxScroll, min(0, newOffset.y))
        )
    }
    
    /// Get horizontal scroll position from canvas offset
    var horizontalScrollPosition: CGFloat {
        return -canvasOffset.x
    }
    
    /// Get vertical scroll position from canvas offset
    var verticalScrollPosition: CGFloat {
        return -canvasOffset.y
    }
    
    /// Get effective canvas width for scrollbar calculation
    var effectiveCanvasWidth: CGFloat {
        return max(contentBounds.width, viewportBounds.width)
    }
    
    /// Get effective canvas height for scrollbar calculation
    var effectiveCanvasHeight: CGFloat {
        return max(contentBounds.height, viewportBounds.height)
    }
}