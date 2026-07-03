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
    private var clickOutsideMonitor: Any?

    // Fresh state, independent of the main window.
    private let toolsManager = ToolsManager()
    private let markersManager = MarkersManager()
    private var eventManager: EventManager!
    private var capturedImage: CapturedPasteboardImage!
    /// Owns the visible-region geometry; the window + toolbar follow its changes.
    private var editorModel: SnapshotEditorModel!

    /// The toolbar's real intrinsic size, measured per-present (fallback below).
    private var toolbarSize = CGSize(width: 280, height: 58)
    /// Gap between the toolbar's bottom edge and the window's bottom edge.
    private let toolbarInsideInset: CGFloat = 16
    /// Gap between the image's bottom edge and the toolbar's top edge.
    private let toolbarTopGap: CGFloat = 24
    private let borderWidth: CGFloat = 2
    /// Transparent ring around the visible snapshot where the resize handles live,
    /// so you grab from *outside* the dashed border. The window is grown by this.
    private let grabMargin: CGFloat = 14
    /// Keep the window this far from the screen edges, so the dashed border is
    /// always visible and there's breathing room. Captures larger than the
    /// resulting area are shown 1:1 and panned via the hand tool.
    private let edgeMargin: CGFloat = 12

    /// - Parameters:
    ///   - fullImage: the frozen WHOLE-screen capture (pixels). The editor shows
    ///     a screen-pinned window onto it; resizing/moving reveals more of it.
    ///   - screenFrame: the captured screen's frame, global AppKit coordinates.
    ///   - selection: the user's selected region, in image-point space (top-left
    ///     origin) — the initial visible region.
    func present(fullImage: CGImage, scale: CGFloat, screenFrame: CGRect, selection: CGRect, onClose: @escaping () -> Void) {
        self.onClose = onClose

        // Wire up the managers exactly like capturescuApp does.
        markersManager.setupUndoRedoNotification(toolsManager: toolsManager)
        // HistoryManager is a shared singleton; start each annotation session with
        // empty undo/redo stacks so a fresh capture can't undo into a prior session.
        HistoryManager.shared.clear()
        eventManager = EventManager(markersManager: markersManager, toolsManager: toolsManager)
        toolsManager.selectTool(named: .FreehandPointer) // default to draw mode

        // Measure the toolbar's real size so the window can fit it (env objects
        // must be wired first — the probe renders MiniToolbarView).
        toolbarSize = measureToolbarSize()

        // The editor wraps the WHOLE frozen screen; the dashed border + viewport
        // clip it down to the visible region.
        capturedImage = CapturedPasteboardImage(
            image: fullImage,
            position: .zero,
            scale: 1.0 / scale,
            hiDPIScale: 1.0 / scale,
            originalPNGData: nil
        )

        // Working area to keep the editor on-screen. A nil screen means we can't
        // determine one, so fall back to the captured screen frame (no clamping
        // beyond the image itself).
        let working = visibleFrame(containing: CGPoint(x: screenFrame.midX, y: screenFrame.midY)) ?? screenFrame

        let model = SnapshotEditorModel(
            fullImage: fullImage,
            scale: scale,
            screenFrame: screenFrame,
            visibleFrame: working,
            edgeMargin: edgeMargin,
            border: borderWidth,
            grabMargin: grabMargin,
            minSize: CGSize(width: 48, height: 48)
        )
        model.setInitialVisibleRect(selection)
        editorModel = model

        presentAnnotationWindow(at: model.windowFrame)
        presentToolbar(for: model.snapshotFrame, overlaps: toolbarOverlaps())
        installKeyMonitor()
        installClickOutsideMonitor()

        // From now on, any resize/move reflows the window + toolbar.
        model.onGeometryChange = { [weak self] in self?.applyGeometry() }
    }

    /// Reposition both windows after the visible region changed (resize / move).
    private func applyGeometry() {
        guard let window = annotationWindow else { return }
        window.setFrame(editorModel.windowFrame, display: true)
        // Anchor the toolbar to the visible snapshot, not the larger grab window.
        toolbarPanel?.setFrame(toolbarFrame(for: editorModel.snapshotFrame, overlaps: toolbarOverlaps()), display: true)
    }

    /// The toolbar sits below the editor unless that band would fall outside the
    /// working area (editor near the screen bottom), in which case it overlaps the
    /// editor's bottom edge instead.
    private func toolbarOverlaps() -> Bool {
        let belowOriginY = editorModel.snapshotFrame.minY - toolbarTopGap - toolbarSize.height
        return belowOriginY < editorModel.workingArea.minY
    }

    /// The visible frame (excludes menu bar / Dock) of the screen containing the
    /// point, falling back to the main screen. Nil when AppKit reports no screen
    /// at all — the caller then shows the capture at natural size and pans.
    private func visibleFrame(containing point: CGPoint) -> CGRect? {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        return screen?.visibleFrame
    }

    // MARK: - Dismiss on click-outside

    /// The snapshot editor dismisses when the user presses the mouse anywhere
    /// outside it. We use a *global* mouse-down monitor, which fires only for
    /// presses delivered to other apps — never for clicks on our own annotation
    /// window or toolbar panel. That makes the "click-away" gesture exact:
    ///
    ///   • A genuine click outside is a mouse-DOWN over another app/desktop →
    ///     the monitor fires → close.
    ///   • Panning the snapshot and releasing the mouse outside our window is a
    ///     mouse-UP — the press originated inside, so the drag is captured by our
    ///     window for its whole lifetime and no global mouse-DOWN ever fires →
    ///     the editor correctly stays open.
    ///
    /// Because the discriminator is the *press* location rather than a focus
    /// change, there's no timing heuristic needed to tell a pan-release apart
    /// from a click-away. (Global monitors are observe-only — the press still
    /// reaches the other app; we just also dismiss.)
    private func installClickOutsideMonitor() {
        guard clickOutsideMonitor == nil else { return }
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    private func removeClickOutsideMonitor() {
        if let clickOutsideMonitor {
            NSEvent.removeMonitor(clickOutsideMonitor)
        }
        clickOutsideMonitor = nil
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

            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // ⌘C copies + closes — unless a text editor handles its own copy.
            if mods == .command, event.charactersIgnoringModifiers?.lowercased() == "c" {
                if NSApp.keyWindow?.firstResponder is NSText { return event }
                self.copyAndClose()
                return nil
            }

            // ⌘Z undo / ⇧⌘Z redo — unless a text editor is capturing keys.
            if event.charactersIgnoringModifiers?.lowercased() == "z",
               mods == .command || mods == [.command, .shift] {
                if NSApp.keyWindow?.firstResponder is NSText { return event }
                if mods.contains(.shift) {
                    HistoryManager.shared.redo()
                } else {
                    HistoryManager.shared.undo()
                }
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

    private func presentAnnotationWindow(at frame: CGRect) {
        let view = CaptureAnnotationView(capturedImage: capturedImage)
            .environmentObject(toolsManager)
            .environmentObject(markersManager)
            .environmentObject(eventManager)
            .environmentObject(editorModel)

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
        // Export only the currently visible region of the frozen full screen.
        // Markers live in full-image-point space, so shift them (and the image)
        // by -visibleRect.origin to land the visible window at the output origin.
        let visible = editorModel.visibleRect
        let transformedMarkers = markersManager.markers.map { marker -> Marker in
            var shifted = marker
            shifted.offsetMarkerBy(dx: -visible.minX, dy: -visible.minY)
            return shifted
        }

        let pngData = CGContextRenderer.renderWithMarkers(
            image: capturedImage.image,
            markers: transformedMarkers,
            bounds: CGRect(origin: .zero, size: visible.size),
            imagePosition: CGPoint(x: -visible.minX, y: -visible.minY),
            imageSize: capturedImage.displaySize,
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
        removeClickOutsideMonitor()
        toolbarPanel?.orderOut(nil)
        toolbarPanel = nil
        annotationWindow?.orderOut(nil)
        annotationWindow = nil
        onClose?()
        onClose = nil
    }
}
