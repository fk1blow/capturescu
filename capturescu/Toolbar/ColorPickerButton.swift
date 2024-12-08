//
//  ColorPickerButton.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct ColorPickerButton: View {
    @EnvironmentObject var selectionManager: ToolsManager
    @EnvironmentObject var markerManager: MarkersManager

    @State private var isHovering = false
    @State private var isShowingPopover = false

    var body: some View {
        Button(action: { isShowingPopover = !isShowingPopover }, label: {
            HStack(alignment: VerticalAlignment.center, spacing: 14) {
                Circle().fill(getSelectedColor().color)
                    .stroke(Color(hex: "#D7DBDF"), lineWidth: 2)
                    .frame(width: 20, height: 20)

                Image(systemName: "eyedropper")
                    .foregroundColor(Color(hex: "#D7DBDF"))
                    .background(getBackgroundColor()) // Change background color on hover
                    .font(.system(size: 16, weight: .regular))
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
            ColorPickerPopup(selectedColor: getSelectedColor(), onPick: { colorName in
                selectionManager.changeToolColor(with: colorName)
                isShowingPopover = false
            })
        }
    }

    private func getBackgroundColor() -> Color {
        if isHovering || isShowingPopover {
            return Color(Color(hex: "#494949"))
        }
        return Color(Color(hex: "#333333"))
    }

    private func getSelectedColor() -> MarkerColor {
        if markerManager.selectedMarker != nil {
            return markerManager.selectedMarker!.marker.style.strokeColor
        }
        return selectionManager.selectedColor
    }
}

private struct ColorPickerPopup: View {
    var selectedColor: MarkerColor
    var onPick: (_ color: MarkerColor) -> Void

    var body: some View {
        HStack {
            // First column of colors (first half)
            VStack(spacing: 12) {
                ForEach(0..<MarkerColor.allCases.count / 2, id: \.self) { idx in
                    let namedColor = MarkerColor.allCases[idx]
                    Button(action: {
                        onPick(namedColor)
                    }, label: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(namedColor.color) // Access the color property
                            .frame(width: 64, height: 20)
                            .overlay(
                                selectedColor.name == namedColor.name
                                    ? RoundedRectangle(cornerRadius: 3)
                                    .fill(namedColor.color.contrastingColor())
                                    .frame(width: 14, height: 8)
                                    .offset(x: -20, y: 0)
                                    : nil
                            )
                    })
                    .fixedSize()
                    .buttonStyle(.plain)
                }
            }

            // Second column of colors (second half)
            VStack(spacing: 12) {
                ForEach(MarkerColor.allCases.count / 2..<MarkerColor.allCases.count, id: \.self) { idx in
                    let namedColor = MarkerColor.allCases[idx]
                    Button(action: {
                        onPick(namedColor)
                    }, label: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(namedColor.color) // Access the color property
                            .frame(width: 64, height: 20)
                            .overlay(
                                selectedColor.name == namedColor.name
                                    ? RoundedRectangle(cornerRadius: 4)
                                    .fill(namedColor.color.contrastingColor())
                                    .frame(width: 14, height: 8)
                                    .offset(x: -20, y: 0)
                                    : nil
                            )
                    })
                    .fixedSize()
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.tertiarySystemFill)))
    }
}
