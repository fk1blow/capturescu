//
//  RegionSelectionController.swift
//  capturescu
//
//  Owns the borderless, screen-saver-level overlay window used for dragging
//  out a capture region.
//

import AppKit
import SwiftUI

@MainActor
final class RegionSelectionController {
    private var window: NSWindow?
    private let onComplete: (CGRect) -> Void
    private let onCancel: () -> Void

    init(onComplete: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    func show(image: CGImage, scale: CGFloat, screenFrame: CGRect) {
        let view = RegionSelectionView(
            image: image,
            scale: scale,
            onComplete: { [weak self] rect in self?.onComplete(rect) },
            onCancel: { [weak self] in self?.onCancel() }
        )

        let window = KeyableBorderlessWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = NSHostingView(rootView: view)
        window.setFrame(screenFrame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.set()

        self.window = window
    }

    func close() {
        NSCursor.arrow.set()
        window?.orderOut(nil)
        window = nil
    }
}
