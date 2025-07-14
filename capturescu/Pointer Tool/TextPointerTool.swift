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
          onDone: { text, frame in
            self.marker = TextMarker(markerColor: self.markerColor, textValue: text, frame: frame)
            self.showAccessoryView = false
            onDone(self.getMarker())
            // this type of marker doesn't have the usual lifecycle of `begin`, `update`, `end`
            // so that after the accessory is `done`, we get rid of the current marker
            // and initialize a new one(so we don't draw the current marker indefinately)
            self.clearMarker()
          }
        )
      )
    }
    return AnyView(EmptyView())
  }

  func pointerClicked(at location: CGPoint) {
    showAccessoryView = !showAccessoryView
    accessoryViewLocation = showAccessoryView ? location : CGPoint.zero
  }
}
