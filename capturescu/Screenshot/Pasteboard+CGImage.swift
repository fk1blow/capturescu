//
//  Pasteboard+NSImage.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import AppKit
import Foundation
import UniformTypeIdentifiers

extension NSPasteboard {
    static func getImage() -> (image: CGImage, isCapturescuRendered: Bool)? {
        let pasteboard = NSPasteboard.general
        
        // Try PNG first (where we store our metadata)
        if let data = pasteboard.data(forType: .png), !data.isEmpty {
            // Validate data size to prevent processing corrupt/malformed images
            guard data.count > 0 && data.count < 100_000_000 else { // 100MB limit
                return nil
            }
            
            if let source = CGImageSourceCreateWithData(data as CFData, nil),
               CGImageSourceGetCount(source) > 0 {
                if let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                    // Validate image dimensions to prevent processing invalid images
                    guard image.width > 0 && image.height > 0 &&
                          image.width <= 32768 && image.height <= 32768 else {
                        return nil
                    }
                    
                    print("DEBUG DETECTION: No scaling approach - using image exactly as-is (\(image.width)x\(image.height))")
                    
                    // NO-SCALING APPROACH: Always use image exactly as pasted, no modifications
                    return (image: image, isCapturescuRendered: false)
                }
            }
        }
        
        // Fall back to TIFF
        if let data = pasteboard.data(forType: .tiff), !data.isEmpty {
            // Validate data size to prevent processing corrupt/malformed images
            guard data.count > 0 && data.count < 100_000_000 else { // 100MB limit
                return nil
            }
            
            if let source = CGImageSourceCreateWithData(data as CFData, nil),
               CGImageSourceGetCount(source) > 0 {
                if let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                    // Validate image dimensions to prevent processing invalid images
                    guard image.width > 0 && image.height > 0 &&
                          image.width <= 32768 && image.height <= 32768 else {
                        return nil
                    }
                    
                    print("DEBUG DETECTION (TIFF): No scaling approach - using image exactly as-is (\(image.width)x\(image.height))")
                    
                    // NO-SCALING APPROACH: Always use image exactly as pasted, no modifications
                    return (image: image, isCapturescuRendered: false)
                }
            }
        }

        return nil
    }
    
    

    static func addImage(capture: CGImage?, originalImageSize: CGSize? = nil) {
        // Get the CGImage
        guard let image = capture else { return }
        
        // Validate image dimensions to prevent adding invalid images
        guard image.width > 0 && image.height > 0 &&
              image.width <= 32768 && image.height <= 32768 else {
            return
        }

        // NO-SCALING APPROACH: Store exact pixel data without modification
        // External apps will handle their own display scaling requirements
        print("DEBUG CLIPBOARD: Adding image at exact size (\(image.width)x\(image.height)) - no scaling")
        
        // Create the pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Store exact image data without any scaling or modification
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        
        // Add PNG format with original image data
        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            guard pngData.count > 0 && pngData.count < 100_000_000 else { return }
            pasteboard.setData(pngData, forType: .png)
        }
        
        // Add TIFF format for broader compatibility
        if let tiffData = bitmapRep.representation(using: .tiff, properties: [:]) {
            guard tiffData.count > 0 && tiffData.count < 100_000_000 else { return }
            pasteboard.setData(tiffData, forType: .tiff)
        }
        
    }
}
