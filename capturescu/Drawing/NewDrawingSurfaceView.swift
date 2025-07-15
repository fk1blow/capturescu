//
//  NewDrawingSurfaceView.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct NewDrawingSurfaceView: View {
    var capturedImage: CapturedPasteboardImage?
    
    @EnvironmentObject var toolsManager: ToolsManager
    @EnvironmentObject var markersManager: MarkersManager
    @StateObject private var eventManager = EventManager(
        markersManager: MarkersManager(),
        toolsManager: ToolsManager()
    )
    
    init(capturedImage: CapturedPasteboardImage?) {
        self.capturedImage = capturedImage
    }
    
    var body: some View {
        Canvas { ctx, size in
            print("🖼️ Canvas draw called - markers count: \(markersManager.markers.count)")
            
            // Access the current active tool to make Canvas observe its @Observable changes
            let _ = eventManager.currentActiveTool
            
            if capturedImage != nil {
                let x = capturedImage!.position.x
                let y = capturedImage!.position.y
                
                // Get the screen scale to handle Retina displays properly
                let screenScale = NSScreen.main?.backingScaleFactor ?? 1.0
                
                // Render at actual pixel size (1:1 mapping) with user scale applied
                let width = CGFloat(capturedImage!.image.width) * capturedImage!.scale
                let height = CGFloat(capturedImage!.image.height) * capturedImage!.scale
                
                ctx.draw(
                    Image(
                        capturedImage!.image,
                        scale: screenScale, // Use screen scale to convert pixels to points
                        label: Text("")
                    ),
                    in: CGRect(
                        origin: CGPoint(x: x, y: y),
                        size: CGSize(width: width, height: height)
                    )
                )
            }
            
            // These are the markers that were already drawn (on paper so to speak)
            for (index, marker) in markersManager.markers.enumerated() {
                print("  🎨 Drawing marker \(index + 1): \(marker.id)")
                marker.draw(onto: ctx)
            }
            
            // Draw the current tool's preview using the new system
            eventManager.renderPreview(context: ctx)
        }
        .drawingGroup() // Force redraw when markers change
        .overlay(
            // New event-driven pointer tool view
            newPointerToolView()
        )
        .onAppear {
            setupEventManager()
        }
        .onChange(of: toolsManager.pointerTool.toolName) { newTool in
            eventManager.handleToolChange(to: newTool)
        }
        .onChange(of: toolsManager.selectedColor) { newColor in
            eventManager.updateToolColor(newColor)
        }
    }
    
    private func setupEventManager() {
        print("🔧 Setting up EventManager")
        print("   Current tool: \(toolsManager.pointerTool.toolName)")
        print("   Current color: \(toolsManager.selectedColor)")
        
        eventManager.updateManagers(
            markersManager: markersManager,
            toolsManager: toolsManager
        )
        // Sync current tool selection
        eventManager.handleCurrentToolChange()
        
        print("✅ EventManager setup complete")
    }
    
    private func newPointerToolView() -> some View {
        ZStack(alignment: .topLeading) {
            // Main interaction area
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged(handleDragChanged)
                        .onEnded(handleDragEnded)
                )
                .onContinuousHover(perform: handleHover)
            
            // Accessory view overlay
            if let accessoryView = eventManager.currentAccessoryView {
                accessoryView
            }
        }
        .cursor(eventManager.currentCursor)
        // TODO: Add keyboard shortcuts later
        // .onKeyPress(.delete) { _ in
        //     eventManager.handleKeyboardEvent(.delete)
        //     return .handled
        // }
        // .onKeyPress(.escape) { _ in
        //     eventManager.handleKeyboardEvent(.escape)
        //     return .handled
        // }
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        let location = value.location
        let translation = value.translation
        
        // Detect start of gesture
        if translation.width == 0 && translation.height == 0 {
            print("🎯 Drag started at: \(location)")
            // Check if we're hovering over a marker
            if markersManager.isHovering {
                print("   Hovering over marker, starting drag")
                eventManager.handleEvent(.dragStart(location))
            } else {
                print("   Starting drawing")
                eventManager.handleEvent(.dragStart(location))
            }
        } else {
            // Continue gesture
            eventManager.handleEvent(.dragUpdate(location))
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let location = value.location
        let translation = value.translation
        
        // Check if this was a click (no movement)
        if translation.width == 0 && translation.height == 0 {
            print("👆 Click at: \(location)")
            eventManager.handleEvent(.click(location))
        } else {
            print("🏁 Drag ended at: \(location)")
            eventManager.handleEvent(.dragEnd(location))
        }
    }
    
    private func handleHover(_ phase: HoverPhase) {
        switch phase {
        case .active(let location):
            // Update markers manager hover state
            markersManager.hoverMarker(at: location)
            // eventManager.handleEvent(.hover(location)) // Commented out for debugging
        case .ended:
            markersManager.clearHover()
            // eventManager.handleEvent(.hoverEnd) // Commented out for debugging
        }
    }
}

// MARK: - Cursor Extension
extension View {
    func cursor(_ cursorType: CursorType) -> some View {
        self.onHover { isHovering in
            if isHovering {
                switch cursorType {
                case .default:
                    NSCursor.arrow.set()
                case .pointer:
                    NSCursor.pointingHand.set()
                case .text:
                    NSCursor.iBeam.set()
                case .crosshair:
                    NSCursor.crosshair.set()
                case .move:
                    NSCursor.openHand.set()
                case .resize:
                    NSCursor.resizeLeftRight.set()
                }
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

