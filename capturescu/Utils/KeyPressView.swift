//
//  KeyPressView.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct KeyPressView: NSViewRepresentable {
    var onCopy: (() -> Void)?

    @State var isCommandPressed: Bool = false

    class Coordinator: NSObject {
        var parent: KeyPressView

        init(parent: KeyPressView) {
            self.parent = parent
        }

        @objc func flagsChanged(with event: NSEvent) {
            // Handle modifier key changes (Command, Shift, etc.)
            if event.modifierFlags.contains(.command) {
                parent.isCommandPressed = true
            } else {
                parent.isCommandPressed = false
            }
        }

        @objc func keyDown(with event: NSEvent) {
            print("Key down event: \(event.keyCode)")
            
            if event.keyCode == 53 { // Escape key
                print("Esc key pressed")
            }
            if event.keyCode == 8 && parent.isCommandPressed {
                if let onCopy = parent.onCopy {
                    onCopy()
                }
            }
            // Handle the event, prevent system alert sound
        }

        @objc func keyUp(with event: NSEvent) {
            // Handle keyUp events if needed
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let nsView = CustomNSView()
        nsView.coordinator = context.coordinator

        return nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // No need to update the view
    }

    class CustomNSView: NSView {
        var coordinator: Coordinator?

        override var acceptsFirstResponder: Bool {
            return true
        }

        override func becomeFirstResponder() -> Bool {
            return true
        }

        override func resignFirstResponder() -> Bool {
            return true
        }

        override func flagsChanged(with event: NSEvent) {
            coordinator?.flagsChanged(with: event)
        }

        override func keyDown(with event: NSEvent) {
            coordinator?.keyDown(with: event)
            // Consume the event to prevent the system beep
        }

        override func keyUp(with event: NSEvent) {
            coordinator?.keyUp(with: event)
        }
    }
}
