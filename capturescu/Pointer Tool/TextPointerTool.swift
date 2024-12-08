//
//  TextPointerTool.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Combine
import Foundation
import SwiftUI

@Observable class TextPointerTool: PointerTool {
    var toolName = PointerToolName.TextPointer

    private var marker: TextMarker
    private var markerColor: MarkerColor
    private var showAccessoryView = false
    private var accessoryViewLocation: CGPoint = .zero

    init(color: MarkerColor) {
        self.markerColor = color
        self.marker = TextMarker(markerColor: color)
    }

    func clearMarker() {
        marker = TextMarker(markerColor: markerColor)
    }

    func drawMarker(onto graphicsContext: GraphicsContext) {
        marker.draw(onto: graphicsContext)
    }

    func getMarker() -> Marker {
        return marker
    }

    func renderAccessoryView(onDone: @escaping (_ maker: Marker) -> Void) -> AnyView {
        if showAccessoryView {
            return AnyView(
                TextPointerAccessoryView(
                    position: accessoryViewLocation,
                    onDone: { text, frame in
                        self.marker = TextMarker(markerColor: self.markerColor, textValue: text, frame: frame)
                        self.showAccessoryView = false
                        onDone(self.getMarker())
                        // this type of marker doesn't have the usual `begin`, `update`, `end` lifecycle
                        // so that after the accessory is `done`, we get rid of the current marker
                        // and initialize a new one(so we don't draw the current marker indefinately)
                        self.clearMarker()
                    }
                )
            )
        }
        return AnyView(EmptyView())
    }

    func pointerClicked(at location: CGPoint) {
        showAccessoryView = !showAccessoryView
        accessoryViewLocation = showAccessoryView ? location : CGPoint.zero
    }
}

struct TextPointerAccessoryView: View {
    // TODO: maybe add this through a Protocol
    var position: CGPoint
    // TODO: maybe add this through a Protocol
    var onDone: (_ text: String, _ frame: CGRect) -> Void

    @State private var text: String = ""
    @State private var textEditorHeight: CGFloat = 20
    @FocusState private var isFocused: Bool
    @State var eventsMonitor: Any? = nil

    private let font: NSFont = .systemFont(ofSize: 14)
    private let editorWidth: CGFloat = 200 // Set a fixed width for the TextEditor

    var body: some View {
        ZStack {
            TextEditor(text: $text)
                .font(.system(size: 14)) // Match font size
                .frame(width: editorWidth, height: textEditorHeight) // Fixed width
                .onChange(of: text) { _, _ in
                    adjustHeight()
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.5)))
                .offset(x: position.x, y: position.y)
                .focused($isFocused)
        }
        .onAppear {
            adjustHeight() // Adjust height on appear to set initial size correctly
            isFocused = true // Set focus to the TextEditor when the view appears

            // this will fuckin brake/takeover the events monitor used inside the ContentView wtf!!!
            eventsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                if event.keyCode == 53 {
                    escapeKeyPressed()
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = eventsMonitor {
                NSEvent.removeMonitor(monitor)
                eventsMonitor = nil
            }
        }
    }

    private func adjustHeight() {
        // Calculate the line height using font properties
        let lineHeight = font.ascender + abs(font.descender) + font.leading

        // Calculate number of lines based on the current text length
        let numberOfLines = ceil(textSizeFor(text: text, width: editorWidth).height / lineHeight)

        // Update height based on number of lines
        textEditorHeight = numberOfLines * lineHeight
    }

    private func textSizeFor(text: String, width: CGFloat) -> CGSize {
        // Create attributed string to measure the text size
        let attributedText = NSAttributedString(string: text, attributes: [.font: font])
        let size = attributedText.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        // Return the calculated size, using ceil to round up to the nearest pixel
        return CGSize(width: size.width, height: ceil(size.height))
    }

    private func escapeKeyPressed() {
        onDone(text, CGRect(x: position.x, y: position.y, width: editorWidth, height: textEditorHeight))
        // Add the code for the functionality you want to trigger here
    }
}
