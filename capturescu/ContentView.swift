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
                        // temporarely disabled
                        // DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        //     handlePasteAction()
                        // }
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
        if let image = NSPasteboard.getImage() {
            let imageSize = CGSize(width: image.width, height: image.height)
            
            
            // DEBUG: Compare with what we had before (if any)
            if let previousImage = capturedImage {
            }
            
            // Calculate scale factor for the image
            let scale = windowSizeManager.calculateImageScale(for: imageSize)
            
            // Calculate new window size based on scaled image
            let windowSize = windowSizeManager.calculateWindowSize(for: imageSize)
            
            // Resize the window to fit the image
            windowSizeManager.resizeWindow(to: windowSize)
            
            // Wait for window resize to complete, then position the image
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let screenScale = NSScreen.main?.backingScaleFactor ?? 1.0
                
                // Calculate scaled size in points
                let scaledSize = CGSize(
                    width: (imageSize.width / screenScale) * scale,
                    height: (imageSize.height / screenScale) * scale
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
        } else {
        }
    }

    private func handleCopyAction() {
        let markersBoundingBox = CaptureScreenshotBounds(
            paths: markersManager.markersPaths(), capturedImage: capturedImage
        )

        let renderer = ImageRenderer(
            content: CaptureScreenshotCanvas(
                capturedBounds: markersBoundingBox.bounds,
                capturedImage: capturedImage,
                capturedMarkers: markersManager.markers
            )
        )
        
        // Set the renderer scale to 1.0 to match Image(scale: 1.0) for high quality output
        // This ensures 1:1 pixel mapping for crisp image quality
        renderer.scale = 1.0
        
        
        let capture = renderer.cgImage
        if let capture = capture {
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
    ContentView()
        .environmentObject(ToolsManager())
        .environmentObject(MarkersManager())
        .frame(width: 900, height: 400)
}
