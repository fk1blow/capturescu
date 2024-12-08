//
//  MarkersManager.swift
//  capturescu
//
//  Created by Dragos Tudorache
//

import Foundation
import SwiftUI

struct MarkerSelection {
    var atIndex: Int
    var marker: Marker
}

class MarkersManager: ObservableObject {
    @Published var markers: [Marker] = []
    @Published var hoveredMarker: MarkerSelection?
    @Published var selectedMarker: MarkerSelection?

    func addMarker(marker: Marker) {
        markers.append(marker)
    }
    
    func isMarkerHovered() -> Bool {
        return hoveredMarker != nil
    }
    
    // - if theres already a selected marker, remove it and the highlight
    // - if theres an active marker, selected == active marker
    func selectHoveredMarker() {
        if selectedMarker != nil {
            markers[selectedMarker!.atIndex].hideHighlight()
            selectedMarker = nil
        }
        if hoveredMarker != nil {
            selectedMarker = hoveredMarker!
            markers[selectedMarker!.atIndex].showHighlight()
        }
    }
    
    func clearSelectedMarker() {
        if selectedMarker != nil {
            markers[selectedMarker!.atIndex].hideHighlight()
        }
        selectedMarker = nil
    }
    
    func setHoveredMarker(on marker: Marker, atIndex: Int) {
        // NSCursor.openHand.set()
        hoveredMarker = MarkerSelection(atIndex: atIndex, marker: marker)
        markers[hoveredMarker!.atIndex].showHighlight()
    }
    
    func clearHoveredMarker() {
        // NSCursor.arrow.set()
        
        guard hoveredMarker != nil else { return }
        
        // clear the highlight if it's not the selected one
        if hoveredMarker?.marker.id != selectedMarker?.marker.id {
            markers[hoveredMarker!.atIndex].hideHighlight()
        }
        hoveredMarker = nil
    }
    
    func moveSelectedMarker(to location: CGPoint) {
        guard let selectedMarker = selectedMarker, selectedMarker.atIndex < markers.count else {
            return
        }
        
        markers[selectedMarker.atIndex].offsetMarkerBy(dx: location.x, dy: location.y)
    }
 
    func deleteSelectedMarker() {
        guard selectedMarker != nil else { return }
        
        markers[selectedMarker!.atIndex].hideHighlight()
        markers.remove(at: selectedMarker!.atIndex)
        
        selectedMarker = nil
        hoveredMarker = nil
    }
    
    func markersPaths() -> [Path] {
        var paths: [Path] = []

        for marker in markers {
            let representation = marker.getRepresentation()

            switch representation {
            case .path(let path):
                paths.append(path)
            default:
                break
            }
        }
        
        return paths
    }
}
