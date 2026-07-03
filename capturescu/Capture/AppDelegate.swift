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

    // Strong ref so the menu-bar item isn't deallocated.
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

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

    // MARK: - Menu bar item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Template image: monochrome, so macOS tints it to match the menu bar
        // (dark glyph on light bars, light glyph on dark bars) automatically.
        let icon = NSImage(named: "MenuBarIcon")
        icon?.isTemplate = true
        icon?.accessibilityDescription = "Capturescu"
        item.button?.image = icon
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        // Deliver both click types so we can branch on left vs right.
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent, let button = statusItem?.button else { return }

        if event.type == .rightMouseUp {
            // Pop the menu manually rather than assigning `statusItem.menu`,
            // which would make every click (including left) open the menu.
            let menu = makeStatusMenu()
            menu.popUp(positioning: nil,
                       at: NSPoint(x: 0, y: button.bounds.height + 4),
                       in: button)
        } else {
            flowController.beginCapture()
        }
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        let capture = NSMenuItem(title: "Capture Region",
                                 action: #selector(captureRegion),
                                 keyEquivalent: "")
        capture.target = self
        menu.addItem(capture)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Capturescu",
                              action: #selector(quit),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func captureRegion() {
        flowController.beginCapture()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
