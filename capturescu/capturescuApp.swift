//
//  capturescuApp.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import AppKit
import SwiftUI

@main
struct capturescuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar-only app: no main window, no Dock icon (LSUIElement). The
        // capture flow runs entirely from the global hotkey (Meh+G) and these
        // menu items.
        MenuBarExtra("Capturescu", systemImage: "scissors") {
            Button("Capture Region") {
                appDelegate.flowController.beginCapture()
            }

            Divider()

            Button("Quit Capturescu") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
