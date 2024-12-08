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

    var body: some View {
        HStack(spacing: 12) {
            // dummy button to lose the fucking focus ring that's sticking to the first button
            Button(action: {}, label: {}).frame(width: 0, height: 0).background(.clear).opacity(0)
            ToolbarButton(
                iconName: "pencil",
                fontWeight: .medium,
                active: selectionManager.pointerTool.toolName == PointerToolName.FreehandPointer,
                action: { selectionManager.selectTool(named: .FreehandPointer) }
            )
            ToolbarButton(
                iconName: "pencil.line",
                fontWeight: .medium,
                active: selectionManager.pointerTool.toolName == PointerToolName.LinePointer,
                action: { selectionManager.selectTool(named: .LinePointer) }
            )
            ToolbarButton(
                iconName: "arrow.down.left",
                fontWeight: .medium,
                active: selectionManager.pointerTool.toolName == PointerToolName.ArrowPointer,
                action: { selectionManager.selectTool(named: .ArrowPointer) }
            )
            ToolbarButton(
                iconName: "character",
                fontWeight: .medium,
                active: selectionManager.pointerTool.toolName == PointerToolName.TextPointer,
                action: { selectionManager.selectTool(named: .TextPointer) }
            )
        }
    }
}
