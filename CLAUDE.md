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

**NewDrawingSurfaceView (`Drawing/NewDrawingSurfaceView.swift`)**
- Main canvas using SwiftUI Canvas with event-driven architecture
- Renders captured images and all markers
- Observes current active tool for real-time updates via `@Observable`
- Uses "pen and paper" metaphor: Canvas observes what's being drawn on it
- Integrates with EventManager for tool coordination

**MarkersManager (`Drawing/MarkersManager.swift`)**
- `@Published` state management for all markers
- Handles marker selection, hovering, and deletion
- Manages marker highlighting and movement
- Converts markers to paths for screenshot capture
- Integrates with command pattern for undo/redo

**Marker Protocol (`Drawing/Marker.swift`)**
- Core protocol for all drawable elements
- Defines common interface: `draw()`, `getRepresentation()`, `offsetMarkerBy()`
- Includes highlighting functionality
- Supports different marker types via `MarkerRepresentation` enum

### 4. Event-Driven Pointer Tools System

**Event Architecture (`Pointer Tool/PointerEvent.swift`)**
- Centralized event system for all tool interactions
- Events: `click`, `dragStart`, `dragUpdate`, `dragEnd`, `hover`, `keyPressed`
- Tool responses with commands for state changes
- Clean separation between UI events and tool logic

**EventManager (`Pointer Tool/EventManager.swift`)**
- Central coordinator for event dispatching and tool management
- Manages current active tool and tool switching
- Executes commands through HistoryManager for undo/redo
- Provides `currentActiveTool` for Canvas observation
- Bridges between event system and existing managers

**NewPointerTool Protocol (`Pointer Tool/NewPointerTool.swift`)**
- Modern event-driven interface for annotation tools
- Methods: `handleEvent()`, `renderPreview()`, `reset()`
- All tools are `@Observable` for automatic Canvas updates
- Supports complex interactions and state management

**Tool Implementations:**
- `NewFreehandPointerTool`: Real-time curve drawing with path building
- `NewLinePointerTool`: Interactive line drawing with preview
- `NewArrowPointerTool`: Arrow creation with geometric calculations
- `NewTextPointerTool`: Text placement with accessory view management
- `NewSelectionTool`: Marker selection and editing capabilities

**ToolsManager (`Toolbar/ToolsManager.swift`)**
- Manages currently selected tool and colors (legacy compatibility)
- Handles tool switching and color changes
- Maintains tool state and configuration
- Bridges with new event system

### 5. Canvas and Interaction

**Canvas Synchronization Pattern**
- All tools are `@Observable` classes
- Canvas observes `eventManager.currentActiveTool`
- SwiftUI automatically redraws when tool state changes
- Real-time preview during drawing operations
- Follows physical "pen and paper" metaphor

**Command Pattern Integration**
- All state changes go through command objects
- Commands are executed via `HistoryManager.shared`
- Supports undo/redo functionality
- Clean separation between UI actions and state changes

**Interaction Flow**
1. User interaction → `newPointerToolView()` gesture handlers
2. Gestures → `PointerEvent` objects
3. Events → `EventManager.handleEvent()`
4. EventManager → Current tool's `handleEvent()`
5. Tool → `ToolResponse` with commands
6. Commands → `HistoryManager.execute()`
7. State changes → Canvas redraw via `@Observable`

### 6. Screenshot System

**Screenshot Capture (`Screenshot/`)**
- `CaptureScreenshotBounds`: Calculates bounding box for capture
- `ScreenshotRenderCanvas`: Renders final screenshot with dual coordinate system
- `Pasteboard+CGImage`: Handles pasteboard image operations with format support

### 7. HiDPI/Image Handling System

**HiDPI Detection & Scaling (`ContentView.swift`)**
- **Metadata-based Detection**: Reads DPI information from image metadata (144 DPI = 0.5 scale)
- **Multi-format Support**: Handles PNG, TIFF, JPEG, HEIC, WebP with unified processing
- **Fallback Mechanisms**: Multiple detection methods with dimension-based heuristics
- **Performance Caching**: Metadata detection results cached for repeated operations

**Dual Coordinate System**
- **Display Coordinates**: How images appear in the app UI (`displaySize`)
- **Capture Coordinates**: How images are rendered for clipboard export
- **Consistent Scaling**: Uses `displaySize` throughout pipeline to prevent double-scaling

**Image Format Support (`Pasteboard+CGImage.swift`)**
- **Multiple Formats**: PNG (preferred), TIFF, JPEG, HEIC, WebP
- **Metadata Preservation**: DPI information preserved through copy/paste cycles
- **Format Detection**: Automatic fallback chain for unsupported formats
- **Validation**: Size limits and dimension checking for security

**Multi-Monitor Support (`WindowStyleModifier.swift`)**
- **Per-Screen Scaling**: Window sizing adapts to current monitor DPI
- **Dynamic Adjustment**: Automatic recalculation when moving between displays
- **Smooth Startup**: Conditional window resizing prevents shaking

### 8. Hit Detection

**Hit Detection System (`hit detection/`)**
- `HitDetection`: Core hit testing functionality
- `BoundingBox`: Geometric calculations for marker bounds
- `MarkerHighlight`: Visual feedback for selected markers

### 9. Command Pattern & History

**HistoryManager (`HistoryManager.swift`)**
- Manages undo/redo operations with command pattern
- Executes commands and maintains history stack
- Integrates with EventManager for state management

