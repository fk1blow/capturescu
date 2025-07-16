//
//  ContentView.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import OnPasteboardChange
import SwiftUI

struct CapturedPasteboardImage {
    var image: CGImage
    var position: CGPoint
    var scale: CGFloat = 1.0
    
    // Computed property for display size in points
    var displaySize: CGSize {
        return CGSize(
            width: CGFloat(image.width) * scale,
            height: CGFloat(image.height) * scale
        )
    }
}

struct ContentView: View, KeyboardCommandResponder {
    @EnvironmentObject var markersManager: MarkersManager
    @EnvironmentObject var toolsManager: ToolsManager
    @ObservedObject private var windowSizeManager = WindowSizeManager.shared

    @State var capturedImage: CapturedPasteboardImage?
    @State var drawingSurfaceBounds: CGRect = .init()

    var body: some View {
        VStack(spacing: 0) {
            // Custom draggable area (where title bar would be)
            DraggableAreaView()
                .frame(height: 0)
                .background(Color.clear)

            ZStack(alignment: .center) {
//                DrawingSurfaceView(capturedImage: capturedImage)
                DrawingSurfaceView(capturedImage: capturedImage)
                    .background(GeometryGetter(rect: $drawingSurfaceBounds))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear(perform: {
                        // Re-enabled after fixing race condition issues
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            handlePasteAction()
                        }
                    })

                ToolbarView()

                // annotation bounds indicator/background
                // great for debugging
                // Rectangle()
                //     .fill(.black)
                //     .zIndex(0)
                //     .frame(width: annotationsBoundingBox.size.width, height: annotationsBoundingBox.size.height)
                //     .position(annotationsBoundingBox.position)
                //     .opacity(1)
            }
        }
        .keyboardCommands(handler: self)
    }

    func processCommand(_ command: KeyboardCommand) {

        switch command {
        case .copy:
            handleCopyAction()

        case .paste:
            handlePasteAction()
            
        case .selectArrowTool:
            toolsManager.selectTool(named: PointerToolName.ArrowPointer)
            
        case .selectFreehandTool:
            toolsManager.selectTool(named: PointerToolName.FreehandPointer)
            
        case .selectLineTool:
            toolsManager.selectTool(named: PointerToolName.LinePointer)
            
        case .selectTextTool:
            toolsManager.selectTool(named: PointerToolName.TextPointer)
            
        case .selectSelectionTool:
            toolsManager.selectTool(named: .SelectionPointer)
            
        case .undo:
            HistoryManager.shared.undo()
            
        case .redo:
            HistoryManager.shared.redo()

        default:
            break
        }
    }
    
    private func getDisplayScaleFactor() -> CGFloat {
        // Try to get scale from the window's current screen for better multi-display support
        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first,
           let screen = window.screen {
            let scale = screen.backingScaleFactor
            // Validate scale factor to prevent edge cases
            return validateScaleFactor(scale)
        }
        
        // Fallback to main screen
        let fallbackScale = NSScreen.main?.backingScaleFactor ?? 1.0
        return validateScaleFactor(fallbackScale)
    }
    
    private func validateScaleFactor(_ scale: CGFloat) -> CGFloat {
        // Ensure scale factor is within reasonable bounds
        return (scale > 0 && scale <= 10.0) ? scale : 1.0
    }
    
    private func calculateRendererScale(
        capturedImage: CapturedPasteboardImage?,
        markersBounds: CGRect
    ) -> CGFloat? {
        let screenScale = getDisplayScaleFactor()
        
        // Validate screen scale to prevent edge cases
        guard screenScale > 0 && screenScale <= 10.0 else {
            return nil
        }
        
        // If we have a captured image, calculate scale to preserve original dimensions
        guard let capturedImage = capturedImage else {
            return screenScale
        }
        
        // Validate bounds to prevent division by zero and invalid dimensions
        guard validateBounds(markersBounds) else {
            return nil
        }
        
        let originalImageSize = CGSize(
            width: CGFloat(capturedImage.image.width),
            height: CGFloat(capturedImage.image.height)
        )
        
        // Validate original image dimensions
        guard validateImageSize(originalImageSize) else {
            return nil
        }
        
        // Calculate scale to preserve original pixel dimensions
        let baseScale = calculateBaseScale(
            originalSize: originalImageSize,
            boundsSize: markersBounds.size
        )
        
        guard let validBaseScale = baseScale else {
            return nil
        }
        
        // NO-SCALING APPROACH: Always render at 1.0 scale to preserve exact pixel data
        // External apps will handle their own display scaling as needed
        let preserveOriginalScale: CGFloat = 1.0
        
        // Debug logging to verify the scaling fix
        print("DEBUG COPY: baseScale=\(validBaseScale), screenScale=\(screenScale), final=\(preserveOriginalScale)")
        print("DEBUG COPY: originalSize=\(originalImageSize), boundsSize=\(markersBounds.size)")
        
        // Final validation of the preserve scale
        guard preserveOriginalScale > 0 && preserveOriginalScale <= 1000.0 else {
            return nil
        }
        
        return preserveOriginalScale
    }
    
    private func validateBounds(_ bounds: CGRect) -> Bool {
        return bounds.width > 0 && bounds.height > 0 &&
               bounds.width <= 32768 && bounds.height <= 32768
    }
    
    private func validateImageSize(_ size: CGSize) -> Bool {
        return size.width > 0 && size.height > 0 &&
               size.width <= 32768 && size.height <= 32768
    }
    
    private func calculateBaseScale(
        originalSize: CGSize,
        boundsSize: CGSize
    ) -> CGFloat? {
        // Calculate scale to preserve original pixel dimensions
        // The renderer scale should make the output match the original image size
        let widthScale = originalSize.width / boundsSize.width
        let heightScale = originalSize.height / boundsSize.height
        let baseScale = min(widthScale, heightScale)
        
        // Validate calculated scale to prevent invalid values
        guard baseScale > 0 && baseScale <= 100.0 else {
            return nil
        }
        
        return baseScale
    }
    
    private func getCurrentImageData() -> (image: CGImage, isCapturescuRendered: Bool)? {
        return NSPasteboard.getImage()
    }

    private func handlePasteAction() {
        guard let imageData = NSPasteboard.getImage() else {
            return
        }
        
        let image = imageData.image
        let isCapturescuRendered = imageData.isCapturescuRendered
        
        let imageSize = CGSize(width: image.width, height: image.height)
        
        // Debug logging to understand the scaling issue
        print("DEBUG PASTE: imageSize=\(imageSize), isCapturescuRendered=\(isCapturescuRendered)")
        
        // Validate image dimensions
        guard imageSize.width > 0 && imageSize.height > 0 else {
            return
        }
        
        let _ = getDisplayScaleFactor()
        
        // Calculate scale factor for the image
        let scale = windowSizeManager.calculateImageScale(for: imageSize)
        
        // Calculate new window size based on scaled image
        let windowSize = windowSizeManager.calculateWindowSize(for: imageSize)
        
        // Resize the window to fit the image with completion callback
        windowSizeManager.resizeWindow(to: windowSize) {
            let _ = self.getDisplayScaleFactor()
            
            // Calculate scaled size in points
            // External images should be displayed at their native pixel size without screen scale conversion
            let scaledSize = CGSize(
                width: imageSize.width * scale,
                height: imageSize.height * scale
            )
            
            // Calculate available space for image (excluding padding and toolbar)
            let availableWidth = windowSize.width - LayoutConstants.totalHorizontalPadding
            let availableHeight = windowSize.height - LayoutConstants.totalVerticalSpace
            
            // Position image in available space with padding
            let x = LayoutConstants.imagePadding + (availableWidth - scaledSize.width) / 2
            let y = LayoutConstants.imagePadding + (availableHeight - scaledSize.height) / 2
            
            capturedImage = CapturedPasteboardImage(
                image: image,
                position: CGPoint(x: x, y: y),
                scale: scale
            )
        }
    }

    private func handleCopyAction() {
        // Ensure we have content to copy
        guard capturedImage != nil || !markersManager.markers.isEmpty else {
            return
        }
        
        let markersBoundingBox = CaptureScreenshotBounds(
            paths: markersManager.markersPaths(), capturedImage: capturedImage
        )

        let renderer = ImageRenderer(
            content: ScreenshotRenderCanvas(
                capturedBounds: markersBoundingBox.bounds,
                capturedImage: capturedImage,
                capturedMarkers: markersManager.markers
            )
        )
        
        // Calculate and set the renderer scale to preserve original image dimensions
        let rendererScale = calculateRendererScale(
            capturedImage: capturedImage,
            markersBounds: markersBoundingBox.bounds
        )
        
        guard let validScale = rendererScale else {
            return
        }
        
        renderer.scale = validScale
        
        // Attempt to render the image with error handling
        guard let capture = renderer.cgImage else {
            return
        }
        
        // Pass the DISPLAY size for proper metadata storage (not rendered size)
        // This ensures we can restore the correct display size when pasting back
        let actualOriginalSize = capturedImage.map { capturedImg in
            CGSize(width: capturedImg.image.width, height: capturedImg.image.height)
        }
        
        NSPasteboard.addImage(capture: capture, originalImageSize: actualOriginalSize)
    }

}

struct DraggableAreaView: View {
    var body: some View {
        ZStack {
            Color.clear // Set background color for the draggable area
        }
        .frame(height: 30) // Explicitly constrain the height
        .contentShape(Rectangle()) // Ensure the whole area is tappable
        .gesture(
            DragGesture()
                .onChanged { _ in
                    if let window = NSApplication.shared.windows.first {
                        window.performDrag(with: NSEvent())
                    }
                }
        )
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let toolsManager = ToolsManager()
    let markersManager = MarkersManager()
    let eventManager = EventManager(markersManager: markersManager, toolsManager: toolsManager)
    
    return ContentView()
        .environmentObject(toolsManager)
        .environmentObject(markersManager)
        .environmentObject(eventManager)
        .frame(width: 900, height: 400)
}
