//
//  MarkerGeometry.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

/// Protocol defining the geometric properties and coordinate transformations for markers
protocol MarkerGeometry {
    /// The actual rendered bounds of the marker on canvas
    var renderBounds: CGRect { get }
    
    /// The interactive bounds for hit detection (usually slightly larger than render bounds)
    var interactiveBounds: CGRect { get }
    
    /// The editing bounds for text fields/controls (includes UI padding and borders)
    var editingBounds: CGRect { get }
    
    /// Transform a point from editing coordinate space to render coordinate space
    func editingToRender(_ point: CGPoint) -> CGPoint
    
    /// Transform a point from render coordinate space to editing coordinate space
    func renderToEditing(_ point: CGPoint) -> CGPoint
    
    /// Transform a rect from editing coordinate space to render coordinate space
    func editingToRender(_ rect: CGRect) -> CGRect
    
    /// Transform a rect from render coordinate space to editing coordinate space
    func renderToEditing(_ rect: CGRect) -> CGRect
    
    /// Get the optimal editing position for a given click point
    func getEditingPosition(for clickPoint: CGPoint) -> CGPoint
}

/// Base implementation providing common functionality
struct BaseMarkerGeometry {
    let renderBounds: CGRect
    
    init(renderBounds: CGRect) {
        self.renderBounds = renderBounds
    }
}

extension BaseMarkerGeometry: MarkerGeometry {
    var interactiveBounds: CGRect {
        // Default: expand render bounds by 10 pixels for easier selection
        return renderBounds.insetBy(dx: -10, dy: -10)
    }
    
    var editingBounds: CGRect {
        // Default: same as render bounds
        return renderBounds
    }
    
    func editingToRender(_ point: CGPoint) -> CGPoint {
        // Default: no transformation
        return point
    }
    
    func renderToEditing(_ point: CGPoint) -> CGPoint {
        // Default: no transformation
        return point
    }
    
    func editingToRender(_ rect: CGRect) -> CGRect {
        return CGRect(
            origin: editingToRender(rect.origin),
            size: rect.size
        )
    }
    
    func renderToEditing(_ rect: CGRect) -> CGRect {
        return CGRect(
            origin: renderToEditing(rect.origin),
            size: rect.size
        )
    }
    
    func getEditingPosition(for clickPoint: CGPoint) -> CGPoint {
        return renderToEditing(clickPoint)
    }
}

/// Specialized geometry for text markers that handles text field coordinate transformations
struct TextMarkerGeometry: MarkerGeometry {
    private let baseGeometry: BaseMarkerGeometry
    
    /// Text rendering properties
    let fontSize: CGFloat = 14
    let textFieldPadding: CGFloat = 8
    let textFieldBorderWidth: CGFloat = 2
    
    /// The offset between text field position and actual text rendering
    /// These values account for SwiftUI TextField internal layout
    private let textFieldToTextOffsetX: CGFloat = 8
    private let textFieldToTextOffsetY: CGFloat = 21
    
    init(renderBounds: CGRect) {
        self.baseGeometry = BaseMarkerGeometry(renderBounds: renderBounds)
    }
    
    init(textContent: String, position: CGPoint, fontSize: CGFloat = 14) {
        // Estimate text size for initial geometry
        let estimatedSize = TextMarkerGeometry.estimateTextSize(textContent, fontSize: fontSize)
        let renderRect = CGRect(origin: position, size: estimatedSize)
        self.baseGeometry = BaseMarkerGeometry(renderBounds: renderRect)
    }
    
    var renderBounds: CGRect {
        return baseGeometry.renderBounds
    }
    
    var interactiveBounds: CGRect {
        return baseGeometry.interactiveBounds
    }
    
    var editingBounds: CGRect {
        // Text field needs extra space for padding and border
        let editingOrigin = renderToEditing(renderBounds.origin)
        let editingSize = CGSize(
            width: max(120, renderBounds.width + textFieldPadding * 2),
            height: max(30, renderBounds.height + textFieldPadding * 2)
        )
        return CGRect(origin: editingOrigin, size: editingSize)
    }
    
    func editingToRender(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x + textFieldToTextOffsetX,
            y: point.y + textFieldToTextOffsetY
        )
    }
    
    func renderToEditing(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x - textFieldToTextOffsetX,
            y: point.y - textFieldToTextOffsetY
        )
    }
    
    func editingToRender(_ rect: CGRect) -> CGRect {
        return CGRect(
            origin: editingToRender(rect.origin),
            size: rect.size
        )
    }
    
    func renderToEditing(_ rect: CGRect) -> CGRect {
        return CGRect(
            origin: renderToEditing(rect.origin),
            size: rect.size
        )
    }
    
    func getEditingPosition(for clickPoint: CGPoint) -> CGPoint {
        // For text markers, we want to position the text field so that
        // the resulting text appears where the user clicked
        return renderToEditing(clickPoint)
    }
    
    /// Create geometry from an existing text field frame (when submitting text)
    static func fromTextFieldFrame(_ textFieldFrame: CGRect, textContent: String) -> TextMarkerGeometry {
        let instance = TextMarkerGeometry(renderBounds: .zero)
        let renderFrame = instance.editingToRender(textFieldFrame)
        
        // Adjust size based on actual text content
        let textSize = estimateTextSize(textContent, fontSize: instance.fontSize)
        let finalRenderFrame = CGRect(
            origin: renderFrame.origin,
            size: textSize
        )
        
        return TextMarkerGeometry(renderBounds: finalRenderFrame)
    }
    
    /// Estimate the size of rendered text
    private static func estimateTextSize(_ text: String, fontSize: CGFloat) -> CGSize {
        let font = NSFont.systemFont(ofSize: fontSize)
        let attributes = [NSAttributedString.Key.font: font]
        let size = text.size(withAttributes: attributes)
        
        // Add small padding for rendering differences
        return CGSize(width: size.width + 4, height: size.height + 2)
    }
}

/// Factory for creating appropriate geometry for different marker types
struct MarkerGeometryFactory {
    static func createGeometry(for marker: Marker) -> MarkerGeometry {
        switch marker.getRepresentation() {
        case .text(let textRep):
            return TextMarkerGeometry(renderBounds: textRep.frame)
        case .path(let path):
            return BaseMarkerGeometry(renderBounds: path.boundingRect)
        default:
            // Default fallback
            return BaseMarkerGeometry(renderBounds: .zero)
        }
    }
    
    static func createTextGeometry(at clickPoint: CGPoint, initialText: String = "") -> TextMarkerGeometry {
        return TextMarkerGeometry(textContent: initialText, position: clickPoint)
    }
}