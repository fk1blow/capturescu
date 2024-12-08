//
//  AnnotationCanvas.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct AnnotationCanvas: View {
    var drawingsAnnotation: [Path]
    var capturedImageAnnotation: CapturedPasteboardImage?

    var onDrawStart: (_ location: CGPoint) -> Void
    var onDraw: (_ location: CGPoint) -> Void
    var onDrawEnd: (_ location: CGPoint) -> Void

    @State private var isDrawing = false
    @State private var isMoving = false
    @State private var highlight: LineHighlight?
    @State private var lastDragPosition: CGPoint? = nil

    var body: some View {
        Canvas { ctx, _ in
            if capturedImageAnnotation != nil {
                let x = capturedImageAnnotation!.position.x
                let y = capturedImageAnnotation!.position.y
                let width = capturedImageAnnotation!.image.width
                let height = capturedImageAnnotation!.image.height

                ctx.draw(
                    Image(
                        capturedImageAnnotation!.image,
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

            for annotationPath in drawingsAnnotation {
                let newPath = annotationPath.offsetBy(dx: 0, dy: 0)
                ctx.stroke(newPath, with: .color(.red), lineWidth: 3)
                // TODO: see the proposed AnnotationTool protocol changes
                // ctx.fill(newPath, with: .color(Color.red))
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged(handleDragGestureStart)
                .onEnded(handleDragGestureEnd)
        )
    }

    private func handleDragGestureStart(_ value: DragGesture.Value) {
        // gesture just began, which means we need to move to the starting point
        if value.translation.width + value.translation.height == 0 {
            if highlight != nil {
                isMoving = true
                isDrawing = false
            } else {
                isDrawing = true
                isMoving = false
                onDrawStart(value.location)
            }
        } else {
            if value.translation.width + value.translation.height == 0 {
                return
            }

            if isMoving {
                moveLine(to: value.location)
            } else {
                onDraw(value.location)
            }
        }
    }

    private func handleDragGestureEnd(_ value: DragGesture.Value) {
        lastDragPosition = nil

        if isMoving {
            highlight = nil
            isMoving = false
        } else {
            onDrawEnd(value.location)
            isDrawing = false
        }
    }

    private func moveLine(to position: CGPoint) {
        // TODO:
    }
}
