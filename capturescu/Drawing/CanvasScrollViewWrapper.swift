//
//  CanvasScrollViewWrapper.swift
//  capturescu
//
//  Created by Claude Code
//

import SwiftUI
import AppKit

struct CanvasScrollViewWrapper<Content: View>: NSViewRepresentable {
    let content: Content
    @Binding var canvasOffset: CGPoint
    let contentBounds: CGRect
    let viewportSize: CGSize
    
    // Callback for when scrollbar position changes
    var onScrollChanged: ((CGPoint) -> Void)?
    
    init(
        canvasOffset: Binding<CGPoint>,
        contentBounds: CGRect,
        viewportSize: CGSize,
        onScrollChanged: ((CGPoint) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self._canvasOffset = canvasOffset
        self.contentBounds = contentBounds
        self.viewportSize = viewportSize
        self.onScrollChanged = onScrollChanged
        self.content = content()
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        
        // Configure scrollbar appearance and behavior
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false // Always visible when needed
        scrollView.scrollerStyle = .overlay // Don't take up content space
        scrollView.allowsMagnification = false // Disable zoom for now
        scrollView.usesPredominantAxisScrolling = false // Allow free scrolling
        
        // macOS version compatibility
        if #available(macOS 15.0, *) {
            // Workaround for Sequoia autohiding issues
            scrollView.scrollerKnobStyle = .default
        }
        
        // Create a hosting view for our SwiftUI content
        let hostingView = NSHostingView(rootView: content)
        scrollView.documentView = hostingView
        
        // Set up scroll notifications
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { _ in
            context.coordinator.handleScrollChanged(scrollView)
        }
        
        // Initial setup
        context.coordinator.updateScrollView(scrollView, wrapper: self)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.updateScrollView(nsView, wrapper: self)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: CanvasScrollViewWrapper
        private var isUpdatingFromCanvas = false
        
        init(_ parent: CanvasScrollViewWrapper) {
            self.parent = parent
        }
        
        func updateScrollView(_ scrollView: NSScrollView, wrapper: CanvasScrollViewWrapper) {
            guard let documentView = scrollView.documentView else { return }
            
            // Update document size based on content bounds
            let docSize = calculateDocumentSize(for: wrapper.contentBounds, viewport: wrapper.viewportSize)
            documentView.frame = CGRect(origin: .zero, size: docSize)
            
            // Update scrollbar visibility and thumb proportions
            updateScrollbarAppearance(scrollView, contentBounds: wrapper.contentBounds, viewport: wrapper.viewportSize)
            
            // Sync scroll position with canvas offset (without triggering callback)
            if !isUpdatingFromCanvas {
                isUpdatingFromCanvas = true
                syncScrollPositionFromCanvas(scrollView, canvasOffset: wrapper.canvasOffset, contentBounds: wrapper.contentBounds)
                isUpdatingFromCanvas = false
            }
        }
        
        func handleScrollChanged(_ scrollView: NSScrollView) {
            guard !isUpdatingFromCanvas else { return }
            
            // Convert scroll position back to canvas offset
            let scrollPoint = scrollView.contentView.bounds.origin
            let canvasOffset = convertScrollPositionToCanvasOffset(scrollPoint, contentBounds: parent.contentBounds)
            
            // Update the binding
            parent.canvasOffset = canvasOffset
            parent.onScrollChanged?(canvasOffset)
        }
        
        private func calculateDocumentSize(for contentBounds: CGRect, viewport: CGSize) -> CGSize {
            // Document size should encompass the content bounds
            let minWidth = max(contentBounds.maxX - contentBounds.minX, viewport.width)
            let minHeight = max(contentBounds.maxY - contentBounds.minY, viewport.height)
            
            return CGSize(
                width: minWidth + abs(contentBounds.minX) * 2, // Add padding for negative coordinates
                height: minHeight + abs(contentBounds.minY) * 2
            )
        }
        
        private func updateScrollbarAppearance(_ scrollView: NSScrollView, contentBounds: CGRect, viewport: CGSize) {
            let docSize = calculateDocumentSize(for: contentBounds, viewport: viewport)
            
            // Calculate proportions for thumb sizing
            let horizontalProportion = min(1.0, viewport.width / docSize.width)
            let verticalProportion = min(1.0, viewport.height / docSize.height)
            
            // Show scrollbars only when needed
            let needsHorizontalScroller = horizontalProportion < 1.0
            let needsVerticalScroller = verticalProportion < 1.0
            
            scrollView.hasHorizontalScroller = needsHorizontalScroller
            scrollView.hasVerticalScroller = needsVerticalScroller
            
            // Update thumb proportions
            if needsHorizontalScroller {
                scrollView.horizontalScroller?.knobProportion = horizontalProportion
            }
            if needsVerticalScroller {
                scrollView.verticalScroller?.knobProportion = verticalProportion
            }
        }
        
        private func syncScrollPositionFromCanvas(_ scrollView: NSScrollView, canvasOffset: CGPoint, contentBounds: CGRect) {
            // Convert canvas offset to scroll position
            let scrollPoint = convertCanvasOffsetToScrollPosition(canvasOffset, contentBounds: contentBounds)
            
            // Update scroll position
            scrollView.contentView.scroll(scrollPoint)
        }
        
        private func convertCanvasOffsetToScrollPosition(_ canvasOffset: CGPoint, contentBounds: CGRect) -> CGPoint {
            // Canvas offset represents how much the content has been moved
            // Scroll position represents how much we've scrolled into the document
            // They are inversely related
            return CGPoint(
                x: -canvasOffset.x + abs(contentBounds.minX),
                y: -canvasOffset.y + abs(contentBounds.minY)
            )
        }
        
        private func convertScrollPositionToCanvasOffset(_ scrollPoint: CGPoint, contentBounds: CGRect) -> CGPoint {
            // Inverse of the above conversion
            return CGPoint(
                x: -(scrollPoint.x - abs(contentBounds.minX)),
                y: -(scrollPoint.y - abs(contentBounds.minY))
            )
        }
    }
}

// MARK: - Content Bounds Calculation

extension CanvasScrollViewWrapper {
    /// Calculate the bounds that encompass all content (image + annotations)
    static func calculateContentBounds(
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
            let markerBounds = marker.boundingBox
            if bounds == .zero {
                bounds = markerBounds
            } else {
                bounds = bounds.union(markerBounds)
            }
        }
        
        // If still no content, use a default size
        if bounds == .zero {
            bounds = CGRect(x: -250, y: -250, width: 500, height: 500)
        }
        
        // Add padding buffer for better UX
        return bounds.insetBy(dx: -padding, dy: -padding)
    }
}