//
//  CaptureAnnotationView.swift
//  capturescu
//
//  The MVP "annotate in place" screen. It's intentionally thin: it reuses the
//  existing DrawingSurfaceView, feeding it the cropped capture positioned at
//  the origin so the image fills the borderless window exactly. Tool/marker
//  state comes from the environment objects injected by AnnotationWindowController.
//

import SwiftUI

struct CaptureAnnotationView: View {
    let capturedImage: CapturedPasteboardImage

    var body: some View {
        DrawingSurfaceView(capturedImage: capturedImage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
    }
}
