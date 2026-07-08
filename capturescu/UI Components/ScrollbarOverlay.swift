//
//  ScrollbarOverlay.swift
//  capturescu
//
//  Main scrollbar overlay container that positions scrollbars without disrupting Canvas
//

import SwiftUI

/// Main scrollbar overlay that positions horizontal and vertical scrollbars
struct ScrollbarOverlay: View {
    @ObservedObject var scrollbarState: ScrollbarState
    
    var body: some View {
        ZStack {
            // Horizontal scrollbar at bottom
            if scrollbarState.showHorizontalScrollbar {
                VStack {
                    Spacer()
                    HStack {
                        HorizontalScrollbar(
                            canvasWidth: scrollbarState.effectiveCanvasWidth,
                            viewportWidth: scrollbarState.viewportBounds.width,
                            scrollOffset: scrollbarState.horizontalScrollPosition,
                            onScrollToPosition: scrollbarState.scrollToHorizontalPosition
                        )
                        .frame(height: ScrollbarConfig.trackWidth)
                        .padding(.bottom, 20)
                        .padding(.horizontal, 20)
                        
                        // Reserve space for vertical scrollbar corner
                        if scrollbarState.showVerticalScrollbar {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: ScrollbarConfig.trackWidth)
                        }
                    }
                }
            }
            
            // Vertical scrollbar at right
            if scrollbarState.showVerticalScrollbar {
                HStack {
                    Spacer()
                    VStack {
                        VerticalScrollbar(
                            canvasHeight: scrollbarState.effectiveCanvasHeight,
                            viewportHeight: scrollbarState.viewportBounds.height,
                            scrollOffset: scrollbarState.verticalScrollPosition,
                            onScrollToPosition: scrollbarState.scrollToVerticalPosition
                        )
                        .frame(width: ScrollbarConfig.trackWidth)
                        .padding(.trailing, 20)
                        .padding(.vertical, 20)
                        
                        // Reserve space for horizontal scrollbar corner
                        if scrollbarState.showHorizontalScrollbar {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: ScrollbarConfig.trackWidth)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(true)
        .zIndex(1000) // Ensure scrollbars are on top of Canvas interactions
        .animation(.easeInOut(duration: ScrollbarConfig.animationDuration), value: scrollbarState.showHorizontalScrollbar)
        .animation(.easeInOut(duration: ScrollbarConfig.animationDuration), value: scrollbarState.showVerticalScrollbar)
    }
}