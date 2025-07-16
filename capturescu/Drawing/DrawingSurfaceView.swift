//
//  DrawingSurfaceView.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

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

  init(capturedImage: CapturedPasteboardImage?) {
    self.capturedImage = capturedImage
  }

  var body: some View {
    Canvas { ctx, size in
      // Access the current active tool to make Canvas observe its @Observable changes
      let _ = eventManager.currentActiveTool

      if capturedImage != nil {
        let x = capturedImage!.position.x
        let y = capturedImage!.position.y

        // Get the screen scale to handle Retina displays properly
        let screenScale = NSScreen.main?.backingScaleFactor ?? 1.0

        // Render at actual pixel size (1:1 mapping) with user scale applied
        // Divide by screenScale to convert pixels to points for display
        let width = CGFloat(capturedImage!.image.width) * capturedImage!.scale / screenScale
        let height = CGFloat(capturedImage!.image.height) * capturedImage!.scale / screenScale

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
      // Check if we're hovering over a marker
      if markersManager.isHovering {
        eventManager.handleEvent(.dragStart(location))
      } else {
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
      let timeSinceLastClick = currentTime.timeIntervalSince(lastClickTime)
      let distance = sqrt(pow(location.x - lastClickLocation.x, 2) + pow(location.y - lastClickLocation.y, 2))
      
      // Check if this is a double-click
      if timeSinceLastClick <= doubleClickTimeWindow && distance <= doubleClickLocationTolerance {
        eventManager.handleEvent(.doubleClick(location))
      } else {
        eventManager.handleEvent(.click(location))
      }
      
      // Update last click tracking
      lastClickTime = currentTime
      lastClickLocation = location
    } else {
      eventManager.handleEvent(.dragEnd(location))
    }
  }

  private func handleHover(_ phase: HoverPhase) {
    switch phase {
    case let .active(location):
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
