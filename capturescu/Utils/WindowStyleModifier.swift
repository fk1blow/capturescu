//
//  WindowStyleModifier.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI
import AppKit

// Layout constants for spacing and padding
struct LayoutConstants {
    // Image padding on all sides
    static let imagePadding: CGFloat = 60
    
    // Toolbar dimensions and spacing
    static let toolbarHeight: CGFloat = 58
    static let toolbarClearance: CGFloat = 60  // Distance between image and toolbar
    static let toolbarBottomOffset: CGFloat = 24  // Current toolbar offset from bottom
    
    // Total additional space needed
    static let totalHorizontalPadding: CGFloat = imagePadding * 2  // 120px (left + right)
    static let totalVerticalSpace: CGFloat = imagePadding * 2 + toolbarHeight + toolbarClearance  // 238px
    
    // Minimum window dimensions with padding
    static let baseMinimumWidth: CGFloat = 520
    static let baseMinimumHeight: CGFloat = 300
    static let minimumWidth: CGFloat = baseMinimumWidth + totalHorizontalPadding  // 640px
    static let minimumHeight: CGFloat = baseMinimumHeight + totalVerticalSpace  // 538px
}

class WindowSizeManager: ObservableObject {
    static let shared = WindowSizeManager()
    
    // Minimum window size constraints (now using LayoutConstants)
    static let minimumWidth: CGFloat = LayoutConstants.minimumWidth
    static let minimumHeight: CGFloat = LayoutConstants.minimumHeight
    
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
        
        // Work with actual pixel dimensions - don't convert to points
        // Images already have their natural size after HiDPI scaling
        let imagePixelSize = imageSize
        
        // Calculate available space for image (accounting for padding and toolbar)
        let availableWidth = maxSize.width - LayoutConstants.totalHorizontalPadding
        let availableHeight = maxSize.height - LayoutConstants.totalVerticalSpace
        
        // Start with the actual image size (no upscaling)
        var imageWidth = imagePixelSize.width
        var imageHeight = imagePixelSize.height
        
        // Only scale down if image is larger than available space
        if imageWidth > availableWidth || imageHeight > availableHeight {
            let widthScale = availableWidth / imageWidth
            let heightScale = availableHeight / imageHeight
            let scale = min(widthScale, heightScale)
            
            imageWidth *= scale
            imageHeight *= scale
        }
        
        // Calculate final window size including padding and toolbar space
        let windowWidth = imageWidth + LayoutConstants.totalHorizontalPadding
        let windowHeight = imageHeight + LayoutConstants.totalVerticalSpace
        
        // Ensure minimum size
        let finalWidth = max(windowWidth, Self.minimumWidth)
        let finalHeight = max(windowHeight, Self.minimumHeight)
        
        return CGSize(width: finalWidth, height: finalHeight)
    }
    
    // Calculate image scale factor based on window constraints
    func calculateImageScale(for imageSize: CGSize) -> CGFloat {
        let maxSize = maxWindowSize
        
        // Work with actual pixel dimensions - don't convert to points
        // Images already have their natural size after HiDPI scaling
        let imagePixelSize = imageSize
        
        // Calculate available space for image (accounting for padding and toolbar)
        let availableWidth = maxSize.width - LayoutConstants.totalHorizontalPadding
        let availableHeight = maxSize.height - LayoutConstants.totalVerticalSpace
        
        // If image fits within available space, no scaling needed (keep at actual size)
        if imagePixelSize.width <= availableWidth && imagePixelSize.height <= availableHeight {
            return 1.0
        }
        
        // Only scale down if image is larger than available space
        let widthScale = availableWidth / imagePixelSize.width
        let heightScale = availableHeight / imagePixelSize.height
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
    
    // Resize the window to the specified size with completion callback
    func resizeWindow(to size: CGSize, completion: @escaping () -> Void) {
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
                
                // Call completion on the next run loop cycle to ensure frame is set
                DispatchQueue.main.async {
                    completion()
                }
            } else {
                // If no window found, still call completion to avoid hanging
                completion()
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
                            
                            // Set initial window size only if no pasteboard content
                            if NSPasteboard.getImage() == nil {
                                WindowSizeManager.shared.setInitialWindowSize()
                            }
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
