//
//  ScreenshotRenderCanvas.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct ScreenshotRenderCanvas: View {
    var capturedBounds: CGRect = .init()
    var capturedImage: CapturedPasteboardImage?
    var capturedMarkers: [Marker]

    var body: some View {
        Canvas { ctx, _ in
            // Draw image in capture coordinate system
            if let capturedImage = self.capturedImage {
                // In capture coordinate system, we need to position the image correctly
                // The captured bounds represent the content area we're capturing
                
                // Calculate image position in capture coordinates
                let imagePositionInCapture: CGPoint
                let imageSize: CGSize
                
                if capturedMarkers.isEmpty {
                    // Image-only: position at (0,0) with natural size (no window scaling)
                    imagePositionInCapture = CGPoint(x: 0, y: 0)
                    // Use natural size (HiDPI only, no window scaling) for copy operations
                    imageSize = capturedImage.naturalSize
                } else {
                    // Mixed content: transform display position to capture position
                    imagePositionInCapture = CGPoint(
                        x: capturedImage.position.x - capturedBounds.minX,
                        y: capturedImage.position.y - capturedBounds.minY
                    )
                    // Use display size for mixed content
                    imageSize = capturedImage.displaySize
                }
                
                // Draw image at natural size for capture
                // Use the inverse of hiDPIScale for proper rendering
                let renderScale = 1.0 / capturedImage.hiDPIScale
                ctx.draw(
                    Image(
                        capturedImage.image,
                        scale: renderScale,
                        label: Text("")
                    ),
                    in: CGRect(
                        origin: imagePositionInCapture,
                        size: imageSize
                    )
                )
            }

            // Draw markers in capture coordinate system
            // Note: markers are already transformed to capture coordinates by the caller
            for marker in capturedMarkers {
                marker.draw(onto: ctx)
            }
        }
        .frame(width: capturedBounds.width, 
               height: capturedBounds.height)
        .drawingGroup() // Match display Canvas rendering for consistent quality
        // .border(.black)
        .background(Color(hex: "#282828"))
    }
}
