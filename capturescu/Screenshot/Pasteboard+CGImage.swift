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
        if let data = pasteboard.data(forType: .png) {
            if let source = CGImageSourceCreateWithData(data as CFData, nil) {
                if let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                    // Use both metadata and heuristic detection
                    let metadataDetection = checkCapturescuMetadata(source: source)
                    let heuristicDetection = detectCapturescuImageHeuristic(image: image)
                    let isCapturescuRendered = metadataDetection || heuristicDetection
                    
                    print("🔍 Image detection:")
                    print("  • Metadata detection: \(metadataDetection)")
                    print("  • Heuristic detection: \(heuristicDetection)")
                    print("  • Final result: \(isCapturescuRendered)")
                    
                    return (image: image, isCapturescuRendered: isCapturescuRendered)
                }
            }
        }
        
        // Fall back to TIFF
        if let data = pasteboard.data(forType: .tiff) {
            if let source = CGImageSourceCreateWithData(data as CFData, nil) {
                if let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                    // Use heuristic detection for TIFF images
                    let heuristicDetection = detectCapturescuImageHeuristic(image: image)
                    
                    print("🔍 Image detection (TIFF):")
                    print("  • Heuristic detection: \(heuristicDetection)")
                    
                    return (image: image, isCapturescuRendered: heuristicDetection)
                }
            }
        }

        return nil
    }
    
    private static func checkCapturescuMetadata(source: CGImageSource) -> Bool {
        // Get image properties
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return false
        }
        
        // Check for our custom metadata marker
        if let customProperties = properties["capturescu-rendered"] as? String {
            return customProperties == "true"
        }
        
        return false
    }
    
    private static func detectCapturescuImageHeuristic(image: CGImage) -> Bool {
        let width = image.width
        let height = image.height
        
        // Heuristic 1: Check for common screenshot dimensions
        // Most screenshots have dimensions that are multiples of common screen resolutions
        let commonScreenWidths = [1280, 1440, 1920, 2560, 3840] // Common screen widths
        let commonScreenHeights = [720, 900, 1080, 1440, 2160] // Common screen heights
        
        let isLikelyScreenshot = commonScreenWidths.contains(width) || commonScreenHeights.contains(height)
        
        // Heuristic 2: Check aspect ratio
        // Screenshots typically have standard aspect ratios (16:9, 16:10, 4:3)
        let aspectRatio = Double(width) / Double(height)
        let commonAspectRatios = [16.0/9.0, 16.0/10.0, 4.0/3.0, 21.0/9.0] // Common screen aspect ratios
        
        let isCommonAspectRatio = commonAspectRatios.contains { abs($0 - aspectRatio) < 0.1 }
        
        // Heuristic 3: Size analysis
        // Capturescu-rendered images are typically smaller than full screenshots
        // and often have irregular dimensions due to bounding box cropping
        let isSmallSize = width < 1000 && height < 1000
        let hasIrregularDimensions = !isLikelyScreenshot && !isCommonAspectRatio
        
        // Heuristic 4: Check for typical Capturescu output characteristics
        // Images from Capturescu are often cropped and have non-standard dimensions
        let isLikelyCapturescuSize = isSmallSize && hasIrregularDimensions
        
        // Final decision: If it doesn't look like a standard screenshot, it's likely from Capturescu
        let isCapturescuRendered = !isLikelyScreenshot || isLikelyCapturescuSize
        
        // Debug logging
        print("  • Image dimensions: \(width) × \(height)")
        print("  • Aspect ratio: \(String(format: "%.2f", aspectRatio))")
        print("  • Likely screenshot: \(isLikelyScreenshot)")
        print("  • Common aspect ratio: \(isCommonAspectRatio)")
        print("  • Small size: \(isSmallSize)")
        print("  • Irregular dimensions: \(hasIrregularDimensions)")
        
        return isCapturescuRendered
    }
    
    private static func addMetadataToPNG(_ pngData: Data) -> Data? {
        // Create a CGImage from the PNG data
        guard let dataProvider = CGDataProvider(data: pngData as CFData),
              let cgImage = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            return nil
        }
        
        // Create a new image with metadata
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        
        // Add metadata properties
        let metadata: [String: Any] = [
            "capturescu-rendered": "true"
        ]
        
        // Add the image with metadata
        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        
        // Finalize the destination
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
    }

    static func addImage(capture: CGImage?) {
        // Get the CGImage
        guard let image = capture else { return }

        // Create a bitmap representation from the CGImage
        let bitmapRep = NSBitmapImageRep(cgImage: image)

        // Create the pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Add PNG format with simple metadata marker
        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            // Add metadata by creating a new image with metadata
            if let modifiedPngData = addMetadataToPNG(pngData) {
                pasteboard.setData(modifiedPngData, forType: .png)
            } else {
                // Fallback to original data if metadata addition fails
                pasteboard.setData(pngData, forType: .png)
            }
        }
        
        // Add TIFF format for metadata preservation and professional app compatibility
        if let tiffData = bitmapRep.representation(using: .tiff, properties: [:]) {
            pasteboard.setData(tiffData, forType: .tiff)
        }
    }
}
