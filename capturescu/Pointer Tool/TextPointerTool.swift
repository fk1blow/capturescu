//
//  TextPointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Combine
import Foundation
import SwiftUI
import Observation

@Observable class TextPointerTool: PointerTool {
  var toolName = PointerToolName.TextPointer

  private var markerColor: MarkerColor
  private var showAccessoryView = false
  private var accessoryViewLocation: CGPoint = .zero
  private var editingMarkerID: UUID? = nil
  private var editingIndex: Int? = nil
  private var currentMarker: TextMarker? = nil  // Temporary marker during creation/editing

  init(color: MarkerColor) {
    self.markerColor = color
  }

  func clearMarker() {
    currentMarker = nil
    editingMarkerID = nil
    editingIndex = nil
    showAccessoryView = false
  }

  func drawMarker(onto graphicsContext: GraphicsContext) {
    currentMarker?.draw(onto: graphicsContext)
  }

  func getMarker() -> Marker {
    return currentMarker ?? TextMarker(markerColor: markerColor)
  }
  
  // MARK: - Standard Lifecycle Implementation
  
  func beginMarker(at location: CGPoint) {
    // If we're not already editing an existing marker, create a new one
    if editingMarkerID == nil {
      currentMarker = TextMarker(markerColor: markerColor)
      editingIndex = nil
    }
    // For existing markers, currentMarker is already set in editExistingMarker
    
    showAccessoryView = true
    accessoryViewLocation = location
  }
  
  func updateMarker(at location: CGPoint) {
    // Text markers don't have continuous updates like drawing tools
    // Update the accessory view location if needed
    if showAccessoryView {
      accessoryViewLocation = location
    }
  }
  
  func endMarker(at location: CGPoint) {
    // End marker creation - this happens when accessory view is dismissed
    showAccessoryView = false
  }

  func renderAccessoryView(onDone: @escaping (_ maker: Marker) -> Void) -> AnyView {
    if showAccessoryView {
      return AnyView(
        TextPointerToolAccessoryView(
          position: accessoryViewLocation,
          initialText: getCurrentEditingText(),
          onDone: { text, frame in
            if let editingID = self.editingMarkerID {
              // Update existing marker
              var updatedMarker = TextMarker(markerColor: self.markerColor, textValue: text, frame: frame)
              updatedMarker.id = editingID  // Keep the same ID
              self.showAccessoryView = false
              onDone(updatedMarker)
              self.clearMarker()
            } else {
              // Create new marker
              let newMarker = TextMarker(markerColor: self.markerColor, textValue: text, frame: frame)
              self.showAccessoryView = false
              onDone(newMarker)
              self.clearMarker()
            }
          },
          onCancel: {
            // Cancel editing - just hide the accessory view without changes
            self.clearMarker()
          }
        )
      )
    }
    return AnyView(EmptyView())
  }
  
  func isEditingExistingMarker() -> Bool {
    return editingMarkerID != nil
  }
  
  private func getCurrentEditingText() -> String {
    // For new markers, return empty string
    // For existing markers, the text will be passed from the caller
    return currentMarker?.textValueRepresentation ?? ""
  }
  
  func getEditingIndex() -> Int? {
    return editingIndex
  }

  func pointerClicked(at location: CGPoint) {
    // Use standard lifecycle for new text creation
    if showAccessoryView {
      // Hide accessory view if already showing
      showAccessoryView = false
      clearMarker()
    } else {
      // Show accessory view for new text creation
      beginMarker(at: location)
    }
  }
  
  func editExistingMarker(_ textMarker: TextMarker, at location: CGPoint, index: Int) {
    // Validate marker existence (defensive programming)
    guard textMarker.id != UUID() else {
      print("Warning: Attempting to edit marker with invalid ID")
      return
    }
    
    // Set up editing context first
    editingMarkerID = textMarker.id
    editingIndex = index
    currentMarker = textMarker  // Store for text retrieval
    
    // Use standard lifecycle for existing marker editing
    beginMarker(at: textMarker.frameRepresentation.origin)
  }
  
  func onUndoRedo() {
    // Clear all editing state when undo/redo occurs
    // This prevents stale references and state drift
    clearMarker()
  }
}
