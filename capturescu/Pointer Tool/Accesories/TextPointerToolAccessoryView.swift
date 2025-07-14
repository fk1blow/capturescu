//
//  TextPointerToolAccessoryView.swift
//  capturescu
//
//  Created by Dragos Tudorache on 22.12.2024.
//

import Foundation
import SwiftUI

struct TextPointerToolAccessoryView: View {
  // TODO: maybe add this through a Protocol
  var position: CGPoint
  var initialText: String = ""
  // TODO: maybe add this through a Protocol
  var onDone: (_ text: String, _ frame: CGRect) -> Void
  var onCancel: (() -> Void)?

  @State private var text: String = ""
  @State private var textEditorHeight: CGFloat = 20
  @FocusState private var isFocused: Bool

  private let font: NSFont = .systemFont(ofSize: 14)
  // this should be the initial width of the TextEditor
  // then i could either grow it or shrink it based on the text size
  // or it could be a fixed width.
  // It stays fixed if the user has presset "Return" or if the view bounds reached the screen bounds
  private let editorWidth: CGFloat = 200  // Set a fixed width for the TextEditor

  var body: some View {
    ZStack {
      TextEditor(text: $text)
        .onChange(of: text) { _, _ in
          adjustHeight()
        }
        .font(.system(size: 14))  // Match font size
        .frame(width: editorWidth, height: textEditorHeight)  // Fixed width
        .background(Color.gray.opacity(0.1))
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.5)))
        .offset(x: position.x, y: position.y)
        .focused($isFocused)
        .onKeyPress(.escape) {
          escapeKeyPressed()
          return .handled
        }
        .onKeyPress(keys: [.return], phases: [.down]) { keyPress in
          if keyPress.modifiers.contains(.shift) {
            // Shift+Enter: Allow new line (don't handle, let TextEditor handle it)
            return .ignored
          } else {
            // Enter: Save changes
            saveChanges()
            return .handled
          }
        }
    }
    .onAppear {
      text = initialText  // Initialize text with provided value
      adjustHeight()  // Adjust height on appear to set initial size correctly
      isFocused = true  // Set focus to the TextEditor when the view appears
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
    onCancel?()
  }
  
  private func saveChanges() {
    onDone(text, CGRect(x: position.x, y: position.y, width: editorWidth, height: textEditorHeight))
  }
}
