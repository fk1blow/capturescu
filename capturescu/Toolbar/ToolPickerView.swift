//
//  ToolPickerView.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct ToolPickerView: View {
    @EnvironmentObject var selectionManager: ToolsManager

    private var activeTint: Color {
        selectionManager.selectedColor.color
    }

    var body: some View {
        HStack(spacing: 4) {
            // dummy button to lose the fucking focus ring that's sticking to the first button
            Button(action: {}, label: {}).frame(width: 0, height: 0).background(.clear).opacity(0)
            ToolbarButton(
                iconName: "pencil.and.scribble",
                fontWeight: .semibold,
                help: "Freehand",
                active: selectionManager.pointerTool.toolName == PointerToolName.FreehandPointer,
                activeTint: activeTint,
                action: { selectionManager.selectTool(named: .FreehandPointer) }
            )
            ToolbarButton(
                iconName: "line.diagonal",
                fontWeight: .semibold,
                help: "Line",
                active: selectionManager.pointerTool.toolName == PointerToolName.LinePointer,
                activeTint: activeTint,
                action: { selectionManager.selectTool(named: .LinePointer) }
            )
            ToolbarButton(
                iconName: "arrow.down.left",
                fontWeight: .semibold,
                help: "Arrow",
                active: selectionManager.pointerTool.toolName == PointerToolName.ArrowPointer,
                activeTint: activeTint,
                action: { selectionManager.selectTool(named: .ArrowPointer) }
            )
            ToolbarButton(
                iconName: "character",
                fontWeight: .semibold,
                help: "Text",
                active: selectionManager.pointerTool.toolName == PointerToolName.TextPointer,
                activeTint: activeTint,
                action: { selectionManager.selectTool(named: .TextPointer) }
            )
            ToolbarButton(
                iconName: "arrow.up.left.and.arrow.down.right",
                fontWeight: .semibold,
                help: "Select",
                active: selectionManager.pointerTool.toolName == PointerToolName.SelectionPointer,
                activeTint: activeTint,
                action: { selectionManager.selectTool(named: .SelectionPointer) }
            )
        }
    }
}
