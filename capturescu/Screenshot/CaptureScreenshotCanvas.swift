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
                let width = self.capturedImage!.image.width
                let height = self.capturedImage!.image.height

                // Calculate the distance between the original canvas x,y and the annotation bounds x,y
                // The "bounding box" represents a rectangle, smaller or having the same size as
                // the drawing/annotation canvas, which includes ONLY the points(min,max x/y)
                // drawn/annotated on the canvas, disregarding the canvas' original size
                let dx = x - capturedBounds.minX
                let dy = y - capturedBounds.minY

                ctx.draw(
                    Image(
                        self.capturedImage!.image,
                        scale: 1.0,
                        label: Text("")
                    ),
                    in: CGRect(
                        origin: CGPoint(x: dx, y: dy),
                        size: CGSize(width: width,
                                     height: height)
                    )
                )
            }

            for var marker in capturedMarkers {
                let dx = capturedBounds.minX
                let dy = capturedBounds.minY
                marker.offsetMarkerBy(dx: dx * -1, dy: dy * -1)
                marker.draw(onto: ctx)
            }
        }
        .frame(width: capturedBounds.width, height: capturedBounds.height)
        // .border(.black)
        .background(Color(hex: "#282828"))
    }
}
