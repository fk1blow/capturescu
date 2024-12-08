//
//  WindowStyleModifier.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct WindowStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(GeometryReader { _ in
                Color.clear
                    .onAppear {
                        if let window = NSApplication.shared.windows.first {
                            // Make the title bar transparent and hide the title
                            window.titlebarAppearsTransparent = true
                            window.titleVisibility = .hidden

                            // Keep the traffic light (semaphore) buttons by keeping `.titled`
                            window.styleMask.insert(.titled)

                            // Ensure the window is movable only in custom draggable region
                            window.isMovableByWindowBackground = false
                            window.styleMask.insert([.closable, .miniaturizable, .resizable])
                        }
                    }
            })
    }
}

extension View {
    func customWindowStyle() -> some View {
        self.modifier(WindowStyleModifier())
    }
}
