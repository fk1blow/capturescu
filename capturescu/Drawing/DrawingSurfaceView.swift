//
//  DrawingSurfaceView.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI
import AppKit

struct DrawingSurfaceView: View {
  var capturedImage: CapturedPasteboardImage?

  @EnvironmentObject var toolsManager: ToolsManager
  @EnvironmentObject var markersManager: MarkersManager
  @EnvironmentObject var eventManager: EventManager

  // Double-click detection state
  @State private var lastClickTime: Date = Date()
  @State private var lastClickLocation: CGPoint = .zero
  private let doubleClickTimeWindow: TimeInterval = 0.5 // 500ms
  private let doubleClickLocationTolerance: CGFloat = 10.0 // 10 pixels
  
  // Infinite canvas state
  @State private var canvasOffset: CGPoint = .zero
  @State private var isSpacePressed: Bool = false
  @State private var panStartOffset: CGPoint = .zero
  @State private var keyMonitor: Any?
  

  init(capturedImage: CapturedPasteboardImage?) {
    self.capturedImage = capturedImage
  }

  var body: some View {
    Canvas { ctx, size in
      // Access the current active tool to make Canvas observe its @Observable changes
      let _ = eventManager.currentActiveTool

      // Apply canvas offset transformation
      ctx.translateBy(x: canvasOffset.x, y: canvasOffset.y)

      if capturedImage != nil {
        let x = capturedImage!.position.x
        let y = capturedImage!.position.y

        // Render at natural scale (HiDPI only, no window scaling)
        // Display images at their natural size
        let width = CGFloat(capturedImage!.image.width) * capturedImage!.scale
        let height = CGFloat(capturedImage!.image.height) * capturedImage!.scale

        ctx.draw(
          Image(
            capturedImage!.image,
            scale: 1.0, // Use 1.0 scale to match screenshot canvas behavior
            label: Text("")
          ),
          in: CGRect(
            origin: CGPoint(x: x, y: y),
            size: CGSize(width: width, height: height)
          )
        )
      }

      // These are the markers that were already drawn (on paper so to speak)
      for marker in markersManager.markers {
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
      setupSpaceKeyMonitoring()
    }
    .onDisappear {
      cleanupSpaceKeyMonitoring()
    }
    .onChange(of: toolsManager.pointerTool.toolName) { newTool in
      eventManager.handleToolChange(to: newTool)
    }
    .onChange(of: toolsManager.selectedColor) { newColor in
      eventManager.updateToolColor(newColor)
    }
    .onKeyPress(.delete) {
      eventManager.handleKeyboardEvent(.delete)
      return .handled
    }
    .onKeyPress(.escape) {
      eventManager.handleKeyboardEvent(.escape)
      return .handled
    }
  }

  private func setupEventManager() {
    // Sync current tool selection with the already-configured EventManager
    eventManager.handleCurrentToolChange()
  }
  
  private func setupSpaceKeyMonitoring() {
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
      guard event.keyCode == 49 else { return event } // 49 is space key code
      
      if event.type == .keyDown && !event.isARepeat {
        isSpacePressed = true
        NSCursor.openHand.set()
      } else if event.type == .keyUp {
        isSpacePressed = false
        NSCursor.arrow.set() // Reset to default cursor
      }
      
      // Return nil to consume the event and prevent the tic sound
      return nil
    }
  }
  
  private func cleanupSpaceKeyMonitoring() {
    if let monitor = keyMonitor {
      NSEvent.removeMonitor(monitor)
      keyMonitor = nil
    }
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

    // If space is pressed, handle canvas panning
    if isSpacePressed {
      // On drag start, save the current offset
      if translation.width == 0 && translation.height == 0 {
        panStartOffset = canvasOffset
      } else {
        // Apply translation to the start offset
        canvasOffset = CGPoint(
          x: panStartOffset.x + translation.width,
          y: panStartOffset.y + translation.height
        )
      }
      return
    }

    // Convert screen coordinates to canvas coordinates for tools
    let canvasLocation = CGPoint(
      x: location.x - canvasOffset.x,
      y: location.y - canvasOffset.y
    )

    // Detect start of gesture
    if translation.width == 0 && translation.height == 0 {
      // Check if we're hovering over a marker
      if markersManager.isHovering {
        eventManager.handleEvent(.dragStart(canvasLocation))
      } else {
        eventManager.handleEvent(.dragStart(canvasLocation))
      }
    } else {
      // Continue gesture
      eventManager.handleEvent(.dragUpdate(canvasLocation))
    }
  }

  private func handleDragEnded(_ value: DragGesture.Value) {
    let location = value.location
    let translation = value.translation

    // If space was pressed, this was a pan gesture - no need to send events to tools
    if isSpacePressed {
      return
    }

    // Convert screen coordinates to canvas coordinates for tools
    let canvasLocation = CGPoint(
      x: location.x - canvasOffset.x,
      y: location.y - canvasOffset.y
    )

    // Check if this was a click (no movement)
    if translation.width == 0 && translation.height == 0 {
      let currentTime = Date()
      let timeSinceLastClick = currentTime.timeIntervalSince(lastClickTime)
      let distance = sqrt(pow(location.x - lastClickLocation.x, 2) + pow(location.y - lastClickLocation.y, 2))
      
      // Check if this is a double-click
      if timeSinceLastClick <= doubleClickTimeWindow && distance <= doubleClickLocationTolerance {
        eventManager.handleEvent(.doubleClick(canvasLocation))
      } else {
        eventManager.handleEvent(.click(canvasLocation))
      }
      
      // Update last click tracking
      lastClickTime = currentTime
      lastClickLocation = location
    } else {
      eventManager.handleEvent(.dragEnd(canvasLocation))
    }
  }

  private func handleHover(_ phase: HoverPhase) {
    switch phase {
    case let .active(location):
      // Convert screen coordinates to canvas coordinates
      let canvasLocation = CGPoint(
        x: location.x - canvasOffset.x,
        y: location.y - canvasOffset.y
      )
      // Update markers manager hover state
      markersManager.hoverMarker(at: canvasLocation)
    // eventManager.handleEvent(.hover(canvasLocation)) // Commented out for debugging
    case .ended:
      markersManager.clearHover()
      // eventManager.handleEvent(.hoverEnd) // Commented out for debugging
    }
  }
}

// MARK: - Cursor Extension

extension View {
  func cursor(_ cursorType: CursorType) -> some View {
    onHover { isHovering in
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
