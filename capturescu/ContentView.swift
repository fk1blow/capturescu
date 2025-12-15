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
    var scale: CGFloat = 1.0  // Natural scale (HiDPI only) - used for both display and copy
    var hiDPIScale: CGFloat = 1.0  // Preserve original HiDPI scale for metadata
    var originalPNGData: Data?  // Store original PNG data to avoid re-encoding degradation

    // Computed property for natural size (display and copy size)
    var naturalSize: CGSize {
        return CGSize(
            width: CGFloat(image.width) * scale,
            height: CGFloat(image.height) * scale
        )
    }

    // Legacy compatibility - now same as naturalSize
    var displaySize: CGSize {
        return naturalSize
    }

    // Legacy compatibility - now same as naturalSize
    var logicalSize: CGSize {
        return naturalSize
    }
}

struct ContentView: View, KeyboardCommandResponder {
    @EnvironmentObject var markersManager: MarkersManager
    @EnvironmentObject var toolsManager: ToolsManager
    @ObservedObject private var windowSizeManager = WindowSizeManager.shared

    @State var capturedImage: CapturedPasteboardImage?
    @State var drawingSurfaceBounds: CGRect = .init()
    
    // Performance optimization: cache metadata detection results
    private static var metadataCache: [String: CGFloat] = [:]
    private static let cacheQueue = DispatchQueue(label: "metadata.cache", qos: .utility)
    
    // Generate cache key from image properties for performance optimization
    private func generateCacheKey(from imageSource: CGImageSource) -> String? {
        guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { return nil }
        let width = image.width
        let height = image.height
        
        // Create a simple hash based on dimensions and basic properties
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return "\(width)x\(height)"
        }
        
        // Include DPI in cache key if available
        if let dpi = properties[kCGImagePropertyDPIWidth] as? CGFloat {
            return "\(width)x\(height)_\(dpi)"
        }
        
