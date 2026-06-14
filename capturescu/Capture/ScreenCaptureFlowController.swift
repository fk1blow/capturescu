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

    /// Bring back the snapshot editor after it auto-hid on focus loss (Meh+Z).
    /// No-op if there's no retained session.
    func reopenLastCapture() {
        annotationController?.reopen()
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

        // Selection (top-left view points) → pixel rect in the captured image.
        let pixelRect = CGRect(
            x: selectionPoints.minX * scale,
            y: selectionPoints.minY * scale,
            width: selectionPoints.width * scale,
            height: selectionPoints.height * scale
        ).integral

        let imageBounds = CGRect(x: 0, y: 0, width: capture.fullImage.width, height: capture.fullImage.height)
        let cropRect = pixelRect.intersection(imageBounds)

        guard cropRect.width >= 1, cropRect.height >= 1,
              let cropped = capture.fullImage.cropping(to: cropRect) else { return }

        // Snapshot point size derived from the actual cropped pixels (avoids
        // half-pixel drift between the crop and the window).
        let pointSize = CGSize(width: cropRect.width / scale, height: cropRect.height / scale)

        // The editor window is at least `minSize`, so a tiny capture still yields
        // a usable window; the snapshot sits at its real size top-left and the
        // remaining area is filled gray (see CaptureAnnotationView).
        let minSize = CGSize(width: 360, height: 240)
        let windowSize = CGSize(
            width: max(pointSize.width, minSize.width),
            height: max(pointSize.height, minSize.height)
        )

        // Anchor the window's top-left at the selection's top-left (AppKit is
        // bottom-left origin → flip Y), then clamp so the whole editor stays
        // on-screen.
        var originX = screenFrame.minX + selectionPoints.minX
        var originY = screenFrame.minY + screenFrame.height - selectionPoints.minY - windowSize.height
        originX = min(max(originX, screenFrame.minX), screenFrame.maxX - windowSize.width)
        originY = min(max(originY, screenFrame.minY), screenFrame.maxY - windowSize.height)
        let annotationFrame = CGRect(origin: CGPoint(x: originX, y: originY), size: windowSize)

        let controller = AnnotationWindowController()
        controller.present(image: cropped, scale: scale, at: annotationFrame) { [weak self] in
            self?.annotationController = nil
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
