//
//  Pasteboard+NSImage.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import AppKit
import Foundation

extension NSPasteboard {
    static func getImage() -> CGImage? {
        let pasteboard = NSPasteboard.general
        // if let imageData = pasteboard.data(forType: .tiff) {
        //     return NSImage(data: imageData)
        // }
        // return nil
        if let data = pasteboard.data(forType: .tiff) {
            // Convert TIFF data to CGImage directly
            if let source = CGImageSourceCreateWithData(data as CFData, nil) {
                return CGImageSourceCreateImageAtIndex(source, 0, nil)
            }
        }

        return nil
    }

    static func addImage(capture: CGImage?) {
        // Get the CGImage
        guard let image = capture else { return }

        // Create a bitmap representation from the CGImage
        let bitmapRep = NSBitmapImageRep(cgImage: image)

        // Convert the bitmap representation to PNG format
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }

        // Create the pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Write the PNG data to the pasteboard
        pasteboard.setData(pngData, forType: .png)
    }
}
