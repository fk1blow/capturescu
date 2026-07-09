//
//  Marker.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

enum MarkerColor: String, CaseIterable {
    case red = "Red"
    case blue = "Blue"
    case green = "Green"

    case yellow = "Yellow"
    case orange = "Orange"
    case purple = "Purple"

    case black = "Black"
    case white = "White"
    case gray = "Gray"
    case lightGray = "Light Gray"

    case lightBlue = "Light Blue"
    case lightGreen = "Light Green"

    case pink = "Pink"
    case brown = "Brown"
    case teal = "Teal"
    case cyan = "Cyan"

    var color: Color {
        switch self {
        case .red:
            return .red
        case .blue:
            return .blue
        case .green:
            return .green
        case .yellow:
            return .yellow
        case .orange:
            return .orange
        case .purple:
            return .purple
        case .black:
            return .black
        case .white:
            return .white
        case .gray:
            return .gray
        case .lightGray:
            return Color(white: 0.8) // Custom light gray color
        case .lightBlue:
            return Color(red: 0.7, green: 0.85, blue: 1.0) // Custom light blue color
        case .lightGreen:
            return Color(red: 0.6, green: 1.0, blue: 0.6) // Custom light green color
        case .pink:
            return Color(red: 1.0, green: 0.75, blue: 0.8)
        case .brown:
            return Color(red: 0.6, green: 0.4, blue: 0.2)
        case .teal:
            return Color(red: 0.0, green: 0.75, blue: 0.75)
        case .cyan:
            return Color(red: 0.0, green: 1.0, blue: 1.0) // New cyan color
        }
    }

    var name: String {
        return self.rawValue
    }
}

/// A soft drop shadow used to separate a marker from any background — light or
/// dark, plain or busy. Rendered identically on the live canvas and in the
/// exported PNG.
struct MarkerShadow {
    var color: Color = .black.opacity(0.22)
    var radius: CGFloat = 3
    var offset: CGSize = CGSize(width: 0, height: 1)
}

struct MarkerStyle {
    var strokeColor: MarkerColor
    var fillColor: MarkerColor?
    var strokeWidth: CGFloat
    /// Optional drop shadow (nil = none), used by filled shapes like the arrow.
    var shadow: MarkerShadow?

    init(strokeColor: MarkerColor) {
        self.strokeColor = strokeColor
        self.strokeWidth = 2.0
    }

    init(strokeColor: MarkerColor, fillColor: MarkerColor) {
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.strokeWidth = 2.0
    }
}

struct DrawingMarkerRepresentation {
    let path: Path
}

struct TextMarkerRepresentation {
    let frame: CGRect
    let text: String
    var fontSize: CGFloat = TextMarkerFont.defaultSize
}

enum MarkerRepresentation {
    case path(Path)
    // not actually used
    case image(Image)
    case text(TextMarkerRepresentation)
}

protocol Marker {
    var id: UUID { get set }
    var style: MarkerStyle { get }
    var isHighlighted: Bool { get set }
    /// Transient hover feedback (Select tool only). Distinct from `isHighlighted`,
    /// which marks the actually-selected marker.
    var isHovered: Bool { get set }
    func draw(onto graphicsContext: GraphicsContext)
    func changeStyle(with style: MarkerStyle)
    func getRepresentation() -> MarkerRepresentation
    func markerBoundingBox(near location: CGPoint) -> BoundingBox?
    mutating func offsetMarkerBy(dx: CGFloat, dy: CGFloat)
}

extension Marker {
    // Dead simple hit detection
    func contains(_ point: CGPoint) -> Bool {
        return markerBoundingBox(near: point) != nil
    }
    
    func drawHighlight(onto graphicsContext: GraphicsContext) {
        guard isHighlighted else { return }
        
        let representation = self.getRepresentation()

        switch representation {
        case .path(let path):
            let cornerRadius: CGFloat = 8
            let expandedRect = path.boundingRect.insetBy(dx: -10, dy: -10)
            let newPath = RoundedRectangle(cornerRadius: cornerRadius)
                .path(in: expandedRect)
            graphicsContext.stroke(newPath, with: .color(self.style.strokeColor.color), lineWidth: 2)
        case .text(let textRep):
            let cornerRadius: CGFloat = 8
            let expandedRect = textRep.frame.insetBy(dx: -10, dy: -10)
            let newPath = RoundedRectangle(cornerRadius: cornerRadius)
                .path(in: expandedRect)
            graphicsContext.stroke(newPath, with: .color(self.style.strokeColor.color), lineWidth: 2)
        default:
            break
        }
    }

    /// A subtler outline shown while hovering a marker with the Select tool.
    /// Thinner and semi-transparent so it reads as "hover", not "selected", and
    /// suppressed on the already-selected marker to avoid a double outline.
    func drawHoverHighlight(onto graphicsContext: GraphicsContext) {
        guard isHovered, !isHighlighted else { return }

        let representation = self.getRepresentation()
        let cornerRadius: CGFloat = 8

        let rect: CGRect
        switch representation {
        case .path(let path):
            rect = path.boundingRect.insetBy(dx: -10, dy: -10)
        case .text(let textRep):
            rect = textRep.frame.insetBy(dx: -10, dy: -10)
        default:
            return
        }

        let newPath = RoundedRectangle(cornerRadius: cornerRadius).path(in: rect)
        graphicsContext.stroke(
            newPath,
            with: .color(self.style.strokeColor.color.opacity(0.4)),
            lineWidth: 1
        )
    }

    mutating func showHighlight() {
        isHighlighted = true
    }

    mutating func hideHighlight() {
        isHighlighted = false
    }

    mutating func showHover() {
        isHovered = true
    }

    mutating func hideHover() {
        isHovered = false
    }
}
