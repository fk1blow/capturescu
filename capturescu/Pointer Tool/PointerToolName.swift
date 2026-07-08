//
//  PointerToolName.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation

/// Enum representing different pointer tool types
enum PointerToolName: String {
    case FreehandPointer
    case ArrowPointer
    case LinePointer
    case TextPointer
    case SelectionPointer
    case HandPointer

    /// Tools that create markers — the only ones sensible as an open-default.
    /// Hand (⌘-pan) and Selection are transient: a fresh capture has nothing to
    /// pan and no markers to select, so they never become the remembered default.
    var isPersistableDefault: Bool {
        switch self {
        case .FreehandPointer, .ArrowPointer, .LinePointer, .TextPointer: return true
        case .SelectionPointer, .HandPointer: return false
        }
    }
}