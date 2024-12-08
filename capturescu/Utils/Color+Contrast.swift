//
//  Color+Contrast.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

extension Color {
    // This function returns either .black or .white based on the Color's luminance
    func contrastingColor() -> Color {
        // Convert SwiftUI Color to NSColor and convert to sRGB color space
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.white
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Safely extract the RGB components, assuming the color is now in sRGB
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Calculate luminance based on the RGB components
        let luminance = (0.299 * red + 0.587 * green + 0.114 * blue)
        
        // If luminance is less than 0.5, return .white, else return .black
        return luminance < 0.5 ? .white : .black
    }
}
