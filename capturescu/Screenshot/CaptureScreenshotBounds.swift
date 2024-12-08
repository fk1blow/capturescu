//
//  CapturedScreenshotBounds.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct CaptureScreenshotBounds {
    var bounds = CGRect()
    
    var size: CGSize {
        return CGSize(width: bounds.width, height: bounds.height)
    }
    
    var position: CGPoint {
        return CGPoint(x: bounds.minX + (bounds.width / 2), y: bounds.minY + (bounds.height / 2))
    }
    
    // init(bounds: CGRect[]) {
    //
    // }
    
    init(paths: [Path], capturedImage: CapturedPasteboardImage?) {
        self.bounds = calculate(paths: paths, capturedImage: capturedImage)
    }
   
    private func calculate(paths: [Path], capturedImage: CapturedPasteboardImage?) -> CGRect {
        var minX: CGFloat = 0
        var minY: CGFloat = 0
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0
       
        // first it needs to get the bounds of the annotations
        
        if let minXFound = paths.map({ $0.boundingRect.minX }).min() {
            minX = minXFound
        }
        if let minYFound = paths.map({ $0.boundingRect.minY }).min() {
            minY = minYFound
        }
        if let maxXFound = paths.map({ $0.boundingRect.maxX }).max() {
            maxX = maxXFound
        }
        if let maxYFound = paths.map({ $0.boundingRect.maxY }).max() {
            maxY = maxYFound
        }
        
        // if theres an image but the paths min/max values are 0
        // then the min/max values should be the same as image's
        if minX + maxX + minY + maxY == 0 && capturedImage != nil {
            minX = capturedImage!.position.x
            maxX = capturedImage!.position.x + Double(capturedImage!.image.width)
            minY = capturedImage!.position.y
            maxY = capturedImage!.position.y + Double(capturedImage!.image.height)
        }
        
        // if theres a captured image, then it needs to be taken into account
        // when calculating the position of the annotation bounds,
        // alongisde the annotations themselves
        
        if capturedImage != nil {
            let capturedImagePositionX = capturedImage!.position.x
            let capturedImagePositionY = capturedImage!.position.y
            let capturedImageWidth = capturedImage!.image.width
            let capturedImageHeight = capturedImage!.image.height
            
            if minY > capturedImagePositionY {
                minY = capturedImagePositionY
            }
            if maxY < capturedImagePositionY + CGFloat(capturedImageHeight) {
                maxY = capturedImagePositionY + CGFloat(capturedImageHeight)
            }
            if minX > capturedImagePositionX {
                minX = capturedImagePositionX
            }
            if maxX < capturedImagePositionX + CGFloat(capturedImageWidth) {
                maxX = capturedImagePositionX + CGFloat(capturedImageWidth)
            }
        }
        
        // add an offset/padding to the bounds
        let additionalPadding = 20.0
        let additionalOffset = 10.0
        let width = maxX - minX + additionalPadding
        let height = maxY - minY + additionalPadding
        
        return CGRect(
            x: minX - additionalOffset,
            y: minY - additionalOffset,
            width: width,
            height: height
        )
    }
}
