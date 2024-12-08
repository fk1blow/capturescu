//
//  SizePickerButton.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct SizePickerButton: View {
    var action: (() -> Void)?

    @State private var sizeValue:Float = 1.0
    @State private var isHovering = false
    @State private var isShowingPopover = false

    var body: some View {
        Button(action: { isShowingPopover = !isShowingPopover }, label: {
            HStack(alignment: VerticalAlignment.center, spacing: 10) {
                Text(String(format: "%.0f", sizeValue))
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(Color(hex: "#D7DBDF"))
                    .frame(width: 16)

                // TODO might need to have this dynamically,
                // change the text size or the stroke width
                // so instead of the ruler, might render "textformat.size" instead
                Image(systemName: "ruler")
                    .foregroundColor(Color(hex: "#D7DBDF"))
                    .background(getBackgroundColor()) // Change background color on hover
                    .font(.system(size: 20))
                    .cornerRadius(32)
            }
            .frame(width: 74, height: 38)
            .background(RoundedRectangle(cornerRadius: 32).fill(getBackgroundColor()))
        })
        .onHover { hovering in
            isHovering = hovering
        }
        .buttonStyle(.borderless)
        .popover(
            isPresented: $isShowingPopover, arrowEdge: .top
        ) {
            ColorPickerPopup(sizeValue: $sizeValue)
        }
    }

    private func getBackgroundColor() -> Color {
        if isHovering || isShowingPopover {
            return Color(Color(hex: "#494949"))
        }
        return Color(Color(hex: "#333333"))
    }
}

private struct ColorPickerPopup: View {
    @Binding var sizeValue: Float

    var body: some View {
        HStack {
            Slider(
                value: $sizeValue,
                in: 1 ... 12,
                step: 1
            ) {} minimumValueLabel: {} maximumValueLabel: {} onEditingChanged: { _ in
                // isEditing = editing
            }
            .help("Stroke Line Width")
        }
        .frame(width: 220)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}
