//
//  KeyEventHandlingView.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Cocoa
import SwiftUI

class KeyEventHandlingView: NSView {
    var pasteAction: (() -> Void)?
    var copyAction: (() -> Void)?
    var keyPressAction: ((_ chars: String, _ keyCode: UInt16) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.characters == "v" {
            pasteAction?()
        } else if event.modifierFlags.contains(.command), event.characters == "c" {
            copyAction?()
        } else {
            if event.characters != nil && keyPressAction != nil {
                keyPressAction!(event.characters!, event.keyCode)
            } else {
                super.keyDown(with: event)
            }
        }
    }
}

struct KeyEventHandlingViewRepresentable: NSViewRepresentable {
    var pasteAction: (() -> Void)?
    var copyAction: (() -> Void)?
    var keyPressAction: ((_ chars: String, _ keyCode: UInt16) -> Void)?

    func makeNSView(context: Context) -> KeyEventHandlingView {
        let view = KeyEventHandlingView()
        view.pasteAction = pasteAction
        view.copyAction = copyAction
        view.keyPressAction = keyPressAction
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyEventHandlingView, context: Context) {
        nsView.pasteAction = pasteAction
        nsView.copyAction = copyAction
        nsView.keyPressAction = keyPressAction
    }
}