**Command Types:**
- `AddMarkerCommand`: Adds new markers to MarkersManager
- `UpdateMarkerCommand`: Updates existing markers
- `DeleteMarkerCommand`: Removes markers
- Commands are reversible for undo/redo functionality

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
- **Image Import**: Paste images from clipboard with automatic HiDPI detection
- **Screenshot Export**: Copy annotated content to clipboard with metadata preservation
- **Keyboard Shortcuts**: Cmd+C (copy), Cmd+V (paste)

### HiDPI & Image Quality
- **Natural Size Rendering**: macOS screenshots display at correct natural size
- **Metadata Preservation**: DPI information maintained through copy/paste cycles
- **Multi-Format Support**: PNG, TIFF, JPEG, HEIC, WebP with automatic format detection
- **Quality Consistency**: No blur or size changes across multiple copy operations
- **Multi-Monitor**: Automatic adaptation to different screen DPI settings

## Technical Details

### State Management
- Uses `@ObservableObject` for reactive state management
- Environment objects for dependency injection
- `@Observable` tools for automatic Canvas updates
- Published properties for UI updates
- Command pattern for state changes and undo/redo

### Rendering
- SwiftUI Canvas for high-performance drawing
- Real-time preview via `@Observable` tool states
- Canvas observes current active tool for automatic updates
- Path-based geometry for scalable graphics
- "Pen and paper" metaphor: Canvas feels what's being drawn

### Interaction Handling
- Event-driven architecture with centralized event processing
- Gesture recognizers convert UI interactions to events
- EventManager coordinates between events and tools
- Tool-specific event handling with command responses
- Command pattern ensures consistent state management

### Canvas Synchronization
- All tools implement `@Observable` for SwiftUI reactivity
- Canvas accesses `eventManager.currentActiveTool` for observation
- SwiftUI automatically redraws when tool state changes
- No manual Canvas invalidation needed
- Scalable pattern that works with any number of tools

### HiDPI/Image Processing
- **Metadata-Based Detection**: Uses `kCGImagePropertyDPIWidth` for accurate scale detection
- **Dual Coordinate System**: Separates display coordinates from capture coordinates
- **Consistent Sizing**: Uses `displaySize` throughout to prevent double-scaling
- **Format Abstraction**: Unified handling of multiple image formats with fallback chain
- **Performance Caching**: Metadata detection results cached with automatic cleanup
- **Error Resilience**: Multiple fallback mechanisms for corrupted or missing metadata

## Development Notes

### Current Status
- **Completed**: Event-driven architecture with Canvas synchronization
- **Completed**: HiDPI/image handling system with metadata preservation
- **Working**: Freehand, Line, Arrow tools with real-time preview
- **Working**: Multi-format image support with automatic scaling
- **In Progress**: Text tool refinement and marker editing
- **Todo**: Keyboard shortcut system improvements

### Architecture Strengths
- **Event-driven design**: Clean separation between UI and tool logic
- **Canvas synchronization**: Automatic updates via `@Observable` pattern
- **Command pattern**: Robust undo/redo with reversible operations
- **Scalable tool system**: Adding new tools requires minimal changes
- **Reactive state management**: SwiftUI handles all UI updates automatically
- **Physical metaphor**: "Pen and paper" design feels natural to users
- **HiDPI robustness**: Metadata-based scaling with multiple fallback mechanisms
- **Format flexibility**: Unified image handling across multiple formats

### Design Principles
- **Pen and Paper Metaphor**: Canvas observes what's being drawn on it
- **Single Responsibility**: Each component has a clear, focused purpose
- **Observer Pattern**: Canvas automatically updates when tool state changes
- **Command Pattern**: All state changes are reversible and trackable
- **Event-Driven**: UI interactions become events that tools can handle

### Adding New Tools

To add a new drawing tool, follow this pattern:

1. **Create the tool class**:
```swift
@Observable class NewMyPointerTool: NewPointerTool {
    let toolName = PointerToolName.MyTool
    
    // Make drawing state public for Canvas observation
    var drawingState: SomeState?
    var isDrawing = false
    
    func handleEvent(_ event: PointerEvent) -> ToolResponse {
        // Handle events and return commands
    }
    
    func renderPreview(context: GraphicsContext) {
        // Draw current state preview
    }
}
```

2. **Register in EventManager**:
```swift
// Add tool instance to EventManager init
self.myTool = NewMyPointerTool(...)

// Add to tool switching logic
case .myTool:
    currentTool = myTool
```

3. **Canvas automatically observes**: No changes needed! The Canvas observes `currentActiveTool` and will automatically update when your tool's `@Observable` state changes.

**Key Requirements**:
- ✅ Must be `@Observable` class
- ✅ Drawing state must be `var` (not `private`)
- ✅ Handle events and return commands
- ✅ Implement `renderPreview()` for real-time drawing

### File Structure
```
capturescu/
├── capturescuApp.swift          # Main app entry point
├── ContentView.swift            # Main UI coordinator
├── Drawing/                     # Core drawing system and markers
│   ├── DrawingSurfaceView.swift # Legacy canvas (deprecated)
│   ├── NewDrawingSurfaceView.swift # Event-driven canvas with @Observable
│   ├── DrawingMarker.swift      # Drawable marker implementation
│   └── MarkersManager.swift     # Marker state management
├── Pointer Tool/                # Event-driven tool implementations
│   ├── PointerEvent.swift       # Event definitions and responses
│   ├── EventManager.swift       # Central event coordinator
│   ├── NewPointerTool.swift     # Modern tool protocol
│   ├── NewFreehandPointerTool.swift # Freehand drawing tool
│   ├── NewLinePointerTool.swift # Line drawing tool
│   ├── NewArrowPointerTool.swift # Arrow drawing tool
│   ├── NewTextPointerTool.swift # Text placement tool
│   └── NewSelectionTool.swift   # Marker selection tool
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