//
//  DrawingSurfaceView.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct DrawingSurfaceView: View {
    var capturedImage: CapturedPasteboardImage?

    @EnvironmentObject var toolsManager: ToolsManager
    @EnvironmentObject var markersManager: MarkersManager

    var body: some View {
        Canvas { ctx, size in
            if capturedImage != nil {
                let x = capturedImage!.position.x
                let y = capturedImage!.position.y
                
                // Get the screen scale to handle Retina displays properly
                let screenScale = NSScreen.main?.backingScaleFactor ?? 1.0
                
                // Convert pixels to points by dividing by screen scale, then apply user scale
                let width = (CGFloat(capturedImage!.image.width) / screenScale) * capturedImage!.scale
                let height = (CGFloat(capturedImage!.image.height) / screenScale) * capturedImage!.scale

                print("🎨 CANVAS RENDER DEBUG:")
                print("   Canvas size: \(size.width) x \(size.height)")
                print("   Screen scale: \(screenScale)")
                print("   Image original pixels: \(capturedImage!.image.width) x \(capturedImage!.image.height)")
                print("   Image original points: \(CGFloat(capturedImage!.image.width) / screenScale) x \(CGFloat(capturedImage!.image.height) / screenScale)")
                print("   Image user scale: \(capturedImage!.scale)")
                print("   Rendering at: \(width) x \(height)")
                print("   Position: (\(x), \(y))")
                
                ctx.draw(
                    Image(
                        capturedImage!.image,
                        scale: screenScale, // Use screen scale to convert pixels to points
                        label: Text("")
                    ),
                    in: CGRect(
                        origin: CGPoint(x: x, y: y),
                        size: CGSize(width: width, height: height)
                    )
                )
            }

            // These are the markers that were already drawn (on paper so to speak)
            for marker in markersManager.markers {
                marker.draw(onto: ctx)
            }

            // Draw the current pointer's marker
            // This basically represents the ongoing drawing operation(and its render representation)
            toolsManager.pointerTool.drawMarker(onto: ctx)
        }
        .overlay(
            PointerToolView()
        )
    }
}
