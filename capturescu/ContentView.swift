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
    var hiDPIScale: CGFloat = 1.0  // Preserve original HiDPI scale for natural size rendering
    
    // Computed property for display size in points
    var displaySize: CGSize {
        return CGSize(
            width: CGFloat(image.width) * scale,
            height: CGFloat(image.height) * scale
        )
    }
    
    // Computed property for natural size (original pixels × HiDPI scale only)
    var naturalSize: CGSize {
        return CGSize(
            width: CGFloat(image.width) * hiDPIScale,
            height: CGFloat(image.height) * hiDPIScale
        )
    }
}

struct ContentView: View, KeyboardCommandResponder {
    @EnvironmentObject var markersManager: MarkersManager
    @EnvironmentObject var toolsManager: ToolsManager
    @ObservedObject private var windowSizeManager = WindowSizeManager.shared

    @State var capturedImage: CapturedPasteboardImage?
    @State var drawingSurfaceBounds: CGRect = .init()
    
    // HiDPI detection helper - metadata only approach
    private func detectHiDPIScale(from imageSource: CGImageSource) -> CGFloat {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return 1.0
        }
        
        // Check for DPI information - macOS screenshots typically have 144 DPI for Retina
        if let dpiX = properties[kCGImagePropertyDPIWidth] as? CGFloat {
            let scaleFactor = 72.0 / dpiX  // 72 DPI = 1.0 scale, 144 DPI = 0.5 scale
            print("DEBUG DISPLAY: Found DPI=\(dpiX), display scale=\(scaleFactor)")
            return scaleFactor
        }
        
        // No DPI metadata = display at natural size (1:1 scale)
        print("DEBUG DISPLAY: No DPI metadata found, using 1.0 scale")
        return 1.0
    }

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
                        // Handle paste action immediately if content exists
                        handlePasteAction()
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
    
    

    private func handlePasteAction() {
        guard let imageData = NSPasteboard.getImage() else {
            return
        }
        
        let image = imageData.image
        let imageSize = CGSize(width: image.width, height: image.height)
        
        // Use metadata-based HiDPI detection only
        var hiDPIScale: CGFloat = 1.0
        if let imageSource = imageData.imageSource {
            hiDPIScale = detectHiDPIScale(from: imageSource)
        }
        // If no imageSource, default to 1.0 scale (display at natural size)
        
        // Calculate display scale for window fitting
        let windowScale = windowSizeManager.calculateImageScale(for: imageSize)
        
        // Combine scales for final display scale
        let finalScale = windowScale * hiDPIScale
        
        // Calculate window size
        let windowSize = windowSizeManager.calculateWindowSize(for: imageSize)
        
        // Resize window and position image
        windowSizeManager.resizeWindow(to: windowSize) {
            // Calculate available space for image (excluding padding and toolbar)
            let availableWidth = windowSize.width - LayoutConstants.totalHorizontalPadding
            let availableHeight = windowSize.height - LayoutConstants.totalVerticalSpace
            
            // Calculate scaled size
            let scaledSize = CGSize(
                width: imageSize.width * finalScale,
                height: imageSize.height * finalScale
            )
            
            // Position image in available space with padding
            let x = LayoutConstants.imagePadding + (availableWidth - scaledSize.width) / 2
            let y = LayoutConstants.imagePadding + (availableHeight - scaledSize.height) / 2
            
            self.capturedImage = CapturedPasteboardImage(
                image: image,
                position: CGPoint(x: x, y: y),
                scale: finalScale,
                hiDPIScale: hiDPIScale
            )
            
            print("DEBUG PASTE: imageSize=\(imageSize), hiDPIScale=\(hiDPIScale), windowScale=\(windowScale), finalScale=\(finalScale), position=\(CGPoint(x: x, y: y))")
            print("DEBUG PASTE: windowSize=\(windowSize), availableSize=\(availableWidth)x\(availableHeight), scaledSize=\(scaledSize)")
        }
    }

    private func handleCopyAction() {
        // Ensure we have content to copy
        guard capturedImage != nil || !markersManager.markers.isEmpty else {
            return
        }
        
        // Calculate capture bounds using improved logic
        let captureBounds = calculateCaptureBounds(
            image: capturedImage,
            markers: markersManager.markers
        )
        
        // Transform markers to capture coordinates
        let transformedMarkers = markersManager.markers.map { marker in
            var transformedMarker = marker
            transformedMarker.offsetMarkerBy(dx: -captureBounds.minX, dy: -captureBounds.minY)
            return transformedMarker
        }
        
        // Create renderer with capture coordinate system
        let renderer = ImageRenderer(
            content: ScreenshotRenderCanvas(
                capturedBounds: captureBounds,
                capturedImage: capturedImage,
                capturedMarkers: transformedMarkers
            )
        )
        
        // Configure renderer for high-quality output
        // Use screen scale for crisp rendering, but capture bounds are already at display size
        let screenScale = NSScreen.main?.backingScaleFactor ?? 1.0
        renderer.scale = screenScale
        renderer.proposedSize = ProposedViewSize(
            width: captureBounds.width,
            height: captureBounds.height
        )
        
        // Attempt to render the image with error handling
        guard let capture = renderer.cgImage else {
            return
        }
        
        // Store image to clipboard with preserved HiDPI scale
        let originalHiDPIScale = capturedImage?.hiDPIScale ?? 1.0
        NSPasteboard.addImage(capture: capture, originalHiDPIScale: originalHiDPIScale)
    }
    
    // Improved capture bounds calculation
    private func calculateCaptureBounds(image: CapturedPasteboardImage?, markers: [Marker]) -> CGRect {
        if markers.isEmpty {
            // Image-only capture: create tight bounds around natural image size
            guard let image = image else { return CGRect.zero }
            // Use natural size (original pixels × HiDPI scale only) for tight bounds
            return CGRect(
                x: 0,
                y: 0,
                width: image.naturalSize.width,
                height: image.naturalSize.height
            )
        } else {
            // Mixed content: use existing CaptureScreenshotBounds logic
            let markerPaths = markersManager.markersPaths()
            let bounds = CaptureScreenshotBounds(paths: markerPaths, capturedImage: image)
            return bounds.bounds
        }
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
