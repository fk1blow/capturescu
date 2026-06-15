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
    private var keyMonitor: Any?
    private var focusObserver: NSObjectProtocol?
    private var isHidden = false

    // Fresh state, independent of the main window.
    private let toolsManager = ToolsManager()
    private let markersManager = MarkersManager()
    private var eventManager: EventManager!
    private var capturedImage: CapturedPasteboardImage!

    /// The toolbar's real intrinsic size, measured per-present (fallback below).
    private var toolbarSize = CGSize(width: 280, height: 58)
    /// Gap between the toolbar's bottom edge and the window's bottom edge.
    private let toolbarInsideInset: CGFloat = 16
    /// Gap between the image's bottom edge and the toolbar's top edge.
    private let toolbarTopGap: CGFloat = 24
    /// Clearance reserved between the centered toolbar and each window edge.
    private let toolbarSidePadding: CGFloat = 120
    private let borderWidth: CGFloat = 2
    /// Smallest image region, so tiny captures stay usable (the toolbar band is
    /// added below it; width is derived from the measured toolbar — see `present`).
    private let minImageAreaHeight: CGFloat = 160
    /// Keep the window this far from the screen edges, so the dashed border is
    /// always visible and there's breathing room. Captures larger than the
    /// resulting area are shown 1:1 and panned via the hand tool.
    private let edgeMargin: CGFloat = 12

    /// - Parameters:
    ///   - imageSize: the snapshot's point size.
    ///   - imageTopLeft: where the snapshot's top-left corner should sit, in
    ///     global AppKit screen coordinates (y = the image's *top* edge).
    func present(image: CGImage, scale: CGFloat, imageSize: CGSize, imageTopLeft: CGPoint, onClose: @escaping () -> Void) {
        self.onClose = onClose

        // Wire up the managers exactly like capturescuApp does.
        markersManager.setupUndoRedoNotification(toolsManager: toolsManager)
        eventManager = EventManager(markersManager: markersManager, toolsManager: toolsManager)
        toolsManager.selectTool(named: .FreehandPointer) // default to draw mode

        // Measure the toolbar's real size so the window can fit it (env objects
        // must be wired first — the probe renders MiniToolbarView).
        toolbarSize = measureToolbarSize()

        capturedImage = CapturedPasteboardImage(
            image: image,
            position: .zero,
            scale: 1.0 / scale,
            hiDPIScale: 1.0 / scale,
            originalPNGData: nil
        )

        // The dashed border frames *only* the image region — it is the capture
        // rectangle, so nothing but the image lives inside it. The toolbar
        // normally sits in its own band *below* the border. Only when the image +
        // border + that band can't fit on screen does the image clamp to the
        // monitor and the toolbar overlap its bottom (pan to see underneath). The
        // width reserves `toolbarSidePadding` on each side so the centered toolbar
        // always spans within the window.
        let toolbarBelow = toolbarTopGap + toolbarSize.height

        // Max area for the image region (border excluded). A nil screen means we
        // can't determine a max, so don't clamp: show natural size and rely on
        // pan, and never overlap.
        let visible = visibleFrame(containing: imageTopLeft)
        let maxContent: CGSize
        if let visible {
            maxContent = CGSize(
                width: visible.width - 2 * edgeMargin - 2 * borderWidth,
                height: visible.height - 2 * edgeMargin - 2 * borderWidth
            )
        } else {
            maxContent = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        let minWidth = toolbarSize.width + 2 * toolbarSidePadding
        let contentWidth = min(max(imageSize.width, minWidth), maxContent.width)

        // Room for the band below the border? Yes → toolbar sits below it.
        // No → image fills the available height and the toolbar overlaps it.
        let fits = imageSize.height + toolbarBelow <= maxContent.height
        let imageAreaHeight: CGFloat
        let toolbarOverlaps: Bool
        if fits {
            imageAreaHeight = min(max(imageSize.height, minImageAreaHeight), maxContent.height - toolbarBelow)
            toolbarOverlaps = false
        } else {
            imageAreaHeight = min(imageSize.height, maxContent.height)
            toolbarOverlaps = true
        }

        // The window content is just the image region; the dashed border wraps it.
        let content = CGSize(width: contentWidth, height: imageAreaHeight)
        let windowSize = CGSize(
            width: content.width + 2 * borderWidth,
            height: content.height + 2 * borderWidth
        )

        // Center the image within the region. Baked into the canvas offset so
        // markers and the clipboard export stay aligned.
        let centerOffset = CGPoint(
            x: max(0, (content.width - imageSize.width) / 2),
            y: max(0, (content.height - imageSize.height) / 2)
        )

        // Place the window so the image's top-left lands on imageTopLeft, then
        // clamp on-screen (when a screen is known), reserving the toolbar band
        // below the window unless the toolbar overlaps the image.
        var originX = imageTopLeft.x - borderWidth - centerOffset.x
        var originY = (imageTopLeft.y + borderWidth + centerOffset.y) - windowSize.height
        if let visible {
            originX = min(max(originX, visible.minX + edgeMargin), visible.maxX - edgeMargin - windowSize.width)
            let reserveBelow = toolbarOverlaps ? edgeMargin : edgeMargin + toolbarBelow
            originY = min(max(originY, visible.minY + reserveBelow), visible.maxY - edgeMargin - windowSize.height)
        }
        let windowFrame = CGRect(origin: CGPoint(x: originX, y: originY), size: windowSize)

        presentAnnotationWindow(viewportSize: content, initialCanvasOffset: centerOffset, at: windowFrame)
        presentToolbar(for: windowFrame, overlaps: toolbarOverlaps)
        installKeyMonitor()
        startObservingFocus()
    }

    /// The visible frame (excludes menu bar / Dock) of the screen containing the
    /// point, falling back to the main screen. Nil when AppKit reports no screen
    /// at all — the caller then shows the capture at natural size and pans.
    private func visibleFrame(containing point: CGPoint) -> CGRect? {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        return screen?.visibleFrame
    }

    // MARK: - Hide / reopen

    /// The snapshot editor auto-hides when the app loses focus (the user clicks
    /// another app), preserving all state, and can be brought back with Meh+Z.
    /// We observe the app-level resign-active notification — NOT window-level
    /// resign-key — so moving between our own annotation window and the
    /// (non-activating) toolbar panel doesn't trigger a hide.
    private func startObservingFocus() {
        guard focusObserver == nil else { return }
        focusObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
    }

    private func stopObservingFocus() {
        if let focusObserver {
            NotificationCenter.default.removeObserver(focusObserver)
        }
        focusObserver = nil
    }

    private func hide() {
        guard !isHidden else { return }
        // Don't hide because of the focus loss caused by a pan/drag that just
        // ended outside the window — only on a genuine app switch.
        if let last = eventManager.lastCanvasDragAt, Date().timeIntervalSince(last) < 0.6 {
            return
        }
        isHidden = true
        removeKeyMonitor()
        stopObservingFocus()
        toolbarPanel?.orderOut(nil)
        annotationWindow?.orderOut(nil)
        // Keep the windows + managers alive so reopen() can restore everything.
    }

    func reopen() {
        guard isHidden else { return }
        isHidden = false
        annotationWindow?.makeKeyAndOrderFront(nil)
        toolbarPanel?.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installKeyMonitor()
        startObservingFocus()
    }

    // MARK: - Key shortcuts (⌘C, Esc)

    /// ⌘C copies the annotated snapshot and dismisses the editor; Esc just
    /// dismisses it. Both defer to an active text editor first, so typing a
    /// space/Esc or copying selected text inside the text tool still works.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            // Esc dismisses the editor — unless a text field is capturing it.
            if event.keyCode == 53 { // Escape
                if NSApp.keyWindow?.firstResponder is NSText { return event }
                self.close()
                return nil
            }

            // ⌘C copies + closes — unless a text editor handles its own copy.
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods == .command, event.charactersIgnoringModifiers?.lowercased() == "c" {
                if NSApp.keyWindow?.firstResponder is NSText { return event }
                self.copyAndClose()
                return nil
            }

            return event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }

    // MARK: - Windows

    private func presentAnnotationWindow(viewportSize: CGSize, initialCanvasOffset: CGPoint, at frame: CGRect) {
        let view = CaptureAnnotationView(
            capturedImage: capturedImage,
            viewportSize: viewportSize,
            initialCanvasOffset: initialCanvasOffset
        )
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
        // No drop shadow — the dashed border is the only frame, so small
        // snapshots don't get a gray shadow halo around them.
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: view)
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        annotationWindow = window
    }

    /// The toolbar's intrinsic size, measured by laying out MiniToolbarView in a
    /// throwaway hosting view. Used to size the panel and the minimum window.
    private func measureToolbarSize() -> CGSize {
        let probe = MiniToolbarView(copyAction: {}, closeAction: {})
            .environmentObject(toolsManager)
            .environmentObject(markersManager)
            .environmentObject(eventManager)
        let size = NSHostingView(rootView: probe).fittingSize
        return size.width > 0 ? size : CGSize(width: 280, height: 58)
    }

    private func presentToolbar(for frame: CGRect, overlaps: Bool) {
        let toolbarFrame = toolbarFrame(for: frame, overlaps: overlaps)

        let view = MiniToolbarView(
            copyAction: { [weak self] in self?.copyAndClose() },
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
        // One level above the annotation window (.floating) so the toolbar is
        // never covered when the snapshot window is clicked/reordered.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: view)
        panel.setFrame(toolbarFrame, display: true)
        panel.orderFront(nil)

        toolbarPanel = panel
    }

    /// The toolbar is centered horizontally under the snapshot. By default it
    /// sits in a band *below* the dashed border; when `overlaps` is true (the
    /// image filled the screen) it floats *inside*, over the bottom edge. X is
    /// clamped to the visible screen so it stays reachable even when the snapshot
    /// is narrower than the toolbar.
    private func toolbarFrame(for frame: CGRect, overlaps: Bool) -> CGRect {
        let visible = (annotationWindow?.screen ?? NSScreen.main)?.visibleFrame ?? frame
        var originX = frame.midX - toolbarSize.width / 2
        originX = min(max(originX, visible.minX + 8), visible.maxX - toolbarSize.width - 8)
        // AppKit: minY is the bottom edge. Below = step down past the gap + the
        // toolbar's own height; overlap = inset up from the window's bottom.
        let originY = overlaps
            ? frame.minY + toolbarInsideInset
            : frame.minY - toolbarTopGap - toolbarSize.height
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

    private func copyAndClose() {
        copyToClipboard()
        close()
    }

    func close() {
        removeKeyMonitor()
        stopObservingFocus()
        toolbarPanel?.orderOut(nil)
        toolbarPanel = nil
        annotationWindow?.orderOut(nil)
        annotationWindow = nil
        onClose?()
        onClose = nil
    }
}
