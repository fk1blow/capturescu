# Capturescu - Screenshot Annotation Tool

## Overview
Capturescu is a Swift/SwiftUI macOS native application for managing and annotating screenshots. The app provides a canvas-based interface with various drawing tools for annotation.

## Architecture

### Core Components

#### 1. Main Application (`capturescuApp.swift`)
- Entry point with `@main` attribute
- Manages global state objects: `ToolsManager`, `MarkersManager`, `KeyboardManager`
- Handles menu commands for copy/paste functionality
- Uses custom window styling

#### 2. Content View (`ContentView.swift`)
- Main UI coordinator implementing `KeyboardCommandResponder`
- Manages captured images from pasteboard
- Handles keyboard shortcuts (copy/paste)
- Coordinates between drawing surface and toolbar

#### 3. Drawing System

**DrawingSurfaceView (`Drawing/DrawingSurfaceView.swift`)**
- Main canvas using SwiftUI Canvas
- Renders captured images and all markers
- Overlays PointerToolView for interaction
- Coordinates with ToolsManager and MarkersManager

**MarkersManager (`Drawing/MarkersManager.swift`)**
- `@Published` state management for all markers
- Handles marker selection, hovering, and deletion
- Manages marker highlighting and movement
- Converts markers to paths for screenshot capture

**Marker Protocol (`Drawing/Marker.swift`)**
- Core protocol for all drawable elements
- Defines common interface: `draw()`, `getRepresentation()`, `offsetMarkerBy()`
- Includes highlighting functionality
- Supports different marker types via `MarkerRepresentation` enum

### 4. Pointer Tools System

**PointerTool Protocol (`Pointer Tool/PointerTool.swift`)**
- Defines interface for all annotation tools
- Lifecycle methods: `beginMarker()`, `updateMarker()`, `endMarker()`
- Rendering: `drawMarker()`, `renderAccessoryView()`
- Four tool types: Freehand, Line, Arrow, Text

**Specific Tools:**
- `FreehandPointerTool`: Draws smooth curves with path simplification
- `ArrowPointerTool`: Creates arrow shapes with calculated geometry
- `LinePointerTool`: Draws straight lines
- `TextPointerTool`: Places text with accessory view for input

**ToolsManager (`Toolbar/ToolsManager.swift`)**
- Manages currently selected tool and colors
- Handles tool switching and color changes
- Maintains tool state and configuration

### 5. Canvas and Interaction

**AnnotationCanvas (`Annotation/AnnotationCanvas.swift`)**
- Handles drag gestures for drawing
- Manages drawing vs moving states
- Coordinates with pointer tools for annotation creation

**PointerToolView (`Pointer Tool/PointerToolView.swift`)**
- Overlay view for handling user interactions
- Processes clicks, drags, and hover events
- Bridges between UI events and tool actions

### 6. Screenshot System

**Screenshot Capture (`Screenshot/`)**
- `CaptureScreenshotBounds`: Calculates bounding box for capture
- `CaptureScreenshotCanvas`: Renders final screenshot
- `Pasteboard+CGImage`: Handles pasteboard image operations

### 7. Hit Detection

**Hit Detection System (`hit detection/`)**
- `HitDetection`: Core hit testing functionality
- `BoundingBox`: Geometric calculations for marker bounds
- `MarkerHighlight`: Visual feedback for selected markers

## Key Features

### Annotation Tools
- **Freehand Drawing**: Smooth curve drawing with path simplification
- **Arrows**: Geometric arrow shapes with shaft and head
- **Lines**: Straight line drawing
- **Text**: Text placement with custom input interface

### Marker Management
- **Selection**: Click to select markers for editing
- **Movement**: Drag selected markers to new positions
- **Deletion**: Delete key removes selected markers
- **Highlighting**: Visual feedback for hovered/selected markers

### Canvas Operations
- **Image Import**: Paste images from clipboard
- **Screenshot Export**: Copy annotated content to clipboard
- **Keyboard Shortcuts**: Cmd+C (copy), Cmd+V (paste)

## Technical Details

### State Management
- Uses `@ObservableObject` for reactive state management
- Environment objects for dependency injection
- Published properties for UI updates

### Rendering
- SwiftUI Canvas for high-performance drawing
- Custom drawing protocols for extensibility
- Path-based geometry for scalable graphics

### Interaction Handling
- Gesture recognizers for drawing operations
- Custom keyboard command system
- Tool-specific interaction patterns

## Development Notes

### Current Limitations
- Text editing is not fully implemented
- Some tools are work-in-progress
- Keyboard shortcut system needs improvement

### Architecture Strengths
- Clean separation of concerns
- Protocol-based tool system
- Extensible marker system
- Reactive state management

### File Structure
```
capturescu/
├── capturescuApp.swift          # Main app entry point
├── ContentView.swift            # Main UI coordinator
├── Annotation/                  # Annotation canvas and tools
├── Drawing/                     # Core drawing system and markers
├── Pointer Tool/                # Tool implementations
├── Toolbar/                     # UI toolbar and tool management
├── Screenshot/                  # Screenshot capture system
├── Utils/                       # Utility extensions and helpers
├── hit detection/               # Hit testing system
└── old drawable tools/          # Legacy code (deprecated)
```

## Usage Commands

### Building
```bash
# Build the project
xcodebuild -project capturescu.xcodeproj -scheme capturescu build
```

### Running
```bash
# Run from Xcode or build and run the app bundle
open capturescu.app
```

### Keyboard Shortcuts
- `Cmd+C`: Copy annotated screenshot to clipboard
- `Cmd+V`: Paste image from clipboard
- `a`: Select arrow tool
- `f`: Select freehand tool
- `l`: Select line tool
- `t`: Select text tool
- `Delete`: Delete selected marker