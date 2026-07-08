//
//  ToolbarButton.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct ToolbarButton: View {
    var iconName: String
    var fontWeight: Font.Weight = .regular
    var active = false
    var rotation = Angle.zero
    var fontSize = 18.0
    /// Hover tooltip text; empty shows none.
    var help: String = ""
    var action: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        Button(action: {
            action?() // Call the action when the button is pressed
        }, label: {
            Image(systemName: iconName)
                .frame(width: 38, height: 38)
                .foregroundColor(getForegroundColor())
                .background(getBackgroundColor()) // Change background color on hover
                .font(.system(size: fontSize, weight: fontWeight))
                .cornerRadius(32)
                .rotationEffect(rotation)
        })
        // .buttonStyle(PlainButtonStyle())
        .buttonStyle(.borderless)
        .help(help)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    // Initializer without action and active state
    init(iconName: String, fontWeight: Font.Weight = .regular, rotation: Angle = .zero, fontSize: Double = 18.0, help: String = "") {
        self.iconName = iconName
        self.fontWeight = fontWeight
        self.rotation = rotation
        self.fontSize = fontSize
        self.help = help
    }

    // Initializer with action and active state
    init(iconName: String, fontWeight: Font.Weight = .regular, rotation: Angle = .zero, fontSize: Double = 18.0, help: String = "", active: Bool, action: @escaping () -> Void) {
        self.iconName = iconName
        self.fontWeight = fontWeight
        self.rotation = rotation
        self.fontSize = fontSize
        self.help = help
        self.active = active
        self.action = action
    }

    private func getBackgroundColor() -> Color {
        if active {
            return Color(Color(hex: "#585858"))
        }
        else if isHovering {
            return Color(Color(hex: "#494949"))
        }
        else {
            return Color(Color(hex: "#333333"))
        }
    }

    private func getForegroundColor() -> Color {
        if active {
            return Color(hex: "#D7DBDF")
        }
        else {
            return Color(hex: "#888888")
        }
    }
}
