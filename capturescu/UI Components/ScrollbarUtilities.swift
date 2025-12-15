//
//  ScrollbarUtilities.swift
//  capturescu
//
//  Utility functions and performance optimizations for custom scrollbars
//

import SwiftUI

/// Performance optimizations for scrollbar calculations
extension ScrollbarState {
    /// Debounced content bounds update to avoid excessive recalculations
    private static var contentUpdateWorkItem: DispatchWorkItem?
    
    func debouncedUpdateContentBounds(image: CapturedPasteboardImage?, markers: [Marker], delay: TimeInterval = 0.1) {
        Self.contentUpdateWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                self?.updateContentBounds(image: image, markers: markers)
            }
        }
        
        Self.contentUpdateWorkItem = workItem
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    /// Calculate if scrolling is needed with performance caching
    var scrollingNeeded: (horizontal: Bool, vertical: Bool) {
        let horizontal = contentBounds.width > viewportBounds.width
        let vertical = contentBounds.height > viewportBounds.height
        return (horizontal, vertical)
    }
    
    /// Get scroll limits for bounds checking
    var scrollLimits: (maxX: CGFloat, maxY: CGFloat) {
        let maxX = max(0, contentBounds.width - viewportBounds.width)
        let maxY = max(0, contentBounds.height - viewportBounds.height)
        return (maxX, maxY)
    }
}

/// macOS-specific scrollbar appearance customizations
extension ScrollbarConfig {
    /// Adaptive colors based on system appearance
    static var adaptiveTrackColor: Color {
        Color(NSColor.controlColor).opacity(0.3)
    }
    
    static var adaptiveThumbColor: Color {
        Color(NSColor.controlTextColor).opacity(0.4)
    }
    
    static var adaptiveThumbHoverColor: Color {
        Color(NSColor.controlTextColor).opacity(0.6)
    }
    
    /// System scrollbar behavior preferences
    static var respectSystemScrollbarBehavior: Bool {
        NSScroller.preferredScrollerStyle == .overlay
    }
    
    /// Calculate thumb size with system-appropriate ratios
    static func calculateThumbSize(contentSize: CGFloat, viewportSize: CGFloat, trackSize: CGFloat) -> CGFloat {
        guard contentSize > viewportSize else { return trackSize }
        
        let ratio = viewportSize / contentSize
        let thumbSize = trackSize * ratio
        
        // Apply macOS-appropriate minimum thumb size
        return max(thumbMinLength, thumbSize)
    }
}

/// Gesture coordination helpers
extension View {
    /// Modifier to handle scrollbar gesture priority
    func scrollbarGesturePriority() -> some View {
        self.highPriorityGesture(
            DragGesture()
                .onChanged { _ in }
                .onEnded { _ in }
        )
    }
}

/// Extension for smooth scrollbar animations
extension Animation {
    static var scrollbarFade: Animation {
        .easeInOut(duration: ScrollbarConfig.animationDuration)
    }
    
    static var scrollbarThumbHover: Animation {
        .easeInOut(duration: 0.1)
    }
}