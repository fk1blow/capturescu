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
  /// Owns the visible-region geometry. The canvas offset that decides which part
  /// of the frozen full-screen image is shown — and panning/moving it — lives here.
  @EnvironmentObject var editorModel: SnapshotEditorModel

  // Double-click detection state
  @State private var lastClickTime: Date = Date()
  @State private var lastClickLocation: CGPoint = .zero
  private let doubleClickTimeWindow: TimeInterval = 0.5 // 500ms
  private let doubleClickLocationTolerance: CGFloat = 10.0 // 10 pixels

  // Infinite canvas state
  @State private var isSpacePressed: Bool = false
  @State private var keyMonitor: Any?
  @State private var scrollMonitor: Any?

  /// The canvas is translated by this so the model's `visibleRect` shows in the
  /// viewport. It's derived from the editor geometry, not local state.
  private var canvasOffset: CGPoint { editorModel.canvasOffset }

  init(capturedImage: CapturedPasteboardImage?) {
    self.capturedImage = capturedImage
  }

  /// Drag pans the image (instead of drawing) while the hand tool is selected
  /// or the space bar is held.
  private var isPanMode: Bool {
    isSpacePressed || toolsManager.currentTool == .HandPointer
  }

  /// While the hand tool is active, hovering shows an open hand; otherwise the
  /// active tool's own cursor is used.
  private var activeCursor: CursorType {
    // Space-pan or the Move-snapshot tool → open hand, regardless of which
    // drawing tool is underneath.
    if isPanMode { return .move }

    switch toolsManager.currentTool {
    case .HandPointer: return .move
    case .TextPointer: return .text
    case .LinePointer: return .crosshair
    case .ArrowPointer: return .default
    case .FreehandPointer: return .dot
    // Selection drives its own cursor via event responses (click sets
    // .move/.default), so it reads the live EventManager value.
    default: return eventManager.currentCursor
    }
  }

  /// Apply the cursor for the current tool / pan state immediately, without
  /// waiting for a hover transition. The `.cursor` hover modifier only fires on
  /// hover enter/exit, so call this after any state change it won't catch on its
  /// own: a tool switch, a space-pan toggle, or the end of a pan drag.
  private func applyActiveCursor() {
    activeCursor.nsCursor.set()
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

      // These are the markers that were already drawn (on paper so to speak).
      // Skip the one being edited — the inline editor stands in for it.
      for marker in markersManager.markers where marker.id != markersManager.editingMarkerID {
        marker.draw(onto: ctx)
      }

      // Draw the current tool's preview using the new system
      eventManager.renderPreview(context: ctx)
    }
    // NOTE: no .drawingGroup() here — it flattens the Canvas into a cached
    // layer that doesn't re-render when only `canvasOffset` changes, which
    // silently broke panning. The Canvas redraws fine on its own.
    .overlay(
      // New event-driven pointer tool view
      newPointerToolView()
    )
    .onAppear {
      setupEventManager()
      setupSpaceKeyMonitoring()
      setupScrollMonitoring()
    }
    .onDisappear {
      cleanupSpaceKeyMonitoring()
      cleanupScrollMonitoring()
    }
    .onChange(of: toolsManager.pointerTool.toolName) { newTool in
      eventManager.handleToolChange(to: newTool)
      // Re-apply the cursor immediately after switching so it can't stay stale
      // when the pointer is already inside the canvas and no hover event fires.
      // handleToolChange runs synchronously above, so activeCursor now reflects
      // the tool we just switched to.
      applyActiveCursor()
    }
    .onChange(of: toolsManager.selectedColor) { newColor in
      eventManager.updateToolColor(newColor)
    }
    .onChange(of: toolsManager.selectedStrokeWidth) { newWidth in
      eventManager.updateToolStrokeWidth(newWidth)
    }
    .onChange(of: toolsManager.selectedTextSize) { newSize in
      eventManager.updateToolFontSize(newSize)
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

      // While a text field is being edited, space must type a space — don't
      // hijack it for canvas panning.
      if let responder = NSApp.keyWindow?.firstResponder, responder is NSText {
        return event
      }

      if event.type == .keyDown && !event.isARepeat {
        isSpacePressed = true
        applyActiveCursor() // pan mode → open hand
      } else if event.type == .keyUp {
        isSpacePressed = false
        applyActiveCursor() // restore the active tool's cursor (not a hardcoded arrow)
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

  /// Two-finger trackpad / mouse-wheel scroll pans the canvas (Figma-style),
  /// independent of the selected tool.
  private func setupScrollMonitoring() {
    scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
      editorModel.moveByScroll(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
      return event
    }
  }

  private func cleanupScrollMonitoring() {
    if let monitor = scrollMonitor {
      NSEvent.removeMonitor(monitor)
      scrollMonitor = nil
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
    .cursor(activeCursor)
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

    // Hand tool or space bar → move the whole editor across the frozen screen
    // (revealing the pixels under its new position) instead of drawing.
    if isPanMode {
      if translation.width == 0 && translation.height == 0 {
        editorModel.moveBegan()
        NSCursor.closedHand.set()
      } else {
        editorModel.moveUpdated()
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

    // If this was a pan gesture, don't send events to tools.
    if isPanMode {
      // Restore the resting cursor: still-open hand if we're staying in pan mode
      // (Move-snapshot tool or space held), or the underlying tool's cursor.
      applyActiveCursor()
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
    // Hover feedback (cursor + subtle outline) only makes sense for the Select
    // tool; while drawing with any other tool it would be noise.
    guard toolsManager.currentTool == .SelectionPointer else {
      // Ensure no stale hover outline lingers after switching away from Select.
      if markersManager.isHovering { markersManager.clearHover() }
      return
    }

    switch phase {
    case let .active(location):
      // Convert screen coordinates to canvas coordinates
      let canvasLocation = CGPoint(
        x: location.x - canvasOffset.x,
        y: location.y - canvasOffset.y
      )
      // Update markers manager hover state
      markersManager.hoverMarker(at: canvasLocation)
    case .ended:
      markersManager.clearHover()
    }
  }
}

// MARK: - Cursor Extension

extension CursorType {
  /// The concrete AppKit cursor for this semantic cursor type.
  var nsCursor: NSCursor {
    switch self {
    case .default: return .arrow
    case .pointer: return .pointingHand
    case .text: return .iBeam
    case .crosshair: return .crosshair
    case .move: return .openHand
    case .resize: return .resizeLeftRight
    case .dot: return CustomCursor.dot
    }
  }
}

extension View {
  func cursor(_ cursorType: CursorType) -> some View {
    onHover { isHovering in
      if isHovering {
        cursorType.nsCursor.set()
      } else {
        NSCursor.arrow.set()
      }
    }
  }
}

// MARK: - Custom Cursors

enum CustomCursor {
  /// A small hollow ring for the freehand tool — a "pen tip" that pinpoints
  /// where the stroke will land without covering it. The ring is white with a
  /// thin dark outline so it stays visible on both dark and light backgrounds,
  /// while the open center keeps the exact target pixel in view.
  static let dot: NSCursor = {
    let diameter: CGFloat = 6
    let padding: CGFloat = 2 // room for the ring + outline so it isn't clipped
    let size = NSSize(width: diameter + padding * 2, height: diameter + padding * 2)

    let image = NSImage(size: size, flipped: false) { _ in
      let rect = NSRect(x: padding, y: padding, width: diameter, height: diameter)
      // Dark outline just outside the ring for contrast on light backgrounds…
      let outline = NSBezierPath(ovalIn: rect.insetBy(dx: -0.5, dy: -0.5))
      outline.lineWidth = 1
      NSColor.black.withAlphaComponent(0.6).setStroke()
      outline.stroke()
      // …and the white ring itself for contrast on dark ones.
      let ring = NSBezierPath(ovalIn: rect)
      ring.lineWidth = 1.5
      NSColor.white.setStroke()
      ring.stroke()
      return true
    }
    // Hotspot at the center of the ring so it draws exactly under the point.
    return NSCursor(image: image, hotSpot: NSPoint(x: size.width / 2, y: size.height / 2))
  }()
}
