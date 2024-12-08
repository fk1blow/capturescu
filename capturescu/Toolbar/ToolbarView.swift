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

            HStack {
                ToolPickerView()
                Divider().frame(width: 2, height: 32).padding(.horizontal, 20).opacity(0.6)
                HStack(spacing: 12) {
                    ColorPickerButton()
                    SizePickerButton()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(hex: "#1E1E1E"))
                    .opacity(0.8)
                    .frame(width: 427, height: 58)
                    //  b/c of the fucking ring
                    .offset(x: 7, y: 0)
            )
        }
        .frame(maxWidth: 200, maxHeight: .infinity, alignment: .bottom)
        .offset(x: 0, y: -24)
    }
}
