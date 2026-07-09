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
    /// Default point size for a freshly placed text marker. The actual size is
    /// stored per-marker so different markers can carry different sizes.
    static let defaultSize: CGFloat = 14

    /// Weight shared by the editor, on-canvas draw, and export. Medium reads
    /// clearly over busy screenshots without looking bold.
    static let weight: NSFont.Weight = .medium
    static let swiftUIWeight: Font.Weight = .medium

    static func nsFont(size: CGFloat = defaultSize) -> NSFont { .systemFont(ofSize: size, weight: weight) }
    static func swiftUIFont(size: CGFloat = defaultSize) -> Font { .system(size: size, weight: swiftUIWeight) }
    /// NSFont and CTFont are toll-free bridged, so the exporter renders the
    /// exact same face as the on-screen SwiftUI text.
    static func ctFont(size: CGFloat = defaultSize) -> CTFont { nsFont(size: size) as CTFont }

    /// The maximum width a text marker wraps at before adding a new line.
    static let maxWidth: CGFloat = 280

    /// Measured bounds for `text` laid out in the marker font at `size`. Only the
    /// size is returned; the caller supplies the origin. A small padding and a
    /// minimum size keep the hit box / highlight comfortable for short or empty text.
    static func measureSize(of text: String, size: CGFloat = defaultSize) -> CGSize {
        let attributed = NSAttributedString(string: text, attributes: [.font: nsFont(size: size)])
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
    /// Point size for this marker's text, captured at creation so each marker
    /// keeps its own size independent of the current tool setting.
    var fontSize: CGFloat = TextMarkerFont.defaultSize

    init(markerColor: MarkerColor, textValue: String, frame: CGRect, fontSize: CGFloat = TextMarkerFont.defaultSize) {
        style = MarkerStyle(strokeColor: markerColor)
        textValueRepresentation = textValue
        frameRepresentation = frame
        self.fontSize = fontSize
    }

    init(markerColor: MarkerColor) {
        self.init(markerColor: markerColor, textValue: "", frame: .zero)
    }

    /// Build a marker for `text` anchored at `origin` (top-left, canvas space).
    /// The frame size is measured from the text at `fontSize` so the hit box
    /// matches what is drawn.
    init(markerColor: MarkerColor, textValue: String, origin: CGPoint, fontSize: CGFloat = TextMarkerFont.defaultSize) {
        let size = TextMarkerFont.measureSize(of: textValue, size: fontSize)
        self.init(
            markerColor: markerColor,
            textValue: textValue,
            frame: CGRect(origin: origin, size: size),
            fontSize: fontSize
        )
    }

    func draw(onto ctx: GraphicsContext) {
        let text = Text(verbatim: textValueRepresentation).font(TextMarkerFont.swiftUIFont(size: fontSize))
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
            TextMarkerRepresentation(frame: frameRepresentation, text: textValueRepresentation, fontSize: fontSize)
        )
    }

    func markerBoundingBox(near location: CGPoint) -> BoundingBox? {
        return HitDetectionManager.shared.isPointNearRect(location, rect: frameRepresentation)
    }

    mutating func offsetMarkerBy(dx: CGFloat, dy: CGFloat) {
        frameRepresentation = frameRepresentation.offsetBy(dx: dx, dy: dy)
    }
}
