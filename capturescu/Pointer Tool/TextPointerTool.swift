//
//  TextPointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Combine
import Foundation
import SwiftUI

@Observable class TextPointerTool: PointerTool {
  var toolName = PointerToolName.TextPointer

  private var marker: TextMarker
  private var markerColor: MarkerColor
  private var showAccessoryView = false
  private var accessoryViewLocation: CGPoint = .zero
  private var editingMarker: TextMarker? = nil
  private var editingIndex: Int? = nil

  init(color: MarkerColor) {
    self.markerColor = color
    self.marker = TextMarker(markerColor: color)
  }

  func clearMarker() {
    marker = TextMarker(markerColor: markerColor)
  }

  func drawMarker(onto graphicsContext: GraphicsContext) {
    marker.draw(onto: graphicsContext)
  }

  func getMarker() -> Marker {
    return marker
  }

  func renderAccessoryView(onDone: @escaping (_ maker: Marker) -> Void) -> AnyView {
    if showAccessoryView {
      return AnyView(
        TextPointerToolAccessoryView(
          position: accessoryViewLocation,
          initialText: editingMarker?.textValueRepresentation ?? "",
          onDone: { text, frame in
            if let editingMarker = self.editingMarker {
              // Update existing marker
              var updatedMarker = editingMarker
              updatedMarker.textValueRepresentation = text
              updatedMarker.frameRepresentation = frame
              self.marker = updatedMarker
              self.showAccessoryView = false
              onDone(self.getMarker())
              self.editingMarker = nil
              self.editingIndex = nil
            } else {
              // Create new marker
              self.marker = TextMarker(markerColor: self.markerColor, textValue: text, frame: frame)
              self.showAccessoryView = false
              onDone(self.getMarker())
              // this type of marker doesn't have the usual lifecycle of `begin`, `update`, `end`
              // so that after the accessory is `done`, we get rid of the current marker
              // and initialize a new one(so we don't draw the current marker indefinately)
              self.clearMarker()
            }
          },
          onCancel: {
            // Cancel editing - just hide the accessory view without changes
            self.showAccessoryView = false
            self.editingMarker = nil
            self.editingIndex = nil
          }
        )
      )
    }
    return AnyView(EmptyView())
  }
  
  func isEditingExistingMarker() -> Bool {
    return editingMarker != nil
  }
  
  func getEditingIndex() -> Int? {
    return editingIndex
  }

  func pointerClicked(at location: CGPoint) {
    showAccessoryView = !showAccessoryView
    accessoryViewLocation = showAccessoryView ? location : CGPoint.zero
    editingMarker = nil
    editingIndex = nil
  }
  
  func editExistingMarker(_ textMarker: TextMarker, at location: CGPoint, index: Int) {
    editingMarker = textMarker
    editingIndex = index
    showAccessoryView = true
    accessoryViewLocation = textMarker.frameRepresentation.origin
  }
}
