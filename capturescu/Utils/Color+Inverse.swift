//
//  Color+Inverse.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

extension Color {
    func inverse() -> Color {
        // Convert SwiftUI Color to NSColor
        let nsColor = NSColor(self)
        
        // Convert NSColor to the sRGB color space before extracting components
        guard let convertedColor = nsColor.usingColorSpace(.sRGB) else {
            // If conversion fails, return a default color (e.g., white)
            return Color.white
        }
        
        // Extract RGB components from the sRGB NSColor
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        convertedColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Calculate the inverse color by subtracting from 1
        let invertedRed = 1 - red
        let invertedGreen = 1 - green
        let invertedBlue = 1 - blue
        
        // Return a new SwiftUI Color with the inverted RGB values
        return Color(red: invertedRed, green: invertedGreen, blue: invertedBlue)
    }
}
