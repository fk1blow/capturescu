//
//  FreeShape.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

@Observable class FreehandDrawTool: DrawableToolProtocol {
    var line = Line()

    func move(at location: CGPoint) {
        line = Line()
        line.points.append(location)
    }

    func draw(at location: CGPoint, modifierKeys: NSEvent.ModifierFlags? = nil) {
        line.points.append(location)
    }
}
