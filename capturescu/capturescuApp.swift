//
//  capturescuApp.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import SwiftUI

@main
struct capturescuApp: App {
    private let selectionManager = ToolsManager()
    private let markersManager = MarkersManager()
    private let keyboardManager = KeyboardManager.shared

    var body: some Scene {
        WindowGroup {
            // don't want to receive multiple events from the menu commands
            // while previewing the app in xcode
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                ContentView()
                    .environmentObject(selectionManager)
                    .environmentObject(markersManager)
                    .customWindowStyle()
            }
        }
        .commands {
            CommandGroup(replacing: .pasteboard) {
                Button("Copy") {
                    keyboardManager.trigger(command: .copy)
                }
                .keyboardShortcut("c", modifiers: .command)

                Button("Paste") {
                    keyboardManager.trigger(command: .paste)
                }
                .keyboardShortcut("v", modifiers: .command)
            }
        }
    }
}
