//
//  NewTextPointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

@Observable class NewTextPointerTool: NewPointerTool {
    let toolName = PointerToolName.TextPointer
    let needsAccessoryView = true
    
    private var markerColor: MarkerColor
    var editingContext: EditingContext?
    private weak var markersManager: MarkersManager?
    private var eventHandler: ((PointerEvent) -> Void)?
    
    struct EditingContext {
        let originalMarker: Marker
        let index: Int
        let startPosition: CGPoint
    }
    
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
            
        case .editMarker(let marker, let point, let index):
            return handleEditMarker(marker, at: point, index: index)
            
        case .accessoryAction(let action):
            return handleAccessoryAction(action)
            
        case .cancelEdit:
            return handleCancelEdit()
            
        default:
            return .empty
        }
    }
    
    func reset() {
        editingContext = nil
    }
    
    func updateColor(_ color: MarkerColor) {
        markerColor = color
    }
    
    func updateMarkersManager(_ markersManager: MarkersManager) {
        self.markersManager = markersManager
    }
    
    // MARK: - Event Handlers
    
    private func handleClick(at point: CGPoint) -> ToolResponse {
        // Create new text marker
        let accessoryView = createTextEditor(at: point)
        return ToolResponse(
            shouldContinue: true,
            accessoryView: accessoryView
        )
    }
    
    private func handleEditMarker(_ marker: Marker, at point: CGPoint, index: Int) -> ToolResponse {
        // Edit existing text marker
        editingContext = EditingContext(
            originalMarker: marker,
            index: index,
            startPosition: point
        )
        
        let initialText = (marker as? TextMarker)?.textValueRepresentation ?? ""
        let accessoryView = createTextEditor(at: point, initialText: initialText)
        
        return ToolResponse(
            shouldContinue: true,
            accessoryView: accessoryView
        )
    }
    
    private func handleAccessoryAction(_ action: AccessoryAction) -> ToolResponse {
        switch action {
        case .textSubmitted(let text, let frame):
            return handleTextSubmitted(text: text, frame: frame)
            
        case .textCancelled:
            return handleTextCancelled()
            
        case .hide:
            return ToolResponse(
                shouldContinue: false,
                clearSelection: true
            )
            
        default:
            return .empty
        }
    }
    
    private func handleCancelEdit() -> ToolResponse {
        editingContext = nil
        return ToolResponse(
            shouldContinue: false,
            clearSelection: true
        )
    }
    
    private func handleTextSubmitted(text: String, frame: CGRect) -> ToolResponse {
        guard let markersManager = markersManager else { return .empty }
        
        // Adjust frame to align with text field position
        let adjustedFrame = CGRect(
            x: frame.origin.x + 8,
            y: frame.origin.y - 21,
            width: frame.width,
            height: frame.height
        )
        
        if let editing = editingContext {
            // Update existing marker
            var updatedMarker = TextMarker(
                markerColor: markerColor,
                textValue: text,
                frame: adjustedFrame
            )
            updatedMarker.id = editing.originalMarker.id
            
            let command = UpdateMarkerCommand(
                markersManager: markersManager,
                oldMarker: editing.originalMarker,
                newMarker: updatedMarker,
                at: editing.index
            )
            
            editingContext = nil
            return ToolResponse(
                shouldContinue: false,
                commands: [command]
            )
        } else {
            // Create new marker
            let newMarker = TextMarker(
                markerColor: markerColor,
                textValue: text,
                frame: adjustedFrame
            )
            
            let command = AddMarkerCommand(
                markersManager: markersManager,
                marker: newMarker
            )
            
            return ToolResponse(
                shouldContinue: false,
                commands: [command]
            )
        }
    }
    
    private func handleTextCancelled() -> ToolResponse {
        editingContext = nil
        return ToolResponse(
            shouldContinue: false,
            clearSelection: true
        )
    }
    
    // MARK: - Accessory View Creation
    
    private func createTextEditor(at position: CGPoint, initialText: String = "") -> AnyView {
        return AnyView(
            NewTextPointerToolAccessoryView(
                position: position,
                initialText: initialText,
                onTextSubmitted: { [weak self] text, frame in
                    let action = AccessoryAction.textSubmitted(text, frame)
                    let event = PointerEvent.accessoryAction(action)
                    self?.eventHandler?(event)
                },
                onCancelled: { [weak self] in
                    let action = AccessoryAction.textCancelled
                    let event = PointerEvent.accessoryAction(action)
                    self?.eventHandler?(event)
                }
            )
        )
    }
}

// MARK: - Accessory View
struct NewTextPointerToolAccessoryView: View {
    let position: CGPoint
    let initialText: String
    let onTextSubmitted: (String, CGRect) -> Void
    let onCancelled: () -> Void
    
    @State private var text: String
    @State private var textFrame: CGRect = .zero
    @FocusState private var isTextFieldFocused: Bool
    
    init(
        position: CGPoint,
        initialText: String,
        onTextSubmitted: @escaping (String, CGRect) -> Void,
        onCancelled: @escaping () -> Void
    ) {
        self.position = position
        self.initialText = initialText
        self.onTextSubmitted = onTextSubmitted
        self.onCancelled = onCancelled
        self._text = State(initialValue: initialText)
    }
    
    var body: some View {
        TextField("Enter text", text: $text, axis: .vertical)
            .focused($isTextFieldFocused)
            .textFieldStyle(.plain)
            .padding(8)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.blue, lineWidth: 2)
            )
            .frame(minWidth: 120, maxWidth: 200)
            .background(GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        textFrame = geometry.frame(in: .global)
                    }
                    .onChange(of: geometry.frame(in: .global)) { newFrame in
                        textFrame = newFrame
                    }
            })
            .onKeyPress { keyPress in
                if keyPress.key == .return {
                    if keyPress.modifiers.contains(.shift) {
                        // Shift+Enter: insert newline
                        text += "\n"
                        return .handled
                    } else {
                        // Enter: submit text
                        submitText()
                        return .handled
                    }
                } else if keyPress.key == .escape {
                    // Escape: cancel
                    onCancelled()
                    return .handled
                }
                return .ignored
            }
            .offset(x: position.x, y: position.y)
            .onAppear {
                isTextFieldFocused = true
            }
    }
    
    private func submitText() {
        if !text.isEmpty {
            onTextSubmitted(text, textFrame)
        } else {
            onCancelled()
        }
    }
}