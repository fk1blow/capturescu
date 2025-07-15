//
//  NewPointerToolView.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct NewPointerToolView: View {
    @EnvironmentObject var toolsManager: ToolsManager
    @EnvironmentObject var markersManager: MarkersManager
    @StateObject private var eventManager: EventManager
    @State private var lastClickLocation: CGPoint = .zero
    @State private var lastClickTime: Date = Date()
    @State private var clickCount: Int = 0
    
    init() {
        // EventManager will be initialized in onAppear with environment objects
        self._eventManager = StateObject(wrappedValue: EventManager(
            markersManager: MarkersManager(),
            toolsManager: ToolsManager()
        ))
    }
    
    var body: some View {
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
        .onAppear {
            setupEventManager()
        }
        .onChange(of: toolsManager.pointerTool.toolName) { newTool in
            eventManager.handleToolChange(to: newTool)
        }
        .onChange(of: toolsManager.selectedColor) { newColor in
            eventManager.updateToolColor(newColor)
        }
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
    
    private func setupEventManager() {
        // Update event manager with proper environment objects
        eventManager.updateManagers(
            markersManager: markersManager,
            toolsManager: toolsManager
        )
        // Sync current tool selection
        eventManager.handleCurrentToolChange()
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        let location = value.location
        let translation = value.translation
        
        // Detect start of gesture
        if translation.width == 0 && translation.height == 0 {
            // Check if we're hovering over a marker
            if markersManager.isHovering {
                // Start drag operation
                eventManager.handleEvent(.dragStart(location))
            } else {
                // Start drawing
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
            let currentTime = Date()
            let timeDifference = currentTime.timeIntervalSince(lastClickTime)
            
            print("🖱️ Click detected at \(location)")
            print("   Time difference: \(timeDifference)s")
            print("   Location difference: x=\(abs(location.x - lastClickLocation.x)), y=\(abs(location.y - lastClickLocation.y))")
            print("   Current tool: \(toolsManager.pointerTool.toolName)")
            
            // Double-click detection (within 500ms and close to same location)
            if timeDifference < 0.5 && 
               abs(location.x - lastClickLocation.x) < 10 && 
               abs(location.y - lastClickLocation.y) < 10 {
                // This is a double-click
                print("✅ Double-click detected! Sending .doubleClick event")
                eventManager.handleEvent(.doubleClick(location))
                clickCount = 0 // Reset click count
            } else {
                // Single click
                print("✅ Single click detected! Sending .click event")
                eventManager.handleEvent(.click(location))
                clickCount = 1
            }
            
            lastClickLocation = location
            lastClickTime = currentTime
        } else {
            // End drag
            eventManager.handleEvent(.dragEnd(location))
        }
    }
    
    private func handleHover(_ phase: HoverPhase) {
        switch phase {
        case .active(let location):
            // Update markers manager hover state
            markersManager.hoverMarker(at: location)
            eventManager.handleEvent(.hover(location))
        case .ended:
            markersManager.clearHover()
            eventManager.handleEvent(.hoverEnd)
        }
    }
}

