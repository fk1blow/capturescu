//
//  MiniToolbarView.swift
//  capturescu
//
//  Compact floating toolbar for the capture-annotation flow: the existing
//  color picker, a draw/text toggle, plus copy and close. It shares the same
//  ToolsManager / MarkersManager / EventManager instances as the annotation
//  canvas, so flipping the tool or color here drives the canvas via the
//  existing onChange wiring in DrawingSurfaceView — no extra plumbing.
//

import SwiftUI

struct MiniToolbarView: View {
    @EnvironmentObject var toolsManager: ToolsManager

    var copyAction: () -> Void
    var closeAction: () -> Void

    private var activeTint: Color {
        toolsManager.selectedColor.color
    }

    var body: some View {
        HStack(spacing: 6) {
            ColorPickerButton()
                .help("Color")

            Divider().frame(height: 26).opacity(0.5)

            ToolbarButton(
                iconName: "pencil.and.scribble",
                help: "Freehand",
                active: toolsManager.currentTool == .FreehandPointer,
                activeTint: activeTint
            ) {
                toolsManager.selectTool(named: .FreehandPointer)
            }

            ToolbarButton(
                iconName: "line.diagonal",
                help: "Line",
                active: toolsManager.currentTool == .LinePointer,
                activeTint: activeTint
            ) {
                toolsManager.selectTool(named: .LinePointer)
            }

            ToolbarButton(
                iconName: "arrow.down.left",
                help: "Arrow",
                active: toolsManager.currentTool == .ArrowPointer,
                activeTint: activeTint
            ) {
                toolsManager.selectTool(named: .ArrowPointer)
            }

            ToolbarButton(
                iconName: "character",
                help: "Text",
                active: toolsManager.currentTool == .TextPointer,
                activeTint: activeTint
            ) {
                toolsManager.selectTool(named: .TextPointer)
            }

            ToolbarButton(
                iconName: "hand.draw",
                help: "Move (hold ⌘)",
                active: toolsManager.currentTool == .HandPointer,
                activeTint: activeTint
            ) {
                toolsManager.selectTool(named: .HandPointer)
            }

            Divider().frame(height: 26).opacity(0.5)

            ToolbarButton(iconName: "doc.on.clipboard", help: "Copy", active: false) {
                copyAction()
            }

            ToolbarButton(iconName: "xmark", help: "Close", active: false) {
                closeAction()
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#3A3A3C"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
