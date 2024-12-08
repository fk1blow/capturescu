//
//  DrawingScene.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct DrawingSceneView: View {
    @Binding var lines: [Line]
    @Binding var drawingLine: Line

    var onDrawStart: (_ location: CGPoint) -> Void
    var onDraw: (_ location: CGPoint) -> Void
    var onDrawEnd: (_ location: CGPoint) -> Void

    @State private var isDrawing = false
    @State private var isMoving = false
    @State private var highlight: LineHighlight?
    @State private var lastDragPosition: CGPoint? = nil

    var body: some View {
        Canvas { ctx, _ in
            for line in getLinesToDraw() {
                var path = Path()
                path.addLines(line.points)
                ctx.stroke(path, with: .color(line.color), lineWidth: line.lineWidth)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onContinuousHover { phase in
            guard !isDrawing || !isMoving else { return }
            handleMouseOver(phase: phase)
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

    // TODO: refactor
    private func moveLine(to position: CGPoint) {
        guard highlight != nil else { return }

        if let lastPosition = lastDragPosition {
            // Calculate the delta of the drag
            let deltaX = position.x - lastPosition.x
            let deltaY = position.y - lastPosition.y

            // Update the line's points by adding the drag delta to each point
            // highlight!.targetLine.points = highlight!.targetLine.points.map { point in
            //     CGPoint(x: point.x + deltaX, y: point.y + deltaY)
            // }
            lines[highlight!.atIndex].points = lines[highlight!.atIndex].points.map { point in
                CGPoint(x: point.x + deltaX, y: point.y + deltaY)
            }

            // Update the last drag position
            lastDragPosition = position
        } else {
            // This is the first drag event, set the initial position
            lastDragPosition = position
        }
    }

    private func getLinesToDraw() -> [Line] {
        var linesToDraw = lines

        if highlight != nil {
            linesToDraw.append(highlight!.line)
        }

        if drawingLine.points.isEmpty == false {
            linesToDraw.append(drawingLine)
        }

        return linesToDraw
    }

    private func handleMouseOver(phase: HoverPhase) {
        switch phase {
        case .active(let location):
            for (index, line) in lines.enumerated() {
                let boundingBox = isPointNearPath(
                    testPoint: location,
                    points: line.points
                )
                if boundingBox != nil {
                    highlight = LineHighlight(line: Line.from(box: boundingBox!), atIndex: index)
                    break
                } else {
                    highlight = nil
                }
            }
        case .ended:
            highlight = nil
        }
    }
}
