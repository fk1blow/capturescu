//
//  TextPointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

@Observable class TextPointerTool: PointerTool {
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
    
    // Store the original click position for new markers
    private var currentClickPosition: CGPoint?
    
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
        // Check if clicking on an existing marker
        if let markersManager = markersManager {
            let markerFinder = MarkerFinder(markersManager: markersManager)
            
            if let editableMarker = markerFinder.findEditableMarkerAt(point) {
                if editableMarker.canEdit {
                    // Edit existing text marker
                    return handleEditMarker(editableMarker.marker, at: point, index: editableMarker.index)
                } else {
                    // Non-text marker - switch to selection tool
                    return ToolResponse(
                        shouldContinue: true,
                        toolSwitch: .selectionTool,
                        editMarker: (editableMarker.marker, editableMarker.index)
                    )
                }
            }
        }
        
        // Create new text marker - store the click position and use geometry
        currentClickPosition = point
        let textGeometry = TextMarkerGeometry(renderBounds: CGRect(origin: point, size: CGSize(width: 120, height: 30)))
        let editingPosition = textGeometry.getEditingPosition(for: point)
        let accessoryView = createTextEditor(at: editingPosition)
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
        
        guard let textMarker = marker as? TextMarker else {
            // This should never happen - only text markers should be sent for editing
            return .empty
        }
        
        let initialText = textMarker.textValueRepresentation
        let editingPosition = textMarker.getEditingPosition()
        
        let accessoryView = createTextEditor(at: editingPosition, initialText: initialText)
        
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
        
        if let editing = editingContext {
            // Update existing marker - use the original position
            let originalTextMarker = editing.originalMarker as! TextMarker
            let originalPosition = originalTextMarker.frameRepresentation.origin
            
            // Calculate actual text size for updated marker
            let font = NSFont.systemFont(ofSize: 14)
            let attributes = [NSAttributedString.Key.font: font]
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            let textBounds = attributedString.boundingRect(with: CGSize(width: 280, height: 280), options: [.usesLineFragmentOrigin, .usesFontLeading])
            
            let textGeometry = TextMarkerGeometry(renderBounds: CGRect(
                origin: originalPosition,
                size: CGSize(width: max(textBounds.width + 4, 20), height: max(textBounds.height + 4, 16))
            ))
            
            var updatedMarker = TextMarker(
                markerColor: markerColor,
                textValue: text,
                frame: textGeometry.renderBounds
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
            // Create new marker - use the stored original click position
            guard let originalClickPoint = currentClickPosition else {
                return .empty
            }
            
            
            // Calculate actual text size instead of using text field frame
            let font = NSFont.systemFont(ofSize: 14)
            let attributes = [NSAttributedString.Key.font: font]
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            let textBounds = attributedString.boundingRect(with: CGSize(width: 280, height: 280), options: [.usesLineFragmentOrigin, .usesFontLeading])
            
            let textGeometry = TextMarkerGeometry(renderBounds: CGRect(
                origin: originalClickPoint,
                size: CGSize(width: max(textBounds.width + 4, 20), height: max(textBounds.height + 4, 16))
            ))
            
            let newMarker = TextMarker(
                markerColor: markerColor,
                textValue: text,
                frame: textGeometry.renderBounds
            )
            
            // Clear the stored position
            currentClickPosition = nil
            
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
        currentClickPosition = nil // Clear stored position on cancel
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
            .frame(minWidth: 120, maxWidth: 300, minHeight: 30, maxHeight: 300)
            .fixedSize(horizontal: true, vertical: true)
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