//
//  PointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

enum PointerToolName {
    case FreehandPointer
    case LinePointer
    case ArrowPointer
    case TextPointer
}

protocol PointerTool {
    var toolName: PointerToolName { get }

    func beginMarker(at location: CGPoint)
    func updateMarker(at location: CGPoint)
    func endMarker(at location: CGPoint)

    func drawMarker(onto _: GraphicsContext)
    func clearMarker()
    func getMarker() -> Marker

    func renderAccessoryView(onDone: @escaping (_ marker: Marker) -> Void) -> AnyView
    func pointerClicked(at location: CGPoint)
}

extension PointerTool {
    func renderAccessoryView(onDone _: @escaping (_ marker: Marker) -> Void) -> AnyView {
        return AnyView(EmptyView())
    }

    func pointerClicked(at _: CGPoint) {}

    func beginMarker(at _: CGPoint) {}
    func updateMarker(at _: CGPoint) {}
    func endMarker(at _: CGPoint) {}
}
