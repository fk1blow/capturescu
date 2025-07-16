//
//  CaptureScreenshotCanvas.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct CaptureScreenshotCanvas: View {
    var capturedBounds: CGRect = .init()
    var capturedImage: CapturedPasteboardImage?
    var capturedMarkers: [Marker]

    var body: some View {
        Canvas { ctx, _ in
            if self.capturedImage != nil {
                let x = self.capturedImage!.position.x
                let y = self.capturedImage!.position.y
                
                // Get the screen scale to handle Retina displays properly (same as DrawingSurfaceView)
                let screenScale = NSScreen.main?.backingScaleFactor ?? 1.0
                
                // Render at actual pixel size (1:1 mapping) with user scale applied
                // Divide by screenScale to convert pixels to points (matching DrawingSurfaceView)
                let width = CGFloat(self.capturedImage!.image.width) * self.capturedImage!.scale / screenScale
                let height = CGFloat(self.capturedImage!.image.height) * self.capturedImage!.scale / screenScale
                

                // Calculate the distance between the original canvas x,y and the annotation bounds x,y
                // The "bounding box" represents a rectangle, smaller or having the same size as
                // the drawing/annotation canvas, which includes ONLY the points(min,max x/y)
                // drawn/annotated on the canvas, disregarding the canvas' original size
                // 
                // CRITICAL: Use exact pixel positioning to match bounding box calculation
                let dx = x - capturedBounds.minX
                let dy = y - capturedBounds.minY

                ctx.draw(
                    Image(
                        self.capturedImage!.image,
                        scale: 1.0, // Use 1.0 scale to match pixel-size rendering
                        label: Text("")
                    ),
                    in: CGRect(
                        origin: CGPoint(x: dx, y: dy),
                        size: CGSize(width: width, height: height)
                    )
                )
            }

            for var marker in capturedMarkers {
                // Use the same offset calculation as the image to ensure perfect alignment
                // Use exact coordinates to match bounding box calculation
                let offsetX = capturedBounds.minX
                let offsetY = capturedBounds.minY
                marker.offsetMarkerBy(dx: offsetX * -1, dy: offsetY * -1)
                marker.draw(onto: ctx)
            }
        }
        .frame(width: capturedBounds.width / (NSScreen.main?.backingScaleFactor ?? 1.0), 
               height: capturedBounds.height / (NSScreen.main?.backingScaleFactor ?? 1.0))
        // .border(.black)
        .background(Color(hex: "#282828"))
    }
}
