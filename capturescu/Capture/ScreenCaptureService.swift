//
//  ScreenCaptureService.swift
//  capturescu
//
//  Grabs a full-resolution screenshot of the main display using
//  ScreenCaptureKit. We capture the WHOLE display up front (before any of our
//  own UI is on screen) and crop to the user's selection afterwards, so the
//  selection overlay never ends up in the shot.
//

import AppKit
import CoreGraphics
import ScreenCaptureKit

enum CaptureError: Error {
    case permissionDenied
    case noDisplay
    case captureFailed
}

/// The frozen full-display capture plus the geometry needed to map a
/// selection back onto the screen.
struct ScreenCaptureResult {
    /// Full display image in PIXELS (top-left origin).
    let fullImage: CGImage
    /// AppKit frame of the captured screen, in POINTS (bottom-left origin).
    let screenFrame: CGRect
    /// Backing scale factor of the captured screen (e.g. 2.0 on Retina).
    let scale: CGFloat
}

enum ScreenCaptureService {

    /// Capture the main display at full resolution. Throws `CaptureError`
    /// if Screen Recording permission is missing or capture fails.
    static func captureMainDisplay() async throws -> ScreenCaptureResult {
        // Preflight the Screen Recording permission. If it isn't granted,
        // trigger the system prompt and bail — the caller surfaces an alert.
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            throw CaptureError.permissionDenied
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        // Match the SCDisplay to its NSScreen for the backing scale + AppKit frame.
        let nsScreen = NSScreen.screens.first { screen in
            screenNumber(of: screen) == display.displayID
        } ?? NSScreen.main

        let scale = nsScreen?.backingScaleFactor ?? 2.0
        let screenFrame = nsScreen?.frame ?? CGRect(x: 0, y: 0, width: display.width, height: display.height)

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        // Request full pixel resolution so the cropped region stays sharp.
        config.width = Int(CGFloat(display.width) * scale)
        config.height = Int(CGFloat(display.height) * scale)
        config.showsCursor = false
        config.scalesToFit = false

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        return ScreenCaptureResult(fullImage: image, screenFrame: screenFrame, scale: scale)
    }

    private static func screenNumber(of screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return screen.deviceDescription[key] as? CGDirectDisplayID
    }
}
