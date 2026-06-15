//
//  AppDelegate.swift
//  capturescu
//
//  Registers the global capture hotkey at launch and owns the flow controller.
//  Hooked into the SwiftUI app via @NSApplicationDelegateAdaptor.
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let flowController = ScreenCaptureFlowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Meh+G — capture a new region.
        HotKeyCenter.shared.register(
            id: 1,
            keyCode: CaptureHotKey.keyCode,
            modifiers: CaptureHotKey.modifiers
        ) { [weak self] in
            // Carbon delivers on the main thread; hop onto the main actor to
            // touch the @MainActor flow controller.
            Task { @MainActor in self?.flowController.beginCapture() }
        }
    }
}
