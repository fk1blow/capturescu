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
    var fontWeight: Font.Weight = .semibold
    var active = false
    var rotation = Angle.zero
    var fontSize = 18.0
    /// Hover tooltip text; empty shows none.
    var help: String = ""
    /// Fill color used when this button is active. Tool buttons pass the current
    /// draw color so the active tool reads as the color you'll annotate with; the
    /// icon auto-inverts (via `contrastingColor()`) to stay legible on light fills.
    /// Defaults to a neutral gray for non-tool actions.
    var activeTint: Color = Color(hex: "#585858")
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
                .cornerRadius(8)
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
    init(iconName: String, fontWeight: Font.Weight = .semibold, rotation: Angle = .zero, fontSize: Double = 18.0, help: String = "") {
        self.iconName = iconName
        self.fontWeight = fontWeight
        self.rotation = rotation
        self.fontSize = fontSize
        self.help = help
    }

    // Initializer with action and active state
    init(iconName: String, fontWeight: Font.Weight = .semibold, rotation: Angle = .zero, fontSize: Double = 18.0, help: String = "", active: Bool, activeTint: Color = Color(hex: "#585858"), action: @escaping () -> Void) {
        self.iconName = iconName
        self.fontWeight = fontWeight
        self.rotation = rotation
        self.fontSize = fontSize
        self.help = help
        self.active = active
        self.activeTint = activeTint
        self.action = action
    }

    private func getBackgroundColor() -> Color {
        if active {
            return activeTint
        }
        else if isHovering {
            return Color.white.opacity(0.08)
        }
        else {
            // Tools sit flush on the bar's own surface — no per-button chip.
            return Color.clear
        }
    }

    private func getForegroundColor() -> Color {
        if active {
            // Invert the icon on light fills (yellow, white, light gray, …) so it
            // stays readable; dark fills keep the light icon.
            return activeTint.contrastingColor()
        }
        else {
            return Color(hex: "#888888")
        }
    }
}
