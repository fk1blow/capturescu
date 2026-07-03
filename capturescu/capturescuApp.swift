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
        // menu-bar item is an AppKit NSStatusItem owned by AppDelegate so it can
        // distinguish left-click (capture immediately) from right-click (menu).
        // This empty Settings scene just satisfies the Scene builder.
        Settings { EmptyView() }
    }
}
