//
//  TextPointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI
import AppKit

@Observable class TextPointerTool: PointerTool {
    let toolName = PointerToolName.TextPointer
    let needsAccessoryView = true

    private var markerColor: MarkerColor
    /// Font size applied to newly created text markers. Existing markers keep the
    /// size they were created with when re-edited.
    var fontSize: CGFloat = TextMarkerFont.defaultSize
    private weak var markersManager: MarkersManager?
    private var eventHandler: ((PointerEvent) -> Void)?

    /// An existing text marker being edited. Captured immutably per session so a
    /// commit is unaffected by any later change to the tool's state.
    private struct TextEditTarget {
        let index: Int
        let id: UUID
    }

    /// The in-progress edit. The tool owns the live `editingText` (bound to the
    /// field) so it can commit the typed text atomically on any transition —
    /// Return, Escape, clicking away, or switching tools — without racing the
    /// field's own lifecycle.
    private struct EditSession {
        let id: UUID
        let origin: CGPoint          // canvas-space top-left of the text
        let target: TextEditTarget?  // nil = creating a new marker
        let color: MarkerColor
        let fontSize: CGFloat
    }

    private var session: EditSession?
    /// Live text of the active field. `@Observable`, bound into the editor view.
    var editingText: String = ""

    init(color: MarkerColor, markersManager: MarkersManager) {
        self.markerColor = color
        self.markersManager = markersManager
    }

    func setEventHandler(_ handler: @escaping (PointerEvent) -> Void) {
        eventHandler = handler
    }

    func handleEvent(_ event: PointerEvent) -> ToolResponse {
        switch event {
        case .click(let point):
            return handleClick(at: point)

        case .dragStart:
            // A drag on the canvas ends the current edit, committing typed text.
            return endSessionResponse()

        case .editMarker(let marker, _, let index):
            return handleEditMarker(marker, index: index)

        case .accessoryAction(let action):
            return handleAccessoryAction(action)

        case .cancelEdit, .keyPressed(.escape):
            // Escape discards the edit entirely: no commit, and the original
            // marker reappears (it was only hidden, never changed).
            clearSession()
            return ToolResponse(shouldContinue: false, clearSelection: true)

        default:
            return .empty
        }
    }

    /// Called on tool switch. Commit any in-progress text so switching tools
    /// doesn't silently discard what the user typed.
    func reset() {
        if let command = commitCurrentSession() {
            HistoryManager.shared.execute(command)
        }
    }

    func updateColor(_ color: MarkerColor) {
        markerColor = color
    }

    func updateFontSize(_ size: CGFloat) {
        fontSize = size
    }

    func updateMarkersManager(_ markersManager: MarkersManager) {
        self.markersManager = markersManager
    }

    // MARK: - Event Handlers

    private func handleClick(at point: CGPoint) -> ToolResponse {
        // A click first commits any field that's currently open (click-away),
        // then decides what this click does.
        var commands: [MarkerCommand] = []
        if let command = commitCurrentSession() { commands.append(command) }

        if let markersManager = markersManager {
            let markerFinder = MarkerFinder(markersManager: markersManager)
            if let editable = markerFinder.findEditableMarkerAt(point) {
                if editable.canEdit, let textMarker = editable.marker as? TextMarker {
                    // Edit an existing text marker in place.
                    startSession(
                        origin: textMarker.frameRepresentation.origin,
                        target: TextEditTarget(index: editable.index, id: textMarker.id),
                        color: textMarker.style.strokeColor,
                        fontSize: textMarker.fontSize,
                        initialText: textMarker.textValueRepresentation
                    )
                    return ToolResponse(
                        shouldContinue: true,
                        commands: commands,
                        accessoryView: makeField()
                    )
                } else {
                    // Non-text marker — hand off to the selection tool.
                    return ToolResponse(
                        shouldContinue: true,
                        commands: commands,
                        toolSwitch: .selectionTool,
                        editMarker: (editable.marker, editable.index)
                    )
                }
            }
        }

        // Empty space — start a new text marker at the click point.
        startSession(origin: point, target: nil, color: markerColor, fontSize: fontSize, initialText: "")
        return ToolResponse(
            shouldContinue: true,
            commands: commands,
            accessoryView: makeField()
        )
    }

    private func handleEditMarker(_ marker: Marker, index: Int) -> ToolResponse {
        var commands: [MarkerCommand] = []
        if let command = commitCurrentSession() { commands.append(command) }

        guard let textMarker = marker as? TextMarker else {
            // Only text markers are editable here.
            return ToolResponse(shouldContinue: false, commands: commands, clearSelection: true)
        }

        startSession(
            origin: textMarker.frameRepresentation.origin,
            target: TextEditTarget(index: index, id: textMarker.id),
            color: textMarker.style.strokeColor,
            fontSize: textMarker.fontSize,
            initialText: textMarker.textValueRepresentation
        )
        return ToolResponse(
            shouldContinue: true,
            commands: commands,
            accessoryView: makeField()
        )
    }

