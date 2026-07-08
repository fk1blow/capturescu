//
//  TextMarker.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI
import AppKit

/// Single source of truth for the text-marker font, shared by the inline
/// editor, the on-canvas draw, size measurement, and the PNG exporter. Keeping
/// one definition guarantees the input field, the on-screen marker, and the
/// exported image all use identical metrics.
enum TextMarkerFont {
    static let size: CGFloat = 14

    static var nsFont: NSFont { .systemFont(ofSize: size) }
    static var swiftUIFont: Font { .system(size: size) }
    /// NSFont and CTFont are toll-free bridged, so the exporter renders the
    /// exact same face as the on-screen SwiftUI text.
    static var ctFont: CTFont { nsFont as CTFont }

    /// The maximum width a text marker wraps at before adding a new line.
    static let maxWidth: CGFloat = 280

    /// Measured bounds for `text` laid out in the marker font. Only the size is
    /// returned; the caller supplies the origin. A small padding and a minimum
    /// size keep the hit box / highlight comfortable for short or empty text.
    static func measureSize(of text: String) -> CGSize {
        let attributed = NSAttributedString(string: text, attributes: [.font: nsFont])
        let bounds = attributed.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return CGSize(
            width: max(ceil(bounds.width) + 4, 20),
            height: max(ceil(bounds.height) + 4, 16)
        )
    }
}

struct TextMarker: Marker {
    var id = UUID()

    var style: MarkerStyle
    var isHighlighted: Bool = false

    var textValueRepresentation: String = ""
    var frameRepresentation: CGRect = .zero

    init(markerColor: MarkerColor, textValue: String, frame: CGRect) {
        style = MarkerStyle(strokeColor: markerColor)
        textValueRepresentation = textValue
        frameRepresentation = frame
    }

    init(markerColor: MarkerColor) {
        self.init(markerColor: markerColor, textValue: "", frame: .zero)
    }

    /// Build a marker for `text` anchored at `origin` (top-left, canvas space).
    /// The frame size is measured from the text so the hit box matches what is
    /// drawn.
    init(markerColor: MarkerColor, textValue: String, origin: CGPoint) {
        let size = TextMarkerFont.measureSize(of: textValue)
        self.init(
            markerColor: markerColor,
            textValue: textValue,
            frame: CGRect(origin: origin, size: size)
        )
    }

    func draw(onto ctx: GraphicsContext) {
        let text = Text(verbatim: textValueRepresentation).font(TextMarkerFont.swiftUIFont)
        var resolvedText = ctx.resolve(text)
        resolvedText.shading = .color(style.strokeColor.color)
        // Anchor at the frame's top-left using the text's natural size (no
        // scaling), so the rendered glyphs sit exactly where the inline editor
        // placed them.
        ctx.draw(resolvedText, at: frameRepresentation.origin, anchor: .topLeading)

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
}
