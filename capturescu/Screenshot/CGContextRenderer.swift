//
//  CGContextRenderer.swift
//  capturescu
//
//  Core Graphics-based rendering to avoid SwiftUI ImageRenderer quality loss
//

import Foundation
import CoreGraphics
import AppKit
import CoreText
import UniformTypeIdentifiers
import SwiftUI  // For Path type

struct CGContextRenderer {

    /// Render image with markers using Core Graphics (minimal quality loss)
    /// Returns PNG data with preserved DPI metadata
    static func renderWithMarkers(
        image: CGImage?,
        markers: [Marker],
        bounds: CGRect,
        imagePosition: CGPoint,
        imageSize: CGSize,
        hiDPIScale: CGFloat,
        backgroundColor: CGColor = CGColor(red: 0.157, green: 0.157, blue: 0.157, alpha: 1.0) // #282828
    ) -> Data? {
        // Calculate pixel dimensions (accounting for screen scale)
        let screenScale = NSScreen.main?.backingScaleFactor ?? 2.0
        let pixelWidth = Int(bounds.width * screenScale)
        let pixelHeight = Int(bounds.height * screenScale)

        guard pixelWidth > 0 && pixelHeight > 0 else { return nil }

        // Create CGContext with proper color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            print("DEBUG CGCONTEXT: Failed to create context")
            return nil
        }

        // Configure context for high-quality rendering
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.interpolationQuality = .high

        // Scale context for Retina rendering
        context.scaleBy(x: screenScale, y: screenScale)

        // Flip coordinate system (CGContext is bottom-left origin, SwiftUI is top-left)
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)

        // Fill background
        context.setFillColor(backgroundColor)
        context.fill(CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))

        // Draw original image at exact position (if present)
        if let image = image {
            let imageRect = CGRect(origin: imagePosition, size: imageSize)
            // Need to flip image drawing since we flipped the context
            context.saveGState()
            context.translateBy(x: imageRect.origin.x, y: imageRect.origin.y + imageRect.height)
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(origin: .zero, size: imageRect.size))
            context.restoreGState()
        }

        // Draw markers using Core Graphics
        for marker in markers {
            drawMarker(marker, in: context)
        }

        // Create final image
        guard let outputImage = context.makeImage() else {
            print("DEBUG CGCONTEXT: Failed to make image from context")
            return nil
        }

        // Convert to PNG with DPI metadata
        let dpiValue = 72.0 / hiDPIScale
        return createPNGData(from: outputImage, dpi: dpiValue)
    }

    /// Draw a marker onto CGContext
    private static func drawMarker(_ marker: Marker, in context: CGContext) {
        let representation = marker.getRepresentation()

        switch representation {
        case .path(let path):
            drawPath(path, style: marker.style, in: context)
        case .text(let textRep):
            drawText(textRep, style: marker.style, in: context)
        case .image:
            break // Not currently used
        }
    }

    /// Draw a SwiftUI Path using Core Graphics
    private static func drawPath(_ path: Path, style: MarkerStyle, in context: CGContext) {
        let cgPath = path.cgPath

        context.saveGState()

        // Set stroke properties
        let strokeColor = cgColor(from: style.strokeColor)
        context.setStrokeColor(strokeColor)
        context.setLineWidth(style.strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.addPath(cgPath)

        // Fill if needed, then stroke
        if let fillColor = style.fillColor {
            let fillCGColor = cgColor(from: fillColor)
            context.setFillColor(fillCGColor)
            context.drawPath(using: .fillStroke)
        } else {
            context.strokePath()
        }

        context.restoreGState()
    }

    /// Draw text using Core Text
    private static func drawText(_ textRep: TextMarkerRepresentation, style: MarkerStyle, in context: CGContext) {
        let text = textRep.text
        let frame = textRep.frame

        guard !text.isEmpty else { return }

        context.saveGState()

        // Create font and color
        let font = CTFontCreateWithName("Helvetica" as CFString, 14, nil)
        let color = cgColor(from: style.strokeColor)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(cgColor: color) ?? .white
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)

        // Create CTLine for drawing
        let line = CTLineCreateWithAttributedString(attributedString)

        // Position text - need to handle coordinate system
        // CGContext text position is at baseline, and we've flipped coordinates
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(x: frame.origin.x, y: frame.origin.y + 14) // Adjust for font baseline

        CTLineDraw(line, context)

        context.restoreGState()
    }

    /// Convert MarkerColor to CGColor
    private static func cgColor(from markerColor: MarkerColor) -> CGColor {
        switch markerColor {
        case .red: return CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        case .blue: return CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        case .green: return CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        case .yellow: return CGColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
        case .orange: return CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
        case .purple: return CGColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 1.0)
        case .black: return CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        case .white: return CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        case .gray: return CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        case .lightGray: return CGColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
        case .lightBlue: return CGColor(red: 0.7, green: 0.85, blue: 1.0, alpha: 1.0)
        case .lightGreen: return CGColor(red: 0.6, green: 1.0, blue: 0.6, alpha: 1.0)
        case .pink: return CGColor(red: 1.0, green: 0.75, blue: 0.8, alpha: 1.0)
        case .brown: return CGColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0)
        case .teal: return CGColor(red: 0.0, green: 0.75, blue: 0.75, alpha: 1.0)
        case .cyan: return CGColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0)
        }
    }

    /// Create PNG data with DPI metadata
    private static func createPNGData(from image: CGImage, dpi: CGFloat) -> Data? {
        let mutableData = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            mutableData, UTType.png.identifier as CFString, 1, nil
        ) else {
            print("DEBUG CGCONTEXT: Failed to create image destination")
            return nil
        }

        let metadata: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi
        ]

        CGImageDestinationAddImage(destination, image, metadata as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            print("DEBUG CGCONTEXT: Failed to finalize image destination")
            return nil
        }

        print("DEBUG CGCONTEXT: Created PNG data (\(mutableData.length) bytes) with DPI=\(dpi)")
        return mutableData as Data
    }
}
