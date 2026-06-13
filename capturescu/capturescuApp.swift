//
//  capturescuApp.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import SwiftUI

@main
struct capturescuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let selectionManager = ToolsManager()
    private let markersManager = MarkersManager()
    private let keyboardManager = KeyboardManager.shared
    private let historyManager = HistoryManager.shared
    private let eventManager: EventManager
    
    init() {
        // Set up undo/redo notification for tools
        markersManager.setupUndoRedoNotification(toolsManager: selectionManager)
        
        // Create EventManager with the shared instances
        eventManager = EventManager(
            markersManager: markersManager,
            toolsManager: selectionManager
        )
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
                    .environmentObject(eventManager)
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
                
                Button("Selection Tool") {
                    keyboardManager.trigger(command: .selectSelectionTool)
                }
                .keyboardShortcut("s", modifiers: [])
            }
            
            CommandGroup(after: .textEditing) {
                Button("Delete Marker") {
                    keyboardManager.trigger(command: .deleteMarker)
                }
                .keyboardShortcut(.delete, modifiers: [])
            }

            CommandMenu("Capture") {
                Button("Capture Region") {
                    appDelegate.flowController.beginCapture()
                }
                // Meh+G (⌃⌥⇧G) — also available system-wide via the global hotkey.
                .keyboardShortcut("g", modifiers: [.control, .option, .shift])
            }
        }
    }
}
