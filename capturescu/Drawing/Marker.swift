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

struct MarkerStyle {
    var strokeColor: MarkerColor
    var fillColor: MarkerColor?
    var strokeWidth: CGFloat

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
}

enum MarkerRepresentation {
    case path(Path)
    // not actually used
    case image(Image)
    case text(TextMarkerRepresentation)
}

protocol Marker {
    // TODO: do i really need this? Maybe remove it
    var id: UUID { get set }
    var style: MarkerStyle { get }
    var isHighlighted: Bool { get set }
    func draw(onto graphicsContext: GraphicsContext)
    func changeStyle(with style: MarkerStyle)
    func getRepresentation() -> MarkerRepresentation
    func markerBoundingBox(near location: CGPoint) -> BoundingBox?
    func drawHighlight(onto graphicsContext: GraphicsContext)
    mutating func offsetMarkerBy(dx: CGFloat, dy: CGFloat)
}

extension Marker {
    func drawHighlight(onto graphicsContext: GraphicsContext) {
        // it almost feels like this function could be implemented by the drawing marker itself
        // b/c atm theres no other marker that needs a generic way of doing it
        // The text marker would need to return the 'frameRepresentation'(not the text)
        // in order to be useful when doing the "highlighting"
        let representation = self.getRepresentation()

        switch representation {
        case .path(let path):
            let cornerRadius: CGFloat = 8 // Adjust the corner radius as needed
            let expandedRect = path.boundingRect.insetBy(dx: -10, dy: -10) // Increase the size by 10 points
            let newPath = RoundedRectangle(cornerRadius: cornerRadius)
                .path(in: expandedRect)
            graphicsContext.stroke(newPath, with: .color(self.style.strokeColor.color), lineWidth: 2)
        default:
            break
        }
    }

    mutating func showHighlight() {
        isHighlighted = true
    }

    mutating func hideHighlight() {
        isHighlighted = false
    }
}
