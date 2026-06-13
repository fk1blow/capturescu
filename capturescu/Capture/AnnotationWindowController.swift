//
//  AnnotationWindowController.swift
//  capturescu
//
//  Owns the two windows that make up the in-place annotation experience:
//   1. a borderless window positioned exactly over the captured region,
//      hosting the reused DrawingSurfaceView, and
//   2. a separate floating toolbar panel anchored just below it.
//
//  Both windows share one fresh set of managers so the annotation flow is
//  fully independent of the app's main window.
//

import AppKit
import SwiftUI

@MainActor
final class AnnotationWindowController {
    private var annotationWindow: NSWindow?
    private var toolbarPanel: NSPanel?
    private var onClose: (() -> Void)?

    // Fresh state, independent of the main window.
    private let toolsManager = ToolsManager()
    private let markersManager = MarkersManager()
    private var eventManager: EventManager!
    private var capturedImage: CapturedPasteboardImage!

    private let toolbarSize = CGSize(width: 280, height: 58)
    private let toolbarGap: CGFloat = 12

    func present(image: CGImage, scale: CGFloat, at frame: CGRect, onClose: @escaping () -> Void) {
        self.onClose = onClose

        // Wire up the managers exactly like capturescuApp does.
        markersManager.setupUndoRedoNotification(toolsManager: toolsManager)
        eventManager = EventManager(markersManager: markersManager, toolsManager: toolsManager)
        toolsManager.selectTool(named: .FreehandPointer) // default to draw mode

        capturedImage = CapturedPasteboardImage(
            image: image,
            position: .zero,
            scale: 1.0 / scale,
            hiDPIScale: 1.0 / scale,
            originalPNGData: nil
        )

        presentAnnotationWindow(at: frame)
        presentToolbar(below: frame)
    }

    // MARK: - Windows

    private func presentAnnotationWindow(at frame: CGRect) {
        let view = CaptureAnnotationView(capturedImage: capturedImage)
            .environmentObject(toolsManager)
            .environmentObject(markersManager)
            .environmentObject(eventManager)

        let window = KeyableBorderlessWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: view)
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        annotationWindow = window
    }

    private func presentToolbar(below frame: CGRect) {
        let toolbarFrame = toolbarFrame(for: frame)

        let view = MiniToolbarView(
            copyAction: { [weak self] in self?.copyToClipboard() },
            closeAction: { [weak self] in self?.close() }
        )
        .environmentObject(toolsManager)
        .environmentObject(markersManager)
        .environmentObject(eventManager)

        let panel = NSPanel(
            contentRect: toolbarFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: view)
        panel.setFrame(toolbarFrame, display: true)
        panel.orderFront(nil)

        toolbarPanel = panel
    }

    /// Centre the toolbar just below the region, flipping above and clamping to
    /// the screen when there isn't room.
    private func toolbarFrame(for frame: CGRect) -> CGRect {
        var originX = frame.midX - toolbarSize.width / 2
        var originY = frame.minY - toolbarSize.height - toolbarGap // below (AppKit: lower Y)

        let visible = (annotationWindow?.screen ?? NSScreen.main)?.frame ?? frame
        if originY < visible.minY + 8 {
            originY = frame.maxY + toolbarGap // not enough room below → place above
        }
        originX = min(max(originX, visible.minX + 8), visible.maxX - toolbarSize.width - 8)

        return CGRect(origin: CGPoint(x: originX, y: originY), size: toolbarSize)
    }

    // MARK: - Actions

    private func copyToClipboard() {
        let pngData = CGContextRenderer.renderWithMarkers(
            image: capturedImage.image,
            markers: markersManager.markers,
            bounds: CGRect(origin: .zero, size: capturedImage.naturalSize),
            imagePosition: .zero,
            imageSize: capturedImage.naturalSize,
            hiDPIScale: capturedImage.hiDPIScale
        )
        if let pngData {
            NSPasteboard.addImageData(pngData)
        }
    }

    func close() {
        toolbarPanel?.orderOut(nil)
        toolbarPanel = nil
        annotationWindow?.orderOut(nil)
        annotationWindow = nil
        onClose?()
        onClose = nil
    }
}
