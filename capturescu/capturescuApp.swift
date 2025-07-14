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
    private let historyManager = HistoryManager.shared
    
    init() {
        // Set up undo/redo notification for tools
        markersManager.setupUndoRedoNotification(toolsManager: selectionManager)
    }

    var body: some Scene {
        WindowGroup {
            // don't want to receive multiple events from the menu commands
            // while previewing the app in xcode
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                ContentView()
                    .environmentObject(selectionManager)
                    .environmentObject(markersManager)
                    .environmentObject(historyManager)
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
            
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    keyboardManager.trigger(command: .undo)
                }
                .keyboardShortcut("z", modifiers: .command)
                
                Button("Redo") {
                    keyboardManager.trigger(command: .redo)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            
            CommandMenu("Tools") {
                Button("Arrow Tool") {
                    keyboardManager.trigger(command: .selectArrowTool)
                }
                .keyboardShortcut("a", modifiers: [])
                
                Button("Freehand Tool") {
                    keyboardManager.trigger(command: .selectFreehandTool)
                }
                .keyboardShortcut("f", modifiers: [])
                
                Button("Line Tool") {
                    keyboardManager.trigger(command: .selectLineTool)
                }
                .keyboardShortcut("l", modifiers: [])
                
                Button("Text Tool") {
                    keyboardManager.trigger(command: .selectTextTool)
                }
                .keyboardShortcut("t", modifiers: [])
            }
            
            CommandGroup(after: .textEditing) {
                Button("Delete Marker") {
                    keyboardManager.trigger(command: .deleteMarker)
                }
                .keyboardShortcut(.delete, modifiers: [])
            }
        }
    }
}
