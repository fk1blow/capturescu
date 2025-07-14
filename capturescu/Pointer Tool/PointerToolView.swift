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

// MARK: - Click Gesture Handler
class ClickGestureHandler: ObservableObject {
    private var lastClickTime: Date? = nil
    private var lastClickLocation: CGPoint? = nil
    
    private let doubleClickTimeWindow: TimeInterval = 0.5
    private let doubleClickDistanceThreshold: CGFloat = 5.0
    
    func handleClick(at location: CGPoint, markersManager: MarkersManager, toolsManager: ToolsManager) {
        let currentTime = Date()
        
        // Check for double-click
        if let lastTime = lastClickTime,
           let lastLocation = lastClickLocation,
           currentTime.timeIntervalSince(lastTime) < doubleClickTimeWindow,
           distance(from: location, to: lastLocation) < doubleClickDistanceThreshold {
            
            handleDoubleClick(at: location, markersManager: markersManager, toolsManager: toolsManager)
            
            // Reset click tracking
            lastClickTime = nil
            lastClickLocation = nil
        } else {
            handleSingleClick(at: location, markersManager: markersManager, toolsManager: toolsManager)
            
            // Track this click for potential double-click
            lastClickTime = currentTime
            lastClickLocation = location
        }
    }
    
    private func handleSingleClick(at location: CGPoint, markersManager: MarkersManager, toolsManager: ToolsManager) {
        if !markersManager.isHovering {
            markersManager.handleInteractionEvent(.clearSelection)
        }
        toolsManager.pointerTool.pointerClicked(at: location)
    }
    
    private func handleDoubleClick(at location: CGPoint, markersManager: MarkersManager, toolsManager: ToolsManager) {
        if let hoveredMarker = markersManager.hoveredMarker,
           let hoveredIndex = markersManager.hoveredMarkerIndex {
            // Validate index bounds
            guard hoveredIndex >= 0 && hoveredIndex < markersManager.markers.count else {
                print("Warning: Invalid marker index for double-click")
                return
            }
            
            // Validate marker still exists at that index
            guard markersManager.markers[hoveredIndex].id == hoveredMarker.id else {
                print("Warning: Marker moved or deleted during double-click")
                return
            }
            
            if hoveredMarker is TextMarker {
                if let textTool = toolsManager.pointerTool as? TextPointerTool {
                    textTool.editExistingMarker(hoveredMarker as! TextMarker, at: location, index: hoveredIndex)
                }
            }
        }
    }
    
    private func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
}

struct PointerToolView: View {
  @EnvironmentObject var toolsManager: ToolsManager
  @EnvironmentObject var markersManager: MarkersManager

  @StateObject private var gestureCoordinator = GestureCoordinator()
  @StateObject private var clickHandler = ClickGestureHandler()

  var body: some View {
    ZStack(
      alignment: .topLeading,
      content: {
        Color.clear
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
              .onChanged(handleDragGestureChanged)
              .onEnded(handleDragGestureEnd)
          )
          .onContinuousHover { phase in
            handleContinuousHover(phase: phase)
          }

        toolsManager.pointerTool.renderAccessoryView(onDone: { marker in
          if let textTool = toolsManager.pointerTool as? TextPointerTool,
             textTool.isEditingExistingMarker(),
             let index = textTool.getEditingIndex() {
            // Validate index bounds before updating
            guard index >= 0 && index < markersManager.markers.count else {
              print("Warning: Invalid marker index for update")
              return
            }
            
            // Update existing marker
            markersManager.updateMarker(at: index, with: marker)
          } else {
            // Add new marker
            markersManager.addMarker(marker: marker)
          }
        })
      })
  }

  private func handleDragGestureChanged(_ value: DragGesture.Value) {
    let location = value.location
    let translation = value.translation
    
    // Handle start of gesture (no previous translation)
    if translation.width == 0 && translation.height == 0 {
      gestureCoordinator.handleGestureStart(at: location, markersManager: markersManager, toolsManager: toolsManager)
      return
    }
    
    // Handle drag movement
    gestureCoordinator.handleGestureDrag(at: location, markersManager: markersManager, toolsManager: toolsManager)
  }

  private func handleDragGestureEnd(_ value: DragGesture.Value) {
    let location = value.location
    let translation = value.translation
    
    // Handle end of gesture
    gestureCoordinator.handleGestureEnd(at: location, markersManager: markersManager, toolsManager: toolsManager)
    
    // Handle click if no drag occurred
    if translation.width == 0 && translation.height == 0 {
      clickHandler.handleClick(at: location, markersManager: markersManager, toolsManager: toolsManager)
    }
  }


  private func handleContinuousHover(phase: HoverPhase) {
    switch phase {
    case .active(let location):
      // Handle mouse movement when no gesture is active
      gestureCoordinator.handleMouseMove(at: location, markersManager: markersManager)
    case .ended:
      // Mouse left the view area
      gestureCoordinator.handleMouseExit(markersManager: markersManager)
    }
  }
}
