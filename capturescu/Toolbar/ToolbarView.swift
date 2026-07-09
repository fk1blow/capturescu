//
//  ToolbarView.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct ToolbarView: View {
  var body: some View {
    VStack {
      Spacer()

      HStack(spacing: 8) {
        ToolPickerView()
        Divider().frame(width: 1.5, height: 26).padding(.horizontal, 8).opacity(0.5)
        HStack(spacing: 8) {
          ColorPickerButton()
          SizePickerButton()
        }
      }
      .padding(6)
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(Color(hex: "#3A3A3C"))
          .overlay(
            RoundedRectangle(cornerRadius: 14)
              .stroke(Color.white.opacity(0.1), lineWidth: 1)
          )
      )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .offset(x: 0, y: -24)
  }
}
