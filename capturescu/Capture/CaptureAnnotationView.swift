//
//  CaptureAnnotationView.swift
//  capturescu
//
//  The "snapshot editor" surface. It's intentionally thin: it reuses the
//  existing DrawingSurfaceView, rendered at the viewport size (the visible image
//  area, capped to the screen). A dashed/interrupted white border always frames
//  the snapshot — drawn as a stroke in a 2px padding ring around the viewport,
//  so it never covers the image. When the screenshot is bigger than the
//  viewport, the hand tool pans it 1:1 inside this frame. Tool/marker state
//  comes from the environment objects injected by AnnotationWindowController.
//

import SwiftUI

struct CaptureAnnotationView: View {
    let capturedImage: CapturedPasteboardImage
    let viewportSize: CGSize
    var initialCanvasOffset: CGPoint = .zero

    private let borderWidth: CGFloat = 2

    var body: some View {
        DrawingSurfaceView(capturedImage: capturedImage, initialCanvasOffset: initialCanvasOffset)
            .frame(width: viewportSize.width, height: viewportSize.height)
            .clipped()
            .padding(borderWidth)
            .overlay(
                Rectangle().strokeBorder(
                    Color.white,
                    style: StrokeStyle(lineWidth: borderWidth, dash: [6, 4])
                )
            )
    }
}
