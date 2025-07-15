//
//  PointerToolCompat.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

/// Compatibility layer to use new event system alongside old system
class PointerToolCompat: ObservableObject {
    @Published var useNewSystem = false
    
    private var eventManager: EventManager?
    
    func setupNewSystem(markersManager: MarkersManager, toolsManager: ToolsManager) {
        eventManager = EventManager(
            markersManager: markersManager,
            toolsManager: toolsManager
        )
        useNewSystem = true
    }
    
    func getEventManager() -> EventManager? {
        return eventManager
    }
    
    func toggleSystem() {
        useNewSystem.toggle()
    }
}

/// View that can switch between old and new pointer tool systems
struct CompatPointerToolView: View {
    @EnvironmentObject var toolsManager: ToolsManager
    @EnvironmentObject var markersManager: MarkersManager
    @StateObject private var compat = PointerToolCompat()
    
    var body: some View {
        VStack {
            // Toggle button for testing
            Button("Use New System: \(compat.useNewSystem ? "ON" : "OFF")") {
                compat.toggleSystem()
            }
            .padding()
            
            // Pointer tool view
            if compat.useNewSystem {
                NewPointerToolView()
            } else {
                PointerToolView()
            }
        }
        .onAppear {
            compat.setupNewSystem(
                markersManager: markersManager,
                toolsManager: toolsManager
            )
        }
    }
}