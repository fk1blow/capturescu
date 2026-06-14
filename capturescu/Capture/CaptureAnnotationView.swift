//
//  CaptureAnnotationView.swift
//  capturescu
//
//  The "snapshot editor" surface. It's intentionally thin: it reuses the
//  existing DrawingSurfaceView, feeding it the cropped capture positioned at
//  the origin (top-left). The window can be larger than the snapshot (minimum
//  size for tiny captures), so a gray background fills the remaining area.
//  Tool/marker state comes from the environment objects injected by
//  AnnotationWindowController.
//

import SwiftUI

struct CaptureAnnotationView: View {
    let capturedImage: CapturedPasteboardImage

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Fills the window; the opaque snapshot covers its top-left region
            // and this shows through wherever the snapshot doesn't reach.
            Color(hex: "#3C3C3C")
                .ignoresSafeArea()

            DrawingSurfaceView(capturedImage: capturedImage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        }
    }
}
