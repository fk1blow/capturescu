//
//  CanvasContentBounds.swift
//  capturescu
//
//  Created by Claude Code
//

import Foundation
import SwiftUI

/// Manages dynamic content bounds calculation for the infinite canvas
class CanvasContentBounds: ObservableObject {
    @Published private(set) var currentBounds: CGRect = .zero
    
    private var cachedBounds: CGRect = .zero
    private var cacheInvalidated = true
    
    /// Calculate content bounds based on current image and markers
    func updateBounds(
        image: CapturedPasteboardImage?,
        markers: [any Marker],
        padding: CGFloat = 500
    ) {
        guard cacheInvalidated else { return }
        
        let newBounds = calculateBounds(image: image, markers: markers, padding: padding)
        
        if newBounds != cachedBounds {
            cachedBounds = newBounds
            currentBounds = newBounds
        }
        
        cacheInvalidated = false
    }
    
    /// Mark cache as invalid to force recalculation
    func invalidateCache() {
        cacheInvalidated = true
    }
    
    private func calculateBounds(
        image: CapturedPasteboardImage?,
        markers: [any Marker],
        padding: CGFloat
    ) -> CGRect {
        var bounds = CGRect.zero
        
        // Include image bounds if present
        if let image = image {
            let imageRect = CGRect(
                origin: image.position,
                size: CGSize(
                    width: CGFloat(image.image.width) * image.scale,
                    height: CGFloat(image.image.height) * image.scale
                )
            )
            bounds = imageRect
        }
        
        // Include all marker bounds
        for marker in markers {
            // Use the marker's representation to get bounds
            let representation = marker.getRepresentation()
            let markerRect: CGRect
            
            switch representation {
            case .path(let path):
                markerRect = path.boundingRect
            case .text(let textRep):
                markerRect = textRep.frame
            case .image:
                // For images, we'll use a default small rect or skip
                continue
            }
            
            if bounds == .zero {
                bounds = markerRect
            } else {
                bounds = bounds.union(markerRect)
            }
        }
        
        // If still no content, use a default size centered at origin
        if bounds == .zero {
            bounds = CGRect(x: -250, y: -250, width: 500, height: 500)
        }
        
        // Add padding buffer for better UX - ensures scrollbars appear before hitting edges
        return bounds.insetBy(dx: -padding, dy: -padding)
    }
    
    /// Get bounds for a specific set of content (without caching)
    static func calculateBounds(
        image: CapturedPasteboardImage?,
        markers: [any Marker],
        padding: CGFloat = 500
    ) -> CGRect {
        var bounds = CGRect.zero
        
        // Include image bounds if present
        if let image = image {
            let imageRect = CGRect(
                origin: image.position,
                size: CGSize(
                    width: CGFloat(image.image.width) * image.scale,
                    height: CGFloat(image.image.height) * image.scale
                )
            )
            bounds = imageRect
        }
        
        // Include all marker bounds
        for marker in markers {
            // Use the marker's representation to get bounds
            let representation = marker.getRepresentation()
            let markerRect: CGRect
            
            switch representation {
            case .path(let path):
                markerRect = path.boundingRect
            case .text(let textRep):
                markerRect = textRep.frame
            case .image:
                // For images, we'll use a default small rect or skip
                continue
            }
            
            if bounds == .zero {
                bounds = markerRect
            } else {
                bounds = bounds.union(markerRect)
            }
        }
        
        // If still no content, use a default size
        if bounds == .zero {
            bounds = CGRect(x: -250, y: -250, width: 500, height: 500)
        }
        
        // Add padding buffer
        return bounds.insetBy(dx: -padding, dy: -padding)
    }
}