        return "\(width)x\(height)"
    }
    
    // HiDPI detection helper with fallback mechanisms and caching
    private func detectHiDPIScale(from imageSource: CGImageSource) -> CGFloat {
        // Check cache first
        if let cacheKey = generateCacheKey(from: imageSource) {
            if let cachedScale = Self.metadataCache[cacheKey] {
                print("DEBUG DISPLAY: Using cached scale=\(cachedScale)")
                return cachedScale
            }
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            print("DEBUG DISPLAY: No properties found, using 1.0 scale")
            return cacheAndReturn(scale: 1.0, imageSource: imageSource)
        }
        
        // Check for DPI information - macOS screenshots typically have 144 DPI for Retina
        if let dpiX = properties[kCGImagePropertyDPIWidth] as? CGFloat {
            let scaleFactor = 72.0 / dpiX  // 72 DPI = 1.0 scale, 144 DPI = 0.5 scale
            
            // Validate scale factor is reasonable
            if scaleFactor > 0.1 && scaleFactor <= 4.0 {
                print("DEBUG DISPLAY: Found DPI=\(dpiX), display scale=\(scaleFactor)")
                return cacheAndReturn(scale: scaleFactor, imageSource: imageSource)
            } else {
                print("DEBUG DISPLAY: Invalid DPI=\(dpiX), falling back to dimension detection")
                return cacheAndReturn(scale: detectHiDPIScaleFromDimensions(imageSource: imageSource), imageSource: imageSource)
            }
        }
        
        // Try alternative DPI keys
        if let dpiY = properties[kCGImagePropertyDPIHeight] as? CGFloat {
            let scaleFactor = 72.0 / dpiY
            if scaleFactor > 0.1 && scaleFactor <= 4.0 {
                print("DEBUG DISPLAY: Found DPI Height=\(dpiY), display scale=\(scaleFactor)")
                return cacheAndReturn(scale: scaleFactor, imageSource: imageSource)
            }
        }
        
        // Check for resolution units and values
        if let resolutionX = properties[kCGImagePropertyTIFFXResolution] as? CGFloat {
            let scaleFactor = 72.0 / resolutionX
            if scaleFactor > 0.1 && scaleFactor <= 4.0 {
                print("DEBUG DISPLAY: Found TIFF X Resolution=\(resolutionX), display scale=\(scaleFactor)")
                return cacheAndReturn(scale: scaleFactor, imageSource: imageSource)
            }
        }
        
        // Final fallback: dimension-based detection
        print("DEBUG DISPLAY: No valid DPI metadata found, trying dimension detection")
        let fallbackScale = detectHiDPIScaleFromDimensions(imageSource: imageSource)
        return cacheAndReturn(scale: fallbackScale, imageSource: imageSource)
    }
    
    // Cache the result and return it
    private func cacheAndReturn(scale: CGFloat, imageSource: CGImageSource) -> CGFloat {
        if let cacheKey = generateCacheKey(from: imageSource) {
            Self.cacheQueue.async {
                Self.metadataCache[cacheKey] = scale
                // Limit cache size to prevent memory issues
                if Self.metadataCache.count > 100 {
                    // Remove oldest entries (simple approach)
                    let keysToRemove = Array(Self.metadataCache.keys.prefix(20))
                    keysToRemove.forEach { Self.metadataCache.removeValue(forKey: $0) }
                }
            }
        }
        return scale
    }
    
    // Fallback: detect HiDPI from image dimensions (heuristic)
    private func detectHiDPIScaleFromDimensions(imageSource: CGImageSource) -> CGFloat {
        guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            print("DEBUG DISPLAY: Cannot create image for dimension detection, using 1.0 scale")
            return 1.0
        }
        
        let width = image.width
        let height = image.height
        
        // Common screenshot sizes for Retina displays
        let commonRetinaWidths: [Int] = [2880, 3024, 3360, 3840, 5120, 6016, 7680]
        let commonRetinaHeights: [Int] = [1800, 1964, 2100, 2160, 2880, 3384, 4320]
        
        // If dimensions match common Retina sizes, assume 0.5 scale
        if commonRetinaWidths.contains(width) || commonRetinaHeights.contains(height) {
            print("DEBUG DISPLAY: Dimensions (\(width)x\(height)) suggest Retina display, using 0.5 scale")
            return 0.5
        }
        
        // If very large dimensions, likely Retina
        if width > 2500 || height > 1500 {
            print("DEBUG DISPLAY: Large dimensions (\(width)x\(height)) suggest Retina display, using 0.5 scale")
            return 0.5
        }
        
        // Default to natural size
        print("DEBUG DISPLAY: Dimensions (\(width)x\(height)) suggest standard display, using 1.0 scale")
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

        // Use natural size rendering - no window scaling at all
        let scale = hiDPIScale  // Only HiDPI scaling

        // Simple centered positioning at natural size
        let naturalImageSize = CGSize(
            width: CGFloat(image.width) * scale,
            height: CGFloat(image.height) * scale
        )

        // Center image in the view with basic padding
        let x = LayoutConstants.imagePadding
        let y = LayoutConstants.imagePadding

        self.capturedImage = CapturedPasteboardImage(
            image: image,
            position: CGPoint(x: x, y: y),
            scale: scale,  // Natural scale for everything
            hiDPIScale: hiDPIScale,
            originalPNGData: imageData.originalPNGData  // Preserve original data for zero-loss copy
        )

        let hasOriginalData = imageData.originalPNGData != nil
        print("DEBUG PASTE: imageSize=\(imageSize), hiDPIScale=\(hiDPIScale), scale=\(scale), position=\(CGPoint(x: x, y: y)), naturalSize=\(naturalImageSize), hasOriginalPNG=\(hasOriginalData)")
    }

    private func handleCopyAction() {
        // Ensure we have content to copy
        guard capturedImage != nil || !markersManager.markers.isEmpty else {
            return
        }

        // FAST PATH: Image-only copy with no markers - zero quality loss
        if markersManager.markers.isEmpty, let image = capturedImage {
            if let originalData = image.originalPNGData {
                // Zero-loss: write original PNG data directly back to pasteboard
                NSPasteboard.addImageData(originalData)
                print("DEBUG COPY: Fast path - using original PNG data (zero loss, \(originalData.count) bytes)")
                return
            }
            // Fallback for non-PNG sources: use CGContext renderer
            if let pngData = CGContextRenderer.renderWithMarkers(
                image: image.image,
                markers: [],
                bounds: CGRect(origin: .zero, size: image.naturalSize),
                imagePosition: .zero,
                imageSize: image.naturalSize,
                hiDPIScale: image.hiDPIScale
            ) {
                NSPasteboard.addImageData(pngData)
                print("DEBUG COPY: Fast path fallback - CGContext render for non-PNG source")
                return
            }
        }

        // STANDARD PATH: Image + markers using CGContext (bypasses SwiftUI ImageRenderer)
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

        // Calculate image position in capture coordinates
        let imagePositionInCapture: CGPoint
        let imageSize: CGSize

        if let image = capturedImage {
            imagePositionInCapture = CGPoint(
                x: image.position.x - captureBounds.minX,
                y: image.position.y - captureBounds.minY
            )
            imageSize = image.displaySize
        } else {
            imagePositionInCapture = .zero
            imageSize = .zero
        }

        // Use CGContext renderer instead of SwiftUI ImageRenderer for minimal quality loss
        if let pngData = CGContextRenderer.renderWithMarkers(
            image: capturedImage?.image,
            markers: transformedMarkers,
            bounds: CGRect(origin: .zero, size: captureBounds.size),
            imagePosition: imagePositionInCapture,
            imageSize: imageSize,
            hiDPIScale: capturedImage?.hiDPIScale ?? 1.0
        ) {
            NSPasteboard.addImageData(pngData)
            print("DEBUG COPY: Standard path - CGContext composite with \(transformedMarkers.count) markers")
        } else {
            print("DEBUG COPY: CGContext rendering failed, no fallback")
        }
    }
    
    // Improved capture bounds calculation
    private func calculateCaptureBounds(image: CapturedPasteboardImage?, markers: [Marker]) -> CGRect {
        if markers.isEmpty {
            // Image-only capture: create tight bounds around natural size
            guard let image = image else { return CGRect.zero }
            // Use natural size (HiDPI only, no window scaling) for copy operations
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
