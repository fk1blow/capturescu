//
//  PointerToolView.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

enum DragState {
  case singleClick
  case doubleClick
  case dragging
}

struct PointerToolView: View {
  @EnvironmentObject var toolsManager: ToolsManager
  @EnvironmentObject var markersManager: MarkersManager

  @State private var isDrawingMarker = false
  @State private var isMovingMarker = false
  @State private var lastDragPosition: CGPoint? = nil
  @State private var lastClickTime: Date? = nil
  @State private var lastClickLocation: CGPoint? = nil
  
  private let doubleClickTimeWindow: TimeInterval = 0.5
  private let doubleClickDistanceThreshold: CGFloat = 5.0

  var body: some View {
    ZStack(
      alignment: .topLeading,
      content: {
        Color.clear
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
              .onChanged(handleDragGestureStart)
              .onEnded(handleDragGestureEnd)

            // see https://developer.apple.com/documentation/swiftui/composing-swiftui-gestures
            // https://chatgpt.com/share/67462560-7d68-8011-92ed-56411336f403
            // see also ExclusiveGesture https://developer.apple.com/documentation/swiftui/exclusivegesture
          )
          .onContinuousHover { phase in
            handleMouseOver(phase: phase)
          }

        toolsManager.pointerTool.renderAccessoryView(onDone: { marker in
          if let textTool = toolsManager.pointerTool as? TextPointerTool,
             textTool.isEditingExistingMarker(),
             let index = textTool.getEditingIndex() {
            // Update existing marker
            markersManager.updateMarker(at: index, with: marker)
          } else {
            // Add new marker
            markersManager.addMarker(marker: marker)
          }
        })
      })
  }

  private func handleDragGestureStart(_ value: DragGesture.Value) {
    // gesture just began, which means we need to move to the starting point
    if value.translation.width + value.translation.height == 0 {
      if markersManager.isMarkerHovered() {
        handleMoveStart(value: value)
      } else {
        handleDrawStart(value: value)
      }
    } else {
      if markersManager.isMarkerHovered() {
        handleMoveUpdate(value: value)
      } else {
        handleDrawUpdate(value: value)
      }
    }
  }

  private func handleDragGestureEnd(_ value: DragGesture.Value) {
    lastDragPosition = nil

    if value.translation.width + value.translation.height == 0 {
      handleDrawStop()
      handleClick(value: value)
    } else {
      if markersManager.isMarkerHovered() {
        handleMoveEnd(value: value)
      } else {
        handleDrawEnd(value: value)
      }
    }
  }

  // #region Drawing

  private func handleDrawStart(value: DragGesture.Value) {
    isDrawingMarker = true
    markersManager.clearSelectedMarker()
    toolsManager.pointerTool.beginMarker(at: value.location)
  }

  private func handleDrawUpdate(value: DragGesture.Value) {
    toolsManager.pointerTool.updateMarker(at: value.location)
  }

  private func handleDrawEnd(value: DragGesture.Value) {
    isDrawingMarker = false
    markersManager.addMarker(marker: toolsManager.pointerTool.getMarker())
    toolsManager.pointerTool.endMarker(at: value.location)
  }

  private func handleDrawStop() {
    isDrawingMarker = false
    toolsManager.pointerTool.clearMarker()
  }

  // #endregion

  // #region Clicking

  private func handleClick(value: DragGesture.Value) {
    let currentTime = Date()
    let clickLocation = value.location
    
    // Check for double-click
    if let lastTime = lastClickTime,
       let lastLocation = lastClickLocation,
       currentTime.timeIntervalSince(lastTime) < doubleClickTimeWindow,
       distance(from: clickLocation, to: lastLocation) < doubleClickDistanceThreshold {
      
      // Handle double-click
      handleDoubleClick(at: clickLocation)
      
      // Reset click tracking
      lastClickTime = nil
      lastClickLocation = nil
    } else {
      // Handle single click
      if markersManager.isMarkerHovered() == false {
        // clear the previously selected marker
        markersManager.clearSelectedMarker()
        // informs the pointer tool of the click on the pointer tool view(canvas)
        toolsManager.pointerTool.pointerClicked(at: value.location)
      }
      
      // Track this click for potential double-click
      lastClickTime = currentTime
      lastClickLocation = clickLocation
    }
  }
  
  private func handleDoubleClick(at location: CGPoint) {
    // Check if double-click is on a text marker
    if let hoveredMarker = markersManager.hoveredMarker {
      if hoveredMarker.marker is TextMarker {
        // Enter text editing mode
        if let textTool = toolsManager.pointerTool as? TextPointerTool {
          textTool.editExistingMarker(hoveredMarker.marker as! TextMarker, at: location, index: hoveredMarker.atIndex)
        }
      }
    }
  }
  
  private func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
    let dx = point1.x - point2.x
    let dy = point1.y - point2.y
    return sqrt(dx * dx + dy * dy)
  }

  // #endregion

  // #region Movine/Dragging

  private func handleMoveStart(value _: DragGesture.Value) {
    isMovingMarker = true
    markersManager.selectHoveredMarker()
  }

  private func handleMoveUpdate(value: DragGesture.Value) {
    guard markersManager.selectedMarker != nil else { return }

    isMovingMarker = false

    let position = value.location

    if let lastPosition = lastDragPosition {
      // Calculate the delta of the drag
      let deltaX = position.x - lastPosition.x
      let deltaY = position.y - lastPosition.y

      markersManager.moveSelectedMarker(
        to:
          CGPoint(x: deltaX, y: deltaY)
      )

      // Update the last drag position
      lastDragPosition = position
    } else {
      // This is the first drag event, set the initial position
      lastDragPosition = position
    }
  }

  private func handleMoveEnd(value _: DragGesture.Value) {
    isMovingMarker = false
  }

  // #endregion

  private func handleMouseOver(phase: HoverPhase) {
    guard !isDrawingMarker || !isMovingMarker else { return }

    switch phase {
    case let .active(location):
      for (index, marker) in markersManager.markers.enumerated() {
        let boundingBox = marker.markerBoundingBox(near: location)
        if boundingBox != nil {
          markersManager.setHoveredMarker(on: marker, atIndex: index)
          break
        } else {
          markersManager.clearHoveredMarker()
        }
      }
    case .ended:
      break
    }
  }
}
