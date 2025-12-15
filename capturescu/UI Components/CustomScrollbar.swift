//
//  CustomScrollbar.swift
//  capturescu
//
//  Custom scrollbar overlay components that match macOS aesthetics
//

import SwiftUI

/// Configuration for scrollbar appearance and behavior
struct ScrollbarConfig {
    // Visual appearance
    static let trackWidth: CGFloat = 16
    static let thumbMinLength: CGFloat = 30
    static let cornerRadius: CGFloat = 8
    static let thumbInset: CGFloat = 2
    
    // Colors matching macOS scrollbars (now adaptive)
    static var trackColor: Color { adaptiveTrackColor }
    static var thumbColor: Color { adaptiveThumbColor }
    static var thumbHoverColor: Color { adaptiveThumbHoverColor }
    
    // Animation
    static let animationDuration: Double = 0.2
    static let fadeDelay: Double = 1.5
}

/// Horizontal scrollbar component
struct HorizontalScrollbar: View {
    let canvasWidth: CGFloat
    let viewportWidth: CGFloat
    let scrollOffset: CGFloat
    let onScrollToPosition: (CGFloat) -> Void
    
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragStartOffset: CGFloat = 0
    @State private var dragStartThumbPosition: CGFloat = 0
    
    private var contentRatio: CGFloat {
        guard canvasWidth > 0 else { return 1.0 }
        return viewportWidth / canvasWidth
    }
    
    private var thumbWidth: CGFloat {
        ScrollbarConfig.calculateThumbSize(
            contentSize: canvasWidth,
            viewportSize: viewportWidth,
            trackSize: trackWidth
        )
    }
    
    private var trackWidth: CGFloat {
        viewportWidth - ScrollbarConfig.thumbInset * 2
    }
    
    private var thumbPosition: CGFloat {
        guard canvasWidth > viewportWidth else { return ScrollbarConfig.thumbInset }
        let scrollableWidth = canvasWidth - viewportWidth
        let availableTrackWidth = trackWidth - thumbWidth
        let position = (scrollOffset / scrollableWidth) * availableTrackWidth
        return ScrollbarConfig.thumbInset + max(0, min(availableTrackWidth, position))
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Track background
            Rectangle()
                .fill(ScrollbarConfig.trackColor)
                .frame(height: ScrollbarConfig.trackWidth)
                .cornerRadius(ScrollbarConfig.cornerRadius)
            
            // Thumb
            Rectangle()
                .fill(isHovering || isDragging ? ScrollbarConfig.thumbHoverColor : ScrollbarConfig.thumbColor)
                .frame(width: thumbWidth, height: ScrollbarConfig.trackWidth - ScrollbarConfig.thumbInset * 2)
                .cornerRadius(ScrollbarConfig.cornerRadius - 1)
                .offset(x: thumbPosition)
                .animation(.easeInOut(duration: ScrollbarConfig.animationDuration), value: isHovering)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        dragStartOffset = scrollOffset
                        dragStartThumbPosition = thumbPosition
                    }
                    
                    let deltaX = value.translation.x
                    let availableTrackWidth = trackWidth - thumbWidth
                    guard availableTrackWidth > 0 else { return }
                    
                    let scrollRatio = deltaX / availableTrackWidth
                    let scrollableWidth = canvasWidth - viewportWidth
                    let newOffset = dragStartOffset + (scrollRatio * scrollableWidth)
                    
                    onScrollToPosition(max(0, min(scrollableWidth, newOffset)))
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
}

/// Vertical scrollbar component
struct VerticalScrollbar: View {
    let canvasHeight: CGFloat
    let viewportHeight: CGFloat
    let scrollOffset: CGFloat
    let onScrollToPosition: (CGFloat) -> Void
    
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragStartOffset: CGFloat = 0
    @State private var dragStartThumbPosition: CGFloat = 0
    
    private var contentRatio: CGFloat {
        guard canvasHeight > 0 else { return 1.0 }
        return viewportHeight / canvasHeight
    }
    
    private var thumbHeight: CGFloat {
        ScrollbarConfig.calculateThumbSize(
            contentSize: canvasHeight,
            viewportSize: viewportHeight,
            trackSize: trackHeight
        )
    }
    
    private var trackHeight: CGFloat {
        viewportHeight - ScrollbarConfig.thumbInset * 2
    }
    
    private var thumbPosition: CGFloat {
        guard canvasHeight > viewportHeight else { return ScrollbarConfig.thumbInset }
        let scrollableHeight = canvasHeight - viewportHeight
        let availableTrackHeight = trackHeight - thumbHeight
        let position = (scrollOffset / scrollableHeight) * availableTrackHeight
        return ScrollbarConfig.thumbInset + max(0, min(availableTrackHeight, position))
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Track background
            Rectangle()
                .fill(ScrollbarConfig.trackColor)
                .frame(width: ScrollbarConfig.trackWidth)
                .cornerRadius(ScrollbarConfig.cornerRadius)
            
            // Thumb
            Rectangle()
                .fill(isHovering || isDragging ? ScrollbarConfig.thumbHoverColor : ScrollbarConfig.thumbColor)
                .frame(width: ScrollbarConfig.trackWidth - ScrollbarConfig.thumbInset * 2, height: thumbHeight)
                .cornerRadius(ScrollbarConfig.cornerRadius - 1)
                .offset(y: thumbPosition)
                .animation(.easeInOut(duration: ScrollbarConfig.animationDuration), value: isHovering)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        dragStartOffset = scrollOffset
                        dragStartThumbPosition = thumbPosition
                    }
                    
                    let deltaY = value.translation.y
                    let availableTrackHeight = trackHeight - thumbHeight
                    guard availableTrackHeight > 0 else { return }
                    
                    let scrollRatio = deltaY / availableTrackHeight
                    let scrollableHeight = canvasHeight - viewportHeight
                    let newOffset = dragStartOffset + (scrollRatio * scrollableHeight)
                    
                    onScrollToPosition(max(0, min(scrollableHeight, newOffset)))
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
}