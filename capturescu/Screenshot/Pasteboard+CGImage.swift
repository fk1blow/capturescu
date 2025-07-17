//
//  Pasteboard+NSImage.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import AppKit
import Foundation
import UniformTypeIdentifiers
import ImageIO

// Extension to add missing pasteboard types
extension NSPasteboard.PasteboardType {
    static let jpeg = NSPasteboard.PasteboardType("public.jpeg")
    static let heic = NSPasteboard.PasteboardType("public.heic")
    static let webP = NSPasteboard.PasteboardType("public.webp")
}

extension NSPasteboard {
    static func getImage() -> (image: CGImage, isCapturescuRendered: Bool, imageSource: CGImageSource?)? {
        let pasteboard = NSPasteboard.general
        
        // Define supported image types in order of preference
        let supportedTypes: [NSPasteboard.PasteboardType] = [
            .png,    // Preferred - supports metadata well
            .tiff,   // Good compatibility
            .jpeg,   // Common format
            .heic,   // Modern format
            .webP    // Web format
        ]
        
        // Try each supported format
        for imageType in supportedTypes {
            if let data = pasteboard.data(forType: imageType), !data.isEmpty {
                // Validate data size to prevent processing corrupt/malformed images
                guard data.count > 0 && data.count < 100_000_000 else { // 100MB limit
                    continue // Try next format
                }
                
                if let source = CGImageSourceCreateWithData(data as CFData, nil),
                   CGImageSourceGetCount(source) > 0 {
                    if let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                        // Validate image dimensions to prevent processing invalid images
                        guard image.width > 0 && image.height > 0 &&
                              image.width <= 32768 && image.height <= 32768 else {
                            continue // Try next format
                        }
                        
                        let formatName = imageType.rawValue.uppercased()
                        print("DEBUG DETECTION: \(formatName) image (\(image.width)x\(image.height)) - preserving source for metadata")
                        
                        return (image: image, isCapturescuRendered: false, imageSource: source)
                    }
                }
            }
        }

        return nil
    }
    
    

    static func addImage(capture: CGImage?, originalHiDPIScale: CGFloat = 1.0) {
        // Get the CGImage
        guard let image = capture else { return }
        
        // Validate image dimensions to prevent adding invalid images
        guard image.width > 0 && image.height > 0 &&
              image.width <= 32768 && image.height <= 32768 else {
            return
        }

        // Calculate DPI to preserve HiDPI information
        let dpiValue = 72.0 / originalHiDPIScale // Convert scale back to DPI
        
        print("DEBUG CLIPBOARD: Adding image at exact size (\(image.width)x\(image.height)) with DPI=\(dpiValue)")
        
        // Create the pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Store exact image data with preserved DPI metadata
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        
        // Create properties dictionary with DPI information
        let imageProperties: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionFactor: 1.0,
            .ditherTransparency: false
        ]
        
        // Add PNG format with DPI metadata
        if let pngData = bitmapRep.representation(using: .png, properties: imageProperties) {
            guard pngData.count > 0 && pngData.count < 100_000_000 else { return }
            
            // Create mutable data for the destination
            let mutableData = NSMutableData()
            
            // Create image source from the PNG data
            if let source = CGImageSourceCreateWithData(pngData as CFData, nil),
               let destination = CGImageDestinationCreateWithData(mutableData, kUTTypePNG, 1, nil) {
                
                let metadata: [CFString: Any] = [
                    kCGImagePropertyDPIWidth: dpiValue,
                    kCGImagePropertyDPIHeight: dpiValue
                ]
                
                CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)
                if CGImageDestinationFinalize(destination) {
                    pasteboard.setData(mutableData as Data, forType: .png)
                }
            } else {
                // Fallback: store without metadata
                pasteboard.setData(pngData, forType: .png)
            }
        }
        
        // Add TIFF format for broader compatibility
        if let tiffData = bitmapRep.representation(using: .tiff, properties: imageProperties) {
            guard tiffData.count > 0 && tiffData.count < 100_000_000 else { return }
            pasteboard.setData(tiffData, forType: .tiff)
        }
        
    }
}
