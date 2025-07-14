//
//  WindowStyleModifier.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI
import AppKit

class WindowSizeManager: ObservableObject {
    static let shared = WindowSizeManager()
    
    // Minimum window size constraints
    static let minimumWidth: CGFloat = 520
    static let minimumHeight: CGFloat = 300
    
    private init() {}
    
    // Get the main screen size with some padding for safety
    private var maxWindowSize: CGSize {
        guard let screen = NSScreen.main else {
            return CGSize(width: 1200, height: 800) // fallback
        }
        // Leave some padding (100pts) from screen edges
        return CGSize(
            width: screen.frame.width - 100,
            height: screen.frame.height - 100
        )
    }
    
    // Calculate optimal window size based on image dimensions
    func calculateWindowSize(for imageSize: CGSize) -> CGSize {
        let maxSize = maxWindowSize
        let screenScale = NSScreen.main?.backingScaleFactor ?? 1.0
        
        // Convert pixel dimensions to points
        let imageSizeInPoints = CGSize(
            width: imageSize.width / screenScale,
            height: imageSize.height / screenScale
        )
        
        // Start with the actual image size in points (no upscaling)
        var windowWidth = imageSizeInPoints.width
        var windowHeight = imageSizeInPoints.height
        
        // Only scale down if image is larger than screen
        if windowWidth > maxSize.width || windowHeight > maxSize.height {
            let widthScale = maxSize.width / windowWidth
            let heightScale = maxSize.height / windowHeight
            let scale = min(widthScale, heightScale)
            
            windowWidth *= scale
            windowHeight *= scale
        }
        
        // Ensure minimum size
        windowWidth = max(windowWidth, Self.minimumWidth)
        windowHeight = max(windowHeight, Self.minimumHeight)
        
        return CGSize(width: windowWidth, height: windowHeight)
    }
    
    // Calculate image scale factor based on window constraints
    func calculateImageScale(for imageSize: CGSize) -> CGFloat {
        let maxSize = maxWindowSize
        let screenScale = NSScreen.main?.backingScaleFactor ?? 1.0
        
        // Convert pixel dimensions to points
        let imageSizeInPoints = CGSize(
            width: imageSize.width / screenScale,
            height: imageSize.height / screenScale
        )
        
        // If image fits within max size, no scaling needed (keep at actual size)
        if imageSizeInPoints.width <= maxSize.width && imageSizeInPoints.height <= maxSize.height {
            return 1.0
        }
        
        // Only scale down if image is larger than max size
        let widthScale = maxSize.width / imageSizeInPoints.width
        let heightScale = maxSize.height / imageSizeInPoints.height
        return min(widthScale, heightScale, 1.0) // Never scale above 1.0 (no upscaling)
    }
    
    // Resize the window to the specified size
    func resizeWindow(to size: CGSize) {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                let currentFrame = window.frame
                let newFrame = CGRect(
                    x: currentFrame.origin.x,
                    y: currentFrame.origin.y + (currentFrame.height - size.height), // Adjust y to keep window position
                    width: size.width,
                    height: size.height
                )
                window.setFrame(newFrame, display: true, animate: false)
            }
        }
    }
    
    // Set initial window size
    func setInitialWindowSize() {
        let initialSize = CGSize(width: Self.minimumWidth, height: Self.minimumHeight)
        resizeWindow(to: initialSize)
    }
}

struct WindowStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(GeometryReader { _ in
                Color.clear
                    .onAppear {
                        if let window = NSApplication.shared.windows.first {
                            // Make the title bar transparent and hide the title
                            window.titlebarAppearsTransparent = true
                            window.titleVisibility = .hidden

                            // Keep the traffic light (semaphore) buttons by keeping `.titled`
                            window.styleMask.insert(.titled)

                            // Ensure the window is movable only in custom draggable region
                            window.isMovableByWindowBackground = false
                            window.styleMask.insert([.closable, .miniaturizable, .resizable])
                            
                            // Set initial window size
                            WindowSizeManager.shared.setInitialWindowSize()
                        }
                    }
            })
    }
}

extension View {
    func customWindowStyle() -> some View {
        self.modifier(WindowStyleModifier())
    }
}
