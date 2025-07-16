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
                    
                    // Use both metadata and heuristic detection
                    let metadataDetection = checkCapturescuMetadata(source: source)
                    let heuristicDetection = false // Disable heuristic to rely on metadata for quality preservation
                    let isCapturescuRendered = metadataDetection || heuristicDetection
                    
                    print("DEBUG DETECTION: No scaling approach - using image exactly as-is (\(image.width)x\(image.height))")
                    
                    // NO-SCALING APPROACH: Always use image exactly as pasted, no modifications
                    let finalImage = image
                    
                    return (image: finalImage, isCapturescuRendered: isCapturescuRendered)
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
                    
                    // Use heuristic detection for TIFF images with metadata fallback
                    let metadataDetection = checkCapturescuMetadata(source: source)
                    let heuristicDetection = false // Disable heuristic to rely on metadata for quality preservation
                    let isCapturescuRendered = metadataDetection || heuristicDetection
                    
                    print("DEBUG DETECTION (TIFF): No scaling approach - using image exactly as-is (\(image.width)x\(image.height))")
                    
                    // NO-SCALING APPROACH: Always use image exactly as pasted, no modifications
                    let finalImage = image
                    
                    return (image: finalImage, isCapturescuRendered: isCapturescuRendered)
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
        
        // Check for TIFF metadata with Capturescu markers
        if let tiffProperties = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            // Check for software marker
            if let software = tiffProperties[kCGImagePropertyTIFFSoftware as String] as? String,
               software == "Capturescu" {
                return true
            }
            
            // Check for image description marker
            if let description = tiffProperties[kCGImagePropertyTIFFImageDescription as String] as? String,
               description == "capturescu-rendered" {
                return true
            }
            
            // Check for bundle identifier marker (strongest source detection)
            if let artist = tiffProperties[kCGImagePropertyTIFFArtist as String] as? String,
               (artist == Bundle.main.bundleIdentifier || artist == "com.dragostudorache.capturescu") {
                return true
            }
        }
        
        return false
    }
    
    private static func restoreOriginalSizeWithoutScaling(image: CGImage, source: CGImageSource) -> CGImage {
        // Get image properties to check for original size metadata
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return image
        }
        
        // Check for TIFF metadata with original size information
        if let tiffProperties = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
           let documentName = tiffProperties[kCGImagePropertyTIFFDocumentName as String] as? String,
           documentName.hasPrefix("original-size:") {
            
            // Parse the original dimensions from the document name
            let sizeString = String(documentName.dropFirst("original-size:".count))
            let components = sizeString.components(separatedBy: "x")
            
            if components.count == 2,
               let originalWidth = Int(components[0]),
               let originalHeight = Int(components[1]) {
                
                print("DEBUG RESTORE: currentSize=(\(image.width)x\(image.height)), originalFromMetadata=(\(originalWidth)x\(originalHeight))")
                
                // If the image is already the correct size, return it as-is to preserve quality
                if image.width == originalWidth && image.height == originalHeight {
                    print("DEBUG RESTORE: Image already correct size, returning as-is (quality preserved)")
                    return image
                }
                
                // Only scale if absolutely necessary and different sizes
                print("DEBUG RESTORE: Scaling needed from (\(image.width)x\(image.height)) to (\(originalWidth)x\(originalHeight))")
                return scaleImageWithHighQuality(image: image, targetWidth: originalWidth, targetHeight: originalHeight)
            }
        }
        
        return image
    }
    
    private static func restoreOriginalSize(image: CGImage, source: CGImageSource) -> CGImage {
        // Get image properties to check for original size metadata
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return image
        }
        
        // Check for TIFF metadata with original size information
        if let tiffProperties = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
           let documentName = tiffProperties[kCGImagePropertyTIFFDocumentName as String] as? String,
           documentName.hasPrefix("original-size:") {
            
            // Parse the original dimensions from the document name
            let sizeString = String(documentName.dropFirst("original-size:".count))
            let components = sizeString.components(separatedBy: "x")
            
            if components.count == 2,
               let originalWidth = Int(components[0]),
               let originalHeight = Int(components[1]) {
                
                // The metadata contains the ACTUAL original image size (e.g., 200x200)
                // The clipboard image was rendered at 1x scale, so we need to restore it to the correct display size
                // For Capturescu internal operations, we want to preserve the original image dimensions in screen points
                let screenScale = NSScreen.main?.backingScaleFactor ?? 1.0
                
                // The original size is in pixels, we need to convert to points for display
                // For a 200x200 pixel image on a 2x display, we want 100x100 points but we store 200x200 in metadata
                // So when we read it back, we keep the metadata size as the target size
                let targetWidth = originalWidth  // Keep original pixel dimensions
                let targetHeight = originalHeight // Keep original pixel dimensions
                
                print("DEBUG RESTORE: currentSize=(\(image.width)x\(image.height)), originalFromMetadata=(\(originalWidth)x\(originalHeight)), target=(\(targetWidth)x\(targetHeight))")
                
                print("DEBUG RESTORE: Checking if scaling needed: target(\(targetWidth)x\(targetHeight)) vs current(\(image.width)x\(image.height))")
                
                // Only scale if the target size is different from current size
                if targetWidth != image.width || targetHeight != image.height {
                    print("DEBUG RESTORE: Scaling needed, creating new image...")
                    // Create a new image scaled to the target size
                    print("DEBUG RESTORE: Creating context with width=\(targetWidth), height=\(targetHeight), bitsPerComponent=\(image.bitsPerComponent), bitmapInfo=\(image.bitmapInfo.rawValue)")
                    
                    // Use a standard bitmap configuration that's guaranteed to work
                    let bitmapInfo: CGBitmapInfo = [.byteOrder32Big, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]
                    
                    guard let context = CGContext(
                        data: nil,
                        width: targetWidth,
                        height: targetHeight,
                        bitsPerComponent: 8,  // Force 8 bits per component
                        bytesPerRow: 0,       // Auto-calculate
                        space: CGColorSpaceCreateDeviceRGB(),  // Use standard RGB color space
                        bitmapInfo: bitmapInfo.rawValue
                    ) else {
                        print("DEBUG RESTORE: Failed to create CGContext with standard config!")
                        return image
                    }
                    
                    print("DEBUG RESTORE: CGContext created successfully")
                    
                    // Draw the smaller image into the larger context to scale it up
                    context.interpolationQuality = .high
                    context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
                    
                    if let scaledImage = context.makeImage() {
                        print("DEBUG RESTORE: Successfully scaled to (\(scaledImage.width)x\(scaledImage.height))")
                        return scaledImage
                    } else {
                        print("DEBUG RESTORE: Failed to create scaled image")
                        return image
                    }
                } else {
                    print("DEBUG RESTORE: No scaling needed - sizes are the same")
                }
            }
        }
        
        return image
    }
    
    private static func restoreFromExternalApp(image: CGImage) -> CGImage {
        // When an external app strips our metadata, we need to scale up by screen factor
        // since the external app gave us back a scaled-down version
        let screenScale = NSScreen.main?.backingScaleFactor ?? 1.0
        let targetWidth = Int(CGFloat(image.width) * screenScale)
        let targetHeight = Int(CGFloat(image.height) * screenScale)
        
        print("DEBUG EXTERNAL RESTORE: Scaling (\(image.width)x\(image.height)) to (\(targetWidth)x\(targetHeight)) by screenScale=\(screenScale)")
        
        // Use the same standard bitmap configuration
        let bitmapInfo: CGBitmapInfo = [.byteOrder32Big, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]
        
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            print("DEBUG EXTERNAL RESTORE: Failed to create CGContext")
            return image
        }
        
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        
        if let scaledImage = context.makeImage() {
            print("DEBUG EXTERNAL RESTORE: Successfully scaled to (\(scaledImage.width)x\(scaledImage.height))")
            return scaledImage
        } else {
            print("DEBUG EXTERNAL RESTORE: Failed to create scaled image")
            return image
        }
    }
    
    private static func detectCapturescuImageHeuristic(image: CGImage) -> Bool {
        let width = image.width
        let height = image.height
        
        // Validate input dimensions to prevent edge cases
        guard width > 0 && height > 0 else {
            return false
        }
        
        // Heuristic 1: Check for common screenshot dimensions and their multiples
        // Most screenshots have dimensions that are multiples of common screen resolutions
        let commonScreenWidths = [1280, 1440, 1680, 1920, 2560, 3440, 3840] // Common screen widths including ultrawide
        let commonScreenHeights = [720, 900, 1050, 1080, 1440, 1800, 2160] // Common screen heights
        
        // Check for exact matches or common multiples (for HiDPI screens)
        let isExactScreenWidth = commonScreenWidths.contains(width)
        let isExactScreenHeight = commonScreenHeights.contains(height)
        let isHiDPIWidth = commonScreenWidths.contains { width == $0 * 2 }
        let isHiDPIHeight = commonScreenHeights.contains { height == $0 * 2 }
        
        let isLikelyScreenshot = isExactScreenWidth || isExactScreenHeight || isHiDPIWidth || isHiDPIHeight
        
        // Heuristic 2: Enhanced aspect ratio detection
        // Screenshots typically have standard aspect ratios (16:9, 16:10, 4:3, 21:9)
        guard height > 0 else {
            return false
        }
        
        let aspectRatio = Double(width) / Double(height)
        let commonAspectRatios = [
            16.0/9.0,   // 1.777... (most common)
            16.0/10.0,  // 1.6 (MacBook Pro)
            4.0/3.0,    // 1.333... (older screens)
            21.0/9.0,   // 2.333... (ultrawide)
            3.0/2.0,    // 1.5 (Surface devices)
            5.0/4.0     // 1.25 (some tablets)
        ]
        
        let isCommonAspectRatio = commonAspectRatios.contains { abs($0 - aspectRatio) < 0.05 }
        
        // Heuristic 3: Size analysis with improved thresholds
        // Capturescu-rendered images are typically smaller due to bounding box cropping
        let isSmallSize = width < 1200 && height < 1200  // Increased threshold for larger screens
        let isMediumSize = width < 2000 && height < 2000
        let isVeryLargeSize = width > 4000 || height > 4000
        
        // Heuristic 4: Dimension pattern analysis
        // Capturescu images often have irregular dimensions due to content-based cropping
        let hasIrregularDimensions = !isLikelyScreenshot && !isCommonAspectRatio
        
        // Check for "cropped" characteristics - dimensions that don't align with screen standards
        let widthMod = width % 16  // Most screen widths are multiples of 16
        let heightMod = height % 16
        let hasNonStandardDimensions = (widthMod != 0 || heightMod != 0) && !isVeryLargeSize
        
        // Heuristic 5: Combined size and aspect ratio analysis
        // Screenshots from Capturescu are often cropped and have non-standard dimensions
        let isLikelyCapturescuSize = (isSmallSize && hasIrregularDimensions) || 
                                   (isMediumSize && hasNonStandardDimensions && !isCommonAspectRatio)
        
        // Final decision with improved logic
        // If it matches standard screenshot characteristics, it's likely NOT from Capturescu
        // If it has irregular dimensions and non-standard size, it's likely FROM Capturescu
        let isCapturescuRendered = !isLikelyScreenshot || isLikelyCapturescuSize
        
        return isCapturescuRendered
    }
    
    private static func addMetadataToPNG(_ pngData: Data) -> Data? {
        // Create a CGImage from the PNG data
        guard let dataProvider = CGDataProvider(data: pngData as CFData),
              let cgImage = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            return nil
        }
        
        // Create a new image with metadata using TIFF metadata dictionary
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        
        // Add metadata in TIFF dictionary format (more reliable)
        let metadata: [String: Any] = [
            kCGImagePropertyTIFFDictionary as String: [
                kCGImagePropertyTIFFSoftware as String: "Capturescu",
                kCGImagePropertyTIFFImageDescription as String: "capturescu-rendered"
            ]
        ]
        
        // Add the image with metadata
        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        
        // Finalize the destination
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
    }
    
    private static func scaleImageWithHighQuality(image: CGImage, targetWidth: Int, targetHeight: Int) -> CGImage {
        print("DEBUG HIGH QUALITY SCALE: Scaling (\(image.width)x\(image.height)) to (\(targetWidth)x\(targetHeight))")
        
        // Use the highest quality bitmap configuration to minimize quality loss
        let bitmapInfo: CGBitmapInfo = [.byteOrder32Big, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]
        
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            print("DEBUG HIGH QUALITY SCALE: Failed to create CGContext, using original")
            return image
        }
        
        // Use the highest quality interpolation to minimize artifacts
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        
        if let scaledImage = context.makeImage() {
            print("DEBUG HIGH QUALITY SCALE: Successfully scaled to (\(scaledImage.width)x\(scaledImage.height))")
            return scaledImage
        } else {
            print("DEBUG HIGH QUALITY SCALE: Failed to create scaled image, using original")
            return image
        }
    }
    
    private static func scaleImageForExternalApps(_ image: CGImage, screenScale: CGFloat) -> CGImage {
        // Scale down the image for external apps to prevent 2x larger display
        let targetWidth = Int(CGFloat(image.width) / screenScale)
        let targetHeight = Int(CGFloat(image.height) / screenScale)
        
        print("DEBUG EXTERNAL SCALE: Scaling (\(image.width)x\(image.height)) to (\(targetWidth)x\(targetHeight)) by 1/\(screenScale)")
        
        // Use standard bitmap configuration
        let bitmapInfo: CGBitmapInfo = [.byteOrder32Big, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]
        
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            print("DEBUG EXTERNAL SCALE: Failed to create CGContext, using original")
            return image
        }
        
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        
        if let scaledImage = context.makeImage() {
            print("DEBUG EXTERNAL SCALE: Successfully scaled to (\(scaledImage.width)x\(scaledImage.height))")
            return scaledImage
        } else {
            print("DEBUG EXTERNAL SCALE: Failed to create scaled image, using original")
            return image
        }
    }
    
    private static func addMetadataWithActualOriginalSize(_ pngData: Data, originalImageSize: CGSize) -> Data? {
        // Create a CGImage from the PNG data
        guard let dataProvider = CGDataProvider(data: pngData as CFData),
              let cgImage = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            return nil
        }
        
        // Create a new image with metadata including actual original dimensions
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        
        // Add metadata with ACTUAL original image dimensions and bundle identifier
        let bundleId = Bundle.main.bundleIdentifier ?? "com.dragostudorache.capturescu"
        let metadata: [String: Any] = [
            kCGImagePropertyTIFFDictionary as String: [
                kCGImagePropertyTIFFSoftware as String: "Capturescu",
                kCGImagePropertyTIFFImageDescription as String: "capturescu-rendered",
                kCGImagePropertyTIFFDocumentName as String: "original-size:\(Int(originalImageSize.width))x\(Int(originalImageSize.height))",
                kCGImagePropertyTIFFArtist as String: bundleId  // Add bundle identifier for source detection
            ]
        ]
        
        // Add the image with metadata
        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        
        // Finalize the destination
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
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
