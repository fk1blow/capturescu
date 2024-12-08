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
}

struct ContentView: View, KeyboardCommandResponder {
    @EnvironmentObject var markersManager: MarkersManager
    @EnvironmentObject var toolsManager: ToolsManager

    @State var capturedImage: CapturedPasteboardImage?
    @State var drawingSurfaceBounds: CGRect = .init()

    var body: some View {
        VStack(spacing: 0) {
            // Custom draggable area (where title bar would be)
            DraggableAreaView()
                .frame(height: 0)
                .background(Color.clear)

            ZStack(alignment: .center) {
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

    // TODO: add the "delete" command as well(see the handleKeyPressAction)
    func processCommand(_ command: KeyboardCommand) {
        print("command received: \(command)")

        switch command {
        case .copy:
            handleCopyAction()

        case .paste:
            handlePasteAction()

        default:
            break
        }
    }

    private func handlePasteAction() {
        if let image = NSPasteboard.getImage() {
            let x = Int(drawingSurfaceBounds.width / 2) - (image.width / 2)
            let y = Int(drawingSurfaceBounds.height / 2) - (image.height / 2)
            capturedImage = CapturedPasteboardImage(image: image, position: CGPoint(x: x, y: y))
        } else {
            print("No image found in pasteboard")
        }
    }

    private func handleCopyAction() {
        let markersBoundingBox = CaptureScreenshotBounds(paths: markersManager.markersPaths(), capturedImage: capturedImage)

        let capture = ImageRenderer(
            content: CaptureScreenshotCanvas(
                capturedBounds: markersBoundingBox.bounds,
                capturedImage: capturedImage,
                capturedMarkers: markersManager.markers
            )
        ).cgImage

        NSPasteboard.addImage(capture: capture)
    }

    // TODO: should deal with this another time!
    private func handleKeyPressAction(chars: String, keyCode: UInt16) {
        switch chars {
        case "a":
            toolsManager.selectTool(named: PointerToolName.ArrowPointer)
        case "f":
            toolsManager.selectTool(named: PointerToolName.FreehandPointer)
        case "l":
            toolsManager.selectTool(named: PointerToolName.LinePointer)
        case "t":
            toolsManager.selectTool(named: PointerToolName.TextPointer)
        default:
            break
        }

        switch keyCode {
        case 51:
            markersManager.deleteSelectedMarker()
        default:
            break
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
    ContentView()
        .environmentObject(ToolsManager())
        .environmentObject(MarkersManager())
        .frame(width: 900, height: 400)
}
