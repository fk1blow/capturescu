//
//  PointerToolView.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

enum DragState {
    case singleClick
    case doubleClick
    case dragging
}

struct PointerToolView: View {
    @EnvironmentObject var toolsManager: ToolsManager
    @EnvironmentObject var markersManager: MarkersManager

    @State private var isDrawingMarker = false
    @State private var isMovingMarker = false
    @State private var lastDragPosition: CGPoint? = nil

    var body: some View {
        ZStack(alignment: .topLeading, content: {
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged(handleDragGestureStart)
                        .onEnded(handleDragGestureEnd)

                    // TapGesture(count: 1)
                    //     .sequenced(before: TapGesture(count: 2))

                    // .updating(<#T##state: GestureState<State>##GestureState<State>#>, body: <#T##(SequenceGesture<TapGesture, TapGesture>.Value, inout State, inout Transaction) -> Void#>)
                    // see https://developer.apple.com/documentation/swiftui/composing-swiftui-gestures
                    // https://chatgpt.com/share/67462560-7d68-8011-92ed-56411336f403
                    // see also ExclusiveGesture https://developer.apple.com/documentation/swiftui/exclusivegesture
                    //         DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    //             .onChanged(handleDragGestureStart)
                    //             .onEnded(handleDragGestureEnd)
                )
                .onContinuousHover { phase in
                    handleMouseOver(phase: phase)
                }

            toolsManager.pointerTool.renderAccessoryView(onDone: { marker in
                markersManager.addMarker(marker: marker)
            })
        })
    }

    private func handleDragGestureStart(_ value: DragGesture.Value) {
        // gesture just began, which means we need to move to the starting point
        if value.translation.width + value.translation.height == 0 {
            if markersManager.isMarkerHovered() {
                handleMoveStart(value: value)
            } else {
                handleDrawStart(value: value)
            }
        } else {
            if markersManager.isMarkerHovered() {
                handleMoveUpdate(value: value)
            } else {
                handleDrawUpdate(value: value)
            }
        }
    }

    private func handleDragGestureEnd(_ value: DragGesture.Value) {
        lastDragPosition = nil

        if value.translation.width + value.translation.height == 0 {
            handleDrawStop()
            handleClick(value: value)
        } else {
            if markersManager.isMarkerHovered() {
                handleMoveEnd(value: value)
            } else {
                handleDrawEnd(value: value)
            }
        }
    }

    // #region Drawing

    private func handleDrawStart(value: DragGesture.Value) {
        isDrawingMarker = true
        markersManager.clearSelectedMarker()
        toolsManager.pointerTool.beginMarker(at: value.location)
    }

    private func handleDrawUpdate(value: DragGesture.Value) {
        toolsManager.pointerTool.updateMarker(at: value.location)
    }

    private func handleDrawEnd(value: DragGesture.Value) {
        isDrawingMarker = false
        markersManager.addMarker(marker: toolsManager.pointerTool.getMarker())
        toolsManager.pointerTool.endMarker(at: value.location)
    }

    private func handleDrawStop() {
        isDrawingMarker = false
        toolsManager.pointerTool.clearMarker()
    }

    // #endregion

    // #region Clicking

    private func handleClick(value: DragGesture.Value) {
        if markersManager.isMarkerHovered() == false {
            // clear the previously selected marker
            markersManager.clearSelectedMarker()
            // informs the pointer tool of the click on the pointer tool view(canvas)
            toolsManager.pointerTool.pointerClicked(at: value.location)
        }
    }

    // #endregion

    // #region Movine/Dragging

    private func handleMoveStart(value: DragGesture.Value) {
        isMovingMarker = true
        markersManager.selectHoveredMarker()
    }

    private func handleMoveUpdate(value: DragGesture.Value) {
        guard markersManager.selectedMarker != nil else { return }

        isMovingMarker = false

        let position = value.location

        if let lastPosition = lastDragPosition {
            // Calculate the delta of the drag
            let deltaX = position.x - lastPosition.x
            let deltaY = position.y - lastPosition.y

            markersManager.moveSelectedMarker(to:
                CGPoint(x: deltaX, y: deltaY)
            )

            // Update the last drag position
            lastDragPosition = position
        } else {
            // This is the first drag event, set the initial position
            lastDragPosition = position
        }
    }

    private func handleMoveEnd(value: DragGesture.Value) {
        isMovingMarker = false
    }

    // #endregion

    private func handleMouseOver(phase: HoverPhase) {
        guard !isDrawingMarker || !isMovingMarker else { return }

        switch phase {
        case .active(let location):
            for (index, marker) in markersManager.markers.enumerated() {
                let boundingBox = marker.markerBoundingBox(near: location)
                if boundingBox != nil {
                    markersManager.setHoveredMarker(on: marker, atIndex: index)
                    break
                } else {
                    markersManager.clearHoveredMarker()
                }
            }
        case .ended:
            break
        }
    }
}
