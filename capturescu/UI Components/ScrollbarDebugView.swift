//
//  ScrollbarDebugView.swift
//  capturescu
//
//  Debug and testing view for scrollbar functionality
//

import SwiftUI

#if DEBUG
/// Debug overlay to visualize scrollbar state and content bounds
struct ScrollbarDebugView: View {
    @ObservedObject var scrollbarState: ScrollbarState
    @State private var showDebugInfo = false
    
    var body: some View {
        VStack {
            if showDebugInfo {
                debugInfoPanel
            }
            
            Spacer()
            
            HStack {
                Spacer()
                debugToggleButton
            }
        }
        .padding()
    }
    
    private var debugInfoPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scrollbar Debug Info")
                .font(.headline)
                .foregroundColor(.primary)
            
            Group {
                Text("Content Bounds: \(formatRect(scrollbarState.contentBounds))")
                Text("Viewport Bounds: \(formatRect(scrollbarState.viewportBounds))")
                Text("Canvas Offset: \(formatPoint(scrollbarState.canvasOffset))")
                Text("H-Scroll: \(scrollbarState.showHorizontalScrollbar ? "Visible" : "Hidden")")
                Text("V-Scroll: \(scrollbarState.showVerticalScrollbar ? "Visible" : "Hidden")")
                Text("H-Position: \(String(format: "%.1f", scrollbarState.horizontalScrollPosition))")
                Text("V-Position: \(String(format: "%.1f", scrollbarState.verticalScrollPosition))")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
    
    private var debugToggleButton: some View {
        Button(action: { showDebugInfo.toggle() }) {
            Image(systemName: showDebugInfo ? "eye.slash" : "eye")
                .foregroundColor(.secondary)
        }
        .buttonStyle(PlainButtonStyle())
        .help("Toggle scrollbar debug info")
    }
    
    private func formatRect(_ rect: CGRect) -> String {
        "(\(Int(rect.origin.x)), \(Int(rect.origin.y))) \(Int(rect.width))×\(Int(rect.height))"
    }
    
    private func formatPoint(_ point: CGPoint) -> String {
        "(\(Int(point.x)), \(Int(point.y)))"
    }
}

/// Debug modifier to add scrollbar debugging to any view
extension View {
    func scrollbarDebug(_ scrollbarState: ScrollbarState) -> some View {
        self.overlay(
            ScrollbarDebugView(scrollbarState: scrollbarState),
            alignment: .topTrailing
        )
    }
}
#endif