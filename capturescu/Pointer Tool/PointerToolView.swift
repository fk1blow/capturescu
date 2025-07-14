//
//  PointerToolView.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI



struct PointerToolView: View {
  @EnvironmentObject var toolsManager: ToolsManager
  @EnvironmentObject var markersManager: MarkersManager

  @State private var isDragging = false
  @State private var dragStartPoint: CGPoint = .zero

  var body: some View {
    ZStack(
      alignment: .topLeading,
      content: {
        Color.clear
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
              .onChanged(handleDragChanged)
              .onEnded(handleDragEnded)
          )
          .onContinuousHover(perform: handleHover)

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

  private func handleDragChanged(_ value: DragGesture.Value) {
    let location = value.location
    let translation = value.translation
    
    // Start of gesture (no previous translation)
    if translation.width == 0 && translation.height == 0 {
      dragStartPoint = location
      markersManager.hoverMarker(at: location)
      
      if markersManager.isHovering {
        // Start marker selection/drag
        markersManager.selectMarker(at: location)
        markersManager.startDragOperation()
        isDragging = true
      } else {
        // Start drawing
        markersManager.clearSelection()
        toolsManager.pointerTool.beginMarker(at: location)
      }
      return
    }
    
    // Continue gesture
    if isDragging && markersManager.selectedMarkerIndex != nil {
      // Move selected marker - calculate incremental delta
      let deltaX = location.x - dragStartPoint.x
      let deltaY = location.y - dragStartPoint.y
      markersManager.moveSelectedMarkerDirect(deltaX: deltaX, deltaY: deltaY)
      dragStartPoint = location
    } else if !isDragging {
      // Continue drawing
      toolsManager.pointerTool.updateMarker(at: location)
    }
  }

  private func handleDragEnded(_ value: DragGesture.Value) {
    let location = value.location
    let translation = value.translation
    
    if isDragging {
      // End marker drag
      markersManager.endDragOperation()
      isDragging = false
    } else {
      // End drawing or handle click
      if translation.width == 0 && translation.height == 0 {
        // Simple click
        handleClick(at: location)
      } else {
        // End drawing
        let marker = toolsManager.pointerTool.getMarker()
        toolsManager.pointerTool.endMarker(at: location)
        markersManager.addMarker(marker: marker)
      }
    }
    
    dragStartPoint = .zero
  }

  private func handleClick(at location: CGPoint) {
    if markersManager.isHovering {
      markersManager.selectMarker(at: location)
    } else {
      markersManager.clearSelection()
    }
    toolsManager.pointerTool.pointerClicked(at: location)
  }

  private func handleHover(_ phase: HoverPhase) {
    switch phase {
    case .active(let location):
      markersManager.hoverMarker(at: location)
    case .ended:
      markersManager.clearHover()
    }
  }
}
