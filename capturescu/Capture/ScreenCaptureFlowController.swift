//
//  ScreenCaptureFlowController.swift
//  capturescu
//
//  Coordinates the whole capture flow: hotkey → freeze screen → drag a region
//  → crop + position → in-place annotation window. Owned by AppDelegate.
//

import AppKit
import SwiftUI

@MainActor
final class ScreenCaptureFlowController {
    private var capture: ScreenCaptureResult?
    private var selectionController: RegionSelectionController?
    private var annotationController: AnnotationWindowController?

    /// Fired when an annotation session ends, with how it ended. Set by
    /// AppDelegate to drive the menu-bar icon animation. Not called when the user
    /// cancels region selection before any capture is committed.
    var onSessionEnd: ((CaptureOutcome) -> Void)?

    /// Entry point — invoked by the global hotkey and the in-app menu command.
    func beginCapture() {
        // Don't start a second selection while one is already up.
        guard selectionController == nil else { return }

        // A fresh capture replaces any previous annotation session.
        annotationController?.close()
        annotationController = nil

        Task {
            do {
                let result = try await ScreenCaptureService.captureMainDisplay()
                self.startSelection(with: result)
            } catch {
                self.showPermissionAlert()
            }
        }
    }

    // MARK: - Selection

    private func startSelection(with result: ScreenCaptureResult) {
        capture = result

        let controller = RegionSelectionController(
            onComplete: { [weak self] rect in self?.finishSelection(rect) },
            onCancel: { [weak self] in self?.cancelSelection() }
        )
        controller.show(image: result.fullImage, scale: result.scale, screenFrame: result.screenFrame)
        selectionController = controller
    }

    private func cancelSelection() {
        selectionController?.close()
        selectionController = nil
        capture = nil
    }

    private func finishSelection(_ selectionPoints: CGRect) {
        selectionController?.close()
        selectionController = nil

        guard let capture else { return }
        self.capture = nil

        let scale = capture.scale
        let screenFrame = capture.screenFrame

        // Keep the WHOLE frozen image: resizing the editor reveals more of it
        // rather than re-capturing (a video underneath would have advanced). The
        // selection is already in image-point space (the overlay maps 1:1 to the
        // image); just clamp it to the image bounds.
        let imagePointSize = CGSize(
            width: CGFloat(capture.fullImage.width) / scale,
            height: CGFloat(capture.fullImage.height) / scale
        )
        let selection = selectionPoints.intersection(CGRect(origin: .zero, size: imagePointSize))

        guard selection.width >= 1, selection.height >= 1 else { return }

        let controller = AnnotationWindowController()
        controller.present(fullImage: capture.fullImage, scale: scale, screenFrame: screenFrame, selection: selection) { [weak self] outcome in
            self?.annotationController = nil
            self?.onSessionEnd?(outcome)
        }
        annotationController = controller
    }

    // MARK: - Permission

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording permission needed"
        alert.informativeText = """
        Capturescu needs Screen Recording access to capture a region of your screen. \
        Enable it in System Settings → Privacy & Security → Screen Recording, then relaunch the app.
        """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
