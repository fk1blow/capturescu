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

            // Contextual size control: stroke width for the drawing tools, font
            // size for the text tool. Hidden for Hand / Selection where it has no
            // meaning.
            if toolsManager.currentTool.usesSize {
                Divider().frame(height: 26).opacity(0.5)
                ToolSizeControl()
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

/// Contextual size picker. Shows the current stroke width (for freehand / line /
/// arrow) or font size (for text) as a number + icon, and opens a slider popover.
/// It writes straight to the shared ToolsManager, so the canvas updates live via
/// the existing onChange wiring.
private struct ToolSizeControl: View {
    @EnvironmentObject var toolsManager: ToolsManager

    @State private var isHovering = false
    @State private var isShowingPopover = false

    private var isText: Bool { toolsManager.currentTool.usesFontSize }
    private var range: ClosedRange<CGFloat> { isText ? 10 ... 48 : 1 ... 20 }
    private var iconName: String { isText ? "textformat.size" : "lineweight" }

    private var value: Binding<CGFloat> {
        Binding(
            get: { isText ? toolsManager.selectedTextSize : toolsManager.selectedStrokeWidth },
            set: {
                if isText { toolsManager.selectedTextSize = $0 }
                else { toolsManager.selectedStrokeWidth = $0 }
            }
        )
    }

    var body: some View {
        Button(action: { isShowingPopover.toggle() }, label: {
            HStack(spacing: 8) {
                Text(String(format: "%.0f", value.wrappedValue))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#D7DBDF"))
                    .frame(width: 16)

                Image(systemName: iconName)
                    .foregroundColor(Color(hex: "#D7DBDF"))
                    .font(.system(size: 16))
            }
            .frame(width: 62, height: 38)
            .background(RoundedRectangle(cornerRadius: 8).fill(backgroundColor))
        })
        .buttonStyle(.borderless)
        .help(isText ? "Font Size" : "Stroke Width")
        .onHover { isHovering = $0 }
        .popover(isPresented: $isShowingPopover, arrowEdge: .top) {
            HStack {
                Slider(value: value, in: range, step: 1)
                    .help(isText ? "Font Size" : "Stroke Width")
            }
            .frame(width: 200)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
    }

    private var backgroundColor: Color {
        (isHovering || isShowingPopover) ? Color.white.opacity(0.08) : Color.clear
    }
}
