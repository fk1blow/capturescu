//
//  HandPointerTool.swift
//  capturescu
//
//  A no-op pointer tool used as a "pan" mode. Panning itself is a view-level
//  concern (DrawingSurfaceView intercepts the drag and shifts `canvasOffset`
//  before events ever reach a tool), so this tool only needs to exist so the
//  toolbar can select it and highlight it, and so the canvas can switch the
//  cursor to an open hand while it's active.
//
//  It lives in the Capture group (a filesystem-synchronized Xcode group) so it
//  compiles without editing the project file; it's only used by the in-place
//  annotation flow.
//

import SwiftUI

@Observable class HandPointerTool: PointerTool {
    let toolName = PointerToolName.HandPointer
    let needsAccessoryView = false

    func handleEvent(_ event: PointerEvent) -> ToolResponse {
        // Panning is handled in the view layer; the tool does nothing.
        .empty
    }

    func renderPreview(context: GraphicsContext) {}
    func reset() {}
}