    private func handleAccessoryAction(_ action: AccessoryAction) -> ToolResponse {
        switch action {
        case .textSubmitted:
            return endSessionResponse()

        case .textCancelled:
            clearSession()
            return ToolResponse(shouldContinue: false, clearSelection: true)

        case .hide:
            return ToolResponse(shouldContinue: false, clearSelection: true)

        default:
            return .empty
        }
    }

    // MARK: - Session management

    private func startSession(origin: CGPoint, target: TextEditTarget?, color: MarkerColor, fontSize: CGFloat, initialText: String) {
        session = EditSession(id: UUID(), origin: origin, target: target, color: color, fontSize: fontSize)
        editingText = initialText
        // Hide the marker being edited so only the editor field shows.
        markersManager?.editingMarkerID = target?.id
    }

    /// Clear the active session and stop hiding the edited marker.
    private func clearSession() {
        session = nil
        markersManager?.editingMarkerID = nil
    }

    /// Build the command (if any) for the active session and clear it. Returns
    /// nil for an empty/cancelled session or when there's nothing to edit.
    private func commitCurrentSession() -> MarkerCommand? {
        guard let session = session, let markersManager = markersManager else {
            clearSession()
            return nil
        }
        let text = editingText
        clearSession()

        if let target = session.target {
            // Editing an existing marker.
            guard target.index >= 0, target.index < markersManager.markers.count,
                  let oldMarker = markersManager.markers[target.index] as? TextMarker,
                  oldMarker.id == target.id else {
                return nil
            }
            // Erasing all the text removes the marker.
            if text.isEmpty {
                return DeleteMarkerCommand(
                    markersManager: markersManager,
                    marker: oldMarker,
                    at: target.index
                )
            }
            // Otherwise update in place, preserving identity, color, and size.
            var updated = TextMarker(markerColor: oldMarker.style.strokeColor, textValue: text, origin: session.origin, fontSize: session.fontSize)
            updated.id = oldMarker.id
            return UpdateMarkerCommand(
                markersManager: markersManager,
                oldMarker: oldMarker,
                newMarker: updated,
                at: target.index
            )
        } else {
            // New marker: nothing to add if no text was typed.
            guard !text.isEmpty else { return nil }
            let newMarker = TextMarker(markerColor: session.color, textValue: text, origin: session.origin, fontSize: session.fontSize)
            return AddMarkerCommand(markersManager: markersManager, marker: newMarker)
        }
    }

    /// End the current session, returning a response that commits it and
    /// dismisses the field.
    private func endSessionResponse() -> ToolResponse {
        if let command = commitCurrentSession() {
            return ToolResponse(shouldContinue: false, commands: [command])
        }
        return ToolResponse(shouldContinue: false, clearSelection: true)
    }

    // MARK: - Accessory View

    private func makeField() -> AnyView {
        guard let session = session else { return AnyView(EmptyView()) }
        let textBinding = Binding<String>(
            get: { [weak self] in self?.editingText ?? "" },
            set: { [weak self] in self?.editingText = $0 }
        )
        return AnyView(
            TextMarkerEditorView(
                origin: session.origin,
                color: session.color.color,
                fontSize: session.fontSize,
                text: textBinding,
                onSubmit: { [weak self] in
                    self?.eventHandler?(.accessoryAction(.textSubmitted))
                },
                onCancel: { [weak self] in
                    self?.eventHandler?(.accessoryAction(.textCancelled))
                }
            )
            // Distinct identity per session so a replaced field gets fresh focus.
            .id(session.id)
        )
    }
}

// MARK: - Inline WYSIWYG text editor
//
// Renders as the text itself: same font, size, and color as the committed
// marker, borderless and transparent, positioned at the marker's canvas origin
// plus the current canvas pan so it tracks the surface. There is no bordered
// "text box" and no offset guessing — what you type is what you get.
struct TextMarkerEditorView: View {
    let origin: CGPoint
    let color: Color
    let fontSize: CGFloat
    @Binding var text: String
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @EnvironmentObject var editorModel: SnapshotEditorModel
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text, axis: .vertical)
            .focused($isFocused)
            .textFieldStyle(.plain)
            .font(TextMarkerFont.swiftUIFont(size: fontSize))
            .foregroundColor(color)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: TextMarkerFont.maxWidth, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color.clear)
            .onKeyPress { keyPress in
                if keyPress.key == .return {
                    if keyPress.modifiers.contains(.shift) {
                        text += "\n"       // Shift+Return: newline
                        return .handled
                    }
                    onSubmit()             // Return: commit
                    return .handled
                } else if keyPress.key == .escape {
                    onCancel()             // Escape: discard
                    return .handled
                }
                return .ignored
            }
            .offset(
                x: origin.x + editorModel.canvasOffset.x,
                y: origin.y + editorModel.canvasOffset.y
            )
            .onAppear {
                isFocused = true
                // When editing existing text, select it all so a single Delete
                // clears it (and committing empty removes the marker).
                if !text.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        (NSApp.keyWindow?.firstResponder as? NSText)?.selectAll(nil)
                    }
                }
            }
    }
}
