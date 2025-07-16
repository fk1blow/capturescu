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
    
    
    private func calculateRendererScale(
        capturedImage: CapturedPasteboardImage?,
        markersBounds: CGRect
    ) -> CGFloat? {
        // NO-SCALING APPROACH: Always render at 1.0 scale to preserve exact pixel data
        // External apps will handle their own display scaling as needed
        return 1.0
    }
    
    

    private func detectScreenshotScale(imageSize: CGSize) -> CGFloat {
        // Get current screen info for Retina detection
        guard let screen = NSScreen.main else { return 1.0 }
        
        let screenPixelSize = CGSize(
            width: screen.frame.width * screen.backingScaleFactor,
            height: screen.frame.height * screen.backingScaleFactor
        )
        
        // Check if image dimensions suggest a Retina screenshot
        // Screenshots are often exactly 2x the logical screen size
        let tolerance: CGFloat = 0.1 // 10% tolerance for different screenshot sizes
        
        let isLikelyRetinaScreenshot = 
            screen.backingScaleFactor == 2.0 && // Retina display
            (imageSize.width > screen.frame.width * 1.5) && // Significantly larger than logical size
            (imageSize.width <= screenPixelSize.width * (1.0 + tolerance)) && // Within screen bounds
            (imageSize.height <= screenPixelSize.height * (1.0 + tolerance))
        
        if isLikelyRetinaScreenshot {
            print("DEBUG DETECTION: Detected likely Retina screenshot - using 0.5 display scale")
            return 0.5 // Display at half size to match logical screen dimensions
        }
        
        print("DEBUG DETECTION: Regular image - using 1.0 display scale")
        return 1.0
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
        
        // Detect if this is likely a Retina screenshot and adjust display scale
        let detectedDisplayScale = detectScreenshotScale(imageSize: imageSize)
        
        // Calculate scale factor for the image using the detected display scale
        let scale = windowSizeManager.calculateImageScale(for: imageSize) * detectedDisplayScale
        
        // Calculate new window size based on scaled image
        let windowSize = windowSizeManager.calculateWindowSize(for: imageSize)
        
        // Resize the window to fit the image with completion callback
        windowSizeManager.resizeWindow(to: windowSize) {
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
