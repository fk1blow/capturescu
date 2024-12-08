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
                let width = capturedImage!.image.width
                let height = capturedImage!.image.height

                ctx.draw(
                    Image(
                        capturedImage!.image,
                        scale: 1.0, // this can be used when implementing the zoom feature
                        label: Text("")
                    ),
                    in: CGRect(
                        origin: CGPoint(x: x, y: y),
                        size: CGSize(width: width,
                                     height: height)
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
