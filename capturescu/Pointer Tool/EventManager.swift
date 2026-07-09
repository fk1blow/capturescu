//
//  EventManager.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

/// Manages event dispatching and tool coordination
class EventManager: ObservableObject {
  @Published var currentAccessoryView: AnyView?
  @Published var currentCursor: CursorType = .default
  @Published var canvasUpdateTrigger: Bool = false

  private var currentTool: PointerTool
  var markersManager: MarkersManager
  var toolsManager: ToolsManager
  private let historyManager: HistoryManager
  private var markerFinder: MarkerFinder

  // Tool instances
  private let textTool: TextPointerTool
  private let freehandTool: FreehandPointerTool
  private let lineTool: LinePointerTool
  private let arrowTool: ArrowPointerTool
  private let selectionTool: SelectionTool
  private let handTool: HandPointerTool

  init(markersManager: MarkersManager, toolsManager: ToolsManager) {
    self.markersManager = markersManager
    historyManager = HistoryManager.shared
    self.toolsManager = toolsManager
    markerFinder = MarkerFinder(markersManager: markersManager)

    // Initialize tools
    textTool = TextPointerTool(
      color: toolsManager.selectedColor,
      markersManager: markersManager
    )
    freehandTool = FreehandPointerTool(
      color: toolsManager.selectedColor,
      markersManager: markersManager
    )
    lineTool = LinePointerTool(
      color: toolsManager.selectedColor,
      markersManager: markersManager
    )
    arrowTool = ArrowPointerTool(
      color: toolsManager.selectedColor,
      markersManager: markersManager
    )
    selectionTool = SelectionTool(
      markerFinder: markerFinder
    )
    handTool = HandPointerTool()

    // Start with text tool (matching current default)
    currentTool = textTool

    // Set up event handlers for tools that need to send events back
    setupEventHandlers()

    // Seed tools with the current size settings so the first stroke/text uses
    // whatever the toolbar shows, not the tool's built-in default.
    updateToolStrokeWidth(toolsManager.selectedStrokeWidth)
    updateToolFontSize(toolsManager.selectedTextSize)
  }

  /// Main event handling method
  func handleEvent(_ event: PointerEvent) {
    // Skip hover events to reduce noise
    if case .hover = event { return }
    if case .hoverEnd = event { return }

    let response = currentTool.handleEvent(event)
    processResponse(response)
  }

  /// Process a tool response and execute actions
  private func processResponse(_ response: ToolResponse) {
    // Execute commands through history manager
    for command in response.commands {
      historyManager.execute(command)
    }

    // Update UI state
    if let accessoryView = response.accessoryView {
      currentAccessoryView = accessoryView
    } else if !response.shouldContinue {
      currentAccessoryView = nil
    }

    if let cursor = response.cursorUpdate {
      currentCursor = cursor
    }

    // Clear selection if requested
    if response.clearSelection {
      markersManager.clearSelection()
    }

    // Handle tool switching
    if let toolSwitch = response.toolSwitch {
      switchTool(to: toolSwitch)

      // If switching to edit a marker, send edit event
      if let (marker, index) = response.editMarker {
        let editEvent = PointerEvent.editMarker(
          marker,
          at: marker.centerPoint,
          index: index
        )
        handleEvent(editEvent)
      }
    }
  }

  /// Switch to a different tool
  func switchTool(to toolRequest: ToolSwitchRequest) {
    // Reset current tool (commits any in-progress text edit) and dismiss its
    // accessory view so a lingering text field doesn't outlive the tool.
    currentTool.reset()
    currentAccessoryView = nil

    // Switch to new tool
    switch toolRequest {
    case .textTool:
      currentTool = textTool
    case .freehandTool:
      currentTool = freehandTool
    case .lineTool:
      currentTool = lineTool
    case .arrowTool:
      currentTool = arrowTool
    case .selectionTool:
      currentTool = selectionTool
    case .handTool:
      currentTool = handTool
    }

    // Update tools manager to keep UI in sync
    updateToolsManager(for: toolRequest)
  }

