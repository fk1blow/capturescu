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

    var body: some View {
        HStack(spacing: 10) {
            ColorPickerButton()

            Divider().frame(height: 28)

            ToolbarButton(
                iconName: "pencil",
                active: toolsManager.currentTool == .FreehandPointer
            ) {
                toolsManager.selectTool(named: .FreehandPointer)
            }

            ToolbarButton(
                iconName: "pencil.line",
                active: toolsManager.currentTool == .LinePointer
            ) {
                toolsManager.selectTool(named: .LinePointer)
            }

            ToolbarButton(
                iconName: "arrow.down.left",
                active: toolsManager.currentTool == .ArrowPointer
            ) {
                toolsManager.selectTool(named: .ArrowPointer)
            }

            ToolbarButton(
                iconName: "character",
                active: toolsManager.currentTool == .TextPointer
            ) {
                toolsManager.selectTool(named: .TextPointer)
            }

            ToolbarButton(
                iconName: "hand.draw",
                active: toolsManager.currentTool == .HandPointer
            ) {
                toolsManager.selectTool(named: .HandPointer)
            }

            Divider().frame(height: 28)

            ToolbarButton(iconName: "doc.on.clipboard", active: false) {
                copyAction()
            }

            ToolbarButton(iconName: "xmark", active: false) {
                closeAction()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: "#1E1E1E"))
                .opacity(0.95)
        )
    }
}
