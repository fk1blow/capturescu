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
            return screen.backingScaleFactor
        }
        
        // Fallback to main screen
        return NSScreen.main?.backingScaleFactor ?? 1.0
    }

    private func handlePasteAction() {
        if let imageData = NSPasteboard.getImage() {
            let image = imageData.image
            let isCapturescuRendered = imageData.isCapturescuRendered
            
            let imageSize = CGSize(width: image.width, height: image.height)
            
            // Debug logging for paste behavior
            let screenScale = getDisplayScaleFactor()
            print("📋 Image paste:")
            print("  • Image size: \(imageSize)")
            print("  • Is Capturescu rendered: \(isCapturescuRendered)")
            print("  • Screen scale: \(screenScale)")
            
            // Calculate scale factor for the image
            let scale = windowSizeManager.calculateImageScale(for: imageSize)
            
            // Calculate new window size based on scaled image
            let windowSize = windowSizeManager.calculateWindowSize(for: imageSize)
            
            // Resize the window to fit the image with completion callback
            windowSizeManager.resizeWindow(to: windowSize) {
                
                let screenScale = self.getDisplayScaleFactor()
                
                // Calculate scaled size in points
                let scaledSize: CGSize
                if isCapturescuRendered {
                    // Capturescu-rendered images are already in points, don't apply screen scale conversion
                    scaledSize = CGSize(
                        width: imageSize.width * scale,
                        height: imageSize.height * scale
                    )
                    print("  • Scaling (Capturescu-rendered): \(imageSize) × \(scale) = \(scaledSize)")
                } else {
                    // Original screenshots need screen scale conversion from pixels to points
                    scaledSize = CGSize(
                        width: (imageSize.width / screenScale) * scale,
                        height: (imageSize.height / screenScale) * scale
                    )
                    print("  • Scaling (Original): \(imageSize) ÷ \(screenScale) × \(scale) = \(scaledSize)")
                }
                
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
    }

    private func handleCopyAction() {
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
        
        // Set the renderer scale to preserve original image pixel dimensions
        // This ensures screenshots maintain the same size as the source image
        let screenScale = getDisplayScaleFactor()
        
        // Calculate the scale needed to preserve original image dimensions
        let preserveOriginalScale: CGFloat
        if let capturedImage = capturedImage {
            // Calculate the scale needed to make the output match the original image size
            let bounds = markersBoundingBox.bounds
            let originalImageWidth = CGFloat(capturedImage.image.width)
            let originalImageHeight = CGFloat(capturedImage.image.height)
            
            // Calculate scale to preserve original pixel dimensions
            // The renderer scale should make the output match the original image size
            let widthScale = originalImageWidth / bounds.width
            let heightScale = originalImageHeight / bounds.height
            let baseScale = min(widthScale, heightScale)
            
            // Account for the screen scale factor that ImageRenderer applies internally
            // We need to multiply by screen scale to counteract the internal scaling
            preserveOriginalScale = baseScale * screenScale
        } else {
            // Fallback to screen scale if no captured image
            preserveOriginalScale = screenScale
        }
        
        renderer.scale = preserveOriginalScale
        
        // Debug logging for scaling behavior
        let bounds = markersBoundingBox.bounds
        print("📸 Screenshot capture:")
        print("  • Screen scale factor: \(screenScale)")
        print("  • Preserve original scale: \(preserveOriginalScale)")
        print("  • Renderer scale: \(renderer.scale)")
        print("  • Bounding box: \(bounds)")
        print("  • Output size will be: \(bounds.width * renderer.scale / screenScale) x \(bounds.height * renderer.scale / screenScale) pixels")
        if let capturedImage = capturedImage {
            print("  • Original image: \(capturedImage.image.width) x \(capturedImage.image.height) pixels")
            let originalImageWidth = CGFloat(capturedImage.image.width)
            let originalImageHeight = CGFloat(capturedImage.image.height)
            let widthScale = originalImageWidth / bounds.width
            let heightScale = originalImageHeight / bounds.height
            let baseScale = min(widthScale, heightScale)
            print("  • Base scale: \(baseScale)")
            print("  • Width scale: \(originalImageWidth) / \(bounds.width) = \(widthScale)")
            print("  • Height scale: \(originalImageHeight) / \(bounds.height) = \(heightScale)")
            print("  • Final scale: \(baseScale) × \(screenScale) = \(preserveOriginalScale)")
            print("  • Expected output: \(originalImageWidth) x \(originalImageHeight) pixels")
        }
        
        
        let capture = renderer.cgImage
        
        // Debug logging for clipboard operations
        if let capture = capture {
            print("📎 Clipboard operation:")
            print("  • Rendered image size: \(capture.width) x \(capture.height) pixels")
            print("  • Adding to clipboard...")
        }

        NSPasteboard.addImage(capture: capture)
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
