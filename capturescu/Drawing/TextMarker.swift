//
//  TextMarker.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct TextMarker: Marker {
    var id = UUID()

    var style: MarkerStyle
    // var path: Path
    var isHighlighted: Bool = false

    var textValueRepresentation: String = ""
    // var locationRepresentation: CGPoint = CGPointZero
    var frameRepresentation: CGRect = CGRectZero

    init(markerColor: MarkerColor, textValue: String, frame: CGRect) {
        self.style = MarkerStyle(strokeColor: markerColor)
        self.textValueRepresentation = textValue
        self.frameRepresentation = frame
    }

    init(markerColor: MarkerColor) {
        self.init(markerColor: markerColor, textValue: "", frame: CGRectZero)
    }

    func draw(onto ctx: GraphicsContext) {
        let text = Text(verbatim: textValueRepresentation).font(.system(size: 14))
        var resolvedText = ctx.resolve(text)
        resolvedText.shading = .color(self.style.strokeColor.color)
        ctx.draw(resolvedText, in: self.frameRepresentation)

        if self.isHighlighted {
            self.drawHighlight(onto: ctx)
        }
    }

    func changeStyle(with _: MarkerStyle) {
        // TODO:
    }

    func getRepresentation() -> MarkerRepresentation {
        return MarkerRepresentation.text(
            TextMarkerRepresentation(frame: self.frameRepresentation, text: self.textValueRepresentation)
        )
    }

    func markerBoundingBox(near location: CGPoint) -> BoundingBox? {
        return isPointNearRect(testPoint: location, frame: self.frameRepresentation)
    }

    func drawHighlight(onto ctx: GraphicsContext) {
        let cornerRadius: CGFloat = 8
        let expandedRect = self.frameRepresentation.insetBy(dx: -10, dy: -10)
        let newPath = RoundedRectangle(cornerRadius: cornerRadius)
            .path(in: expandedRect)
        ctx.stroke(newPath, with: .color(self.style.strokeColor.color), lineWidth: 2)
    }

    mutating func offsetMarkerBy(dx: CGFloat, dy: CGFloat) {
        self.frameRepresentation = self.frameRepresentation.offsetBy(dx: dx, dy: dy)
    }
}