  /// Update the existing ToolsManager to keep UI in sync
  private func updateToolsManager(for toolRequest: ToolSwitchRequest) {
    switch toolRequest {
    case .textTool:
      toolsManager.selectTool(named: .TextPointer)
    case .freehandTool:
      toolsManager.selectTool(named: .FreehandPointer)
    case .lineTool:
      toolsManager.selectTool(named: .LinePointer)
    case .arrowTool:
      toolsManager.selectTool(named: .ArrowPointer)
    case .selectionTool:
      toolsManager.selectTool(named: .SelectionPointer)
    case .handTool:
      toolsManager.selectTool(named: .HandPointer)
    }
  }

  /// Handle tool switching from UI (bridging old and new systems)
  func handleToolChange(to toolName: PointerToolName) {
    let toolRequest: ToolSwitchRequest

    switch toolName {
    case .TextPointer:
      toolRequest = .textTool
    case .FreehandPointer:
      toolRequest = .freehandTool
    case .LinePointer:
      toolRequest = .lineTool
    case .ArrowPointer:
      toolRequest = .arrowTool
    case .SelectionPointer:
      toolRequest = .selectionTool
    case .HandPointer:
      toolRequest = .handTool
    }

    switchTool(to: toolRequest)
  }

  /// Handle tool change based on current tool
  func handleCurrentToolChange() {
    handleToolChange(to: toolsManager.pointerTool.toolName)
  }

  /// Update tool colors when changed in UI
  func updateToolColor(_ color: MarkerColor) {
    textTool.updateColor(color)
    freehandTool.updateColor(color)
    lineTool.updateColor(color)
    arrowTool.updateColor(color)
  }

  /// Update stroke width for the stroke-based tools when changed in the UI.
  func updateToolStrokeWidth(_ width: CGFloat) {
    freehandTool.updateStrokeWidth(width)
    lineTool.updateStrokeWidth(width)
    arrowTool.updateStrokeWidth(width)
  }

  /// Update the font size used for newly created text markers.
  func updateToolFontSize(_ size: CGFloat) {
    textTool.updateFontSize(size)
  }

  /// Render current tool preview
  func renderPreview(context: GraphicsContext) {
    currentTool.renderPreview(context: context)
  }

  /// Get the current active tool for Canvas observation
  var currentActiveTool: PointerTool {
    return currentTool
  }

  /// Handle keyboard events
  func handleKeyboardEvent(_ keyEvent: KeyEvent) {
    let event = PointerEvent.keyPressed(keyEvent)
    handleEvent(event)
  }

  // MARK: - Private Methods

  func updateManagers(markersManager: MarkersManager, toolsManager: ToolsManager) {
    self.markersManager = markersManager
    self.toolsManager = toolsManager

    // Update all tools with the new markersManager
    textTool.updateMarkersManager(markersManager)
    freehandTool.updateMarkersManager(markersManager)
    lineTool.updateMarkersManager(markersManager)
    arrowTool.updateMarkersManager(markersManager)

    setupEventHandlers()
  }

  private func triggerCanvasRedraw() {
    // Toggle state to force Canvas redraw
    DispatchQueue.main.async {
      self.canvasUpdateTrigger.toggle()
    }
  }

  func setupEventHandlers() {
    // Update marker finder with current managers manager
    markerFinder = MarkerFinder(markersManager: markersManager)

    // Set up text tool to send events back to this manager
    textTool.setEventHandler { [weak self] event in
      self?.handleEvent(event)
    }

    // Set up freehand tool to trigger canvas redraws
    freehandTool.setStateChangeHandler { [weak self] in
      self?.triggerCanvasRedraw()
    }
  }
}

// MARK: - Marker Extension for Center Point

extension Marker {
  var centerPoint: CGPoint {
    let representation = getRepresentation()
    switch representation {
    case let .text(textRep):
      return CGPoint(
        x: textRep.frame.midX,
        y: textRep.frame.midY
      )
    case let .path(path):
      return path.boundingRect.center
    default:
      return .zero
    }
  }
}
