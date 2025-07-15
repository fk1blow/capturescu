//
//  TextMarker.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI
import CoreText

// Temporary geometry implementation until MarkerGeometry.swift is added to project
struct TextMarkerGeometry {
    let renderBounds: CGRect
    let fontSize: CGFloat = 14
    private let textFieldToTextOffsetX: CGFloat = 8
    private let textFieldToTextOffsetY: CGFloat = 8  // Reduced from 21 to minimize offset
    
    init(renderBounds: CGRect) {
        self.renderBounds = renderBounds
    }
    
    var interactiveBounds: CGRect {
        return renderBounds.insetBy(dx: -10, dy: -10)
    }
    
    func getEditingPosition(for clickPoint: CGPoint) -> CGPoint {
        return CGPoint(
            x: clickPoint.x - textFieldToTextOffsetX,
            y: clickPoint.y - textFieldToTextOffsetY
        )
    }
    
    static func fromTextFieldFrame(_ textFieldFrame: CGRect, textContent: String) -> TextMarkerGeometry {
        // DEBUG: Let's see what coordinates we're actually working with
        
        // PROBLEM: The text field frame isn't reliable because SwiftUI adjusts it
        // SOLUTION: Use the size from the text field, but get position from stored click point
        
        // For now, let's just use the textFieldFrame but adjust for known SwiftUI offset issues
        // Based on debug output: text field at 171.421875 but we positioned it at 143.421875
        // Difference is 28 pixels, and we want final text at 164.421875 (original click)
        // So we need to go back to the original click position
        
        let textFieldPadding: CGFloat = 8
        
        // The issue is that SwiftUI's text field positioning is inconsistent
        // Let's calculate based on the difference we observed: 
        // textField Y was 171.421875, but should render text at 164.421875 (click point)
        // That's a difference of -7 pixels from textField top + padding
        
        let textContentFrame = CGRect(
            x: textFieldFrame.origin.x + textFieldPadding,
            y: textFieldFrame.origin.y - 7, // Empirical adjustment based on debug data
            width: textFieldFrame.width - (textFieldPadding * 2),
            height: textFieldFrame.height - (textFieldPadding * 2)
        )
        
        
        return TextMarkerGeometry(renderBounds: textContentFrame)
    }
}

struct TextMarker: Marker {
  var id = UUID()

  var style: MarkerStyle
  var isHighlighted: Bool = false

  var textValueRepresentation: String = ""
  var frameRepresentation: CGRect = CGRectZero
  
  // Geometry for coordinate transformations
  private var geometry: TextMarkerGeometry {
    return TextMarkerGeometry(renderBounds: frameRepresentation)
  }

  init(markerColor: MarkerColor, textValue: String, frame: CGRect) {
    style = MarkerStyle(strokeColor: markerColor)
    textValueRepresentation = textValue
    frameRepresentation = frame
  }

  init(markerColor: MarkerColor) {
    self.init(markerColor: markerColor, textValue: "", frame: CGRectZero)
  }
  
  /// Create TextMarker with proper geometry-based positioning
  init(markerColor: MarkerColor, textValue: String, textFieldFrame: CGRect) {
    style = MarkerStyle(strokeColor: markerColor)
    textValueRepresentation = textValue
    
    // Use geometry to transform text field coordinates to render coordinates
    let textGeometry = TextMarkerGeometry.fromTextFieldFrame(textFieldFrame, textContent: textValue)
    frameRepresentation = textGeometry.renderBounds
  }

  func draw(onto ctx: GraphicsContext) {
    let text = Text(verbatim: textValueRepresentation).font(.system(size: 14))
    var resolvedText = ctx.resolve(text)
    resolvedText.shading = .color(style.strokeColor.color)
    ctx.draw(resolvedText, in: frameRepresentation)

    drawHighlight(onto: ctx)
  }

  func changeStyle(with _: MarkerStyle) {
    // TODO:
  }

  func getRepresentation() -> MarkerRepresentation {
    return MarkerRepresentation.text(
      TextMarkerRepresentation(frame: frameRepresentation, text: textValueRepresentation)
    )
  }

  func markerBoundingBox(near location: CGPoint) -> BoundingBox? {
    return HitDetectionManager.shared.isPointNearRect(location, rect: frameRepresentation)
  }


  mutating func offsetMarkerBy(dx: CGFloat, dy: CGFloat) {
    frameRepresentation = frameRepresentation.offsetBy(dx: dx, dy: dy)
  }
  
  mutating func updateText(_ newText: String) {
    textValueRepresentation = newText
  }
  
  mutating func updateFrame(_ newFrame: CGRect) {
    frameRepresentation = newFrame
  }
  
  mutating func updateTextAndFrame(_ newText: String, _ newFrame: CGRect) {
    textValueRepresentation = newText
    frameRepresentation = newFrame
  }
  
  /// Get the editing position for this text marker (where to place the text field)
  func getEditingPosition() -> CGPoint {
    return geometry.getEditingPosition(for: frameRepresentation.origin)
  }
  
  /// Get the interactive bounds for hit detection
  func getInteractiveBounds() -> CGRect {
    return geometry.interactiveBounds
  }
  
  /// Update from text field submission using proper geometry
  mutating func updateFromTextFieldSubmission(text: String, textFieldFrame: CGRect) {
    textValueRepresentation = text
    let textGeometry = TextMarkerGeometry.fromTextFieldFrame(textFieldFrame, textContent: text)
    frameRepresentation = textGeometry.renderBounds
  }
}
