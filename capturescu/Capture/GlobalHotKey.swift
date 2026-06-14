//
//  GlobalHotKey.swift
//  capturescu
//
//  System-wide hotkeys via the Carbon RegisterEventHotKey API. These fire even
//  when Capturescu isn't frontmost, without the Accessibility / Input Monitoring
//  permission that NSEvent global monitors require, and work under the App Sandbox.
//
//  HotKeyCenter installs a SINGLE app event handler and dispatches to per-hotkey
//  callbacks by id — registering one handler per hotkey would mis-fire (the most
//  recently installed handler swallows the event for all hotkeys).
//

import AppKit
import Carbon.HIToolbox

/// Capture hotkey: Meh+G (⌃⌥⇧G). The "Meh" combo (Control+Option+Shift, no
/// Command) almost never collides with system or app shortcuts.
enum CaptureHotKey {
    static let keyCode = UInt32(kVK_ANSI_G)
    static let modifiers = UInt32(controlKey | optionKey | shiftKey)
}

/// Reopen-last-snapshot hotkey: Meh+Z (⌃⌥⇧Z).
enum ReopenHotKey {
    static let keyCode = UInt32(kVK_ANSI_Z)
    static let modifiers = UInt32(controlKey | optionKey | shiftKey)
}

final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var callbacks: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlerInstalled = false

    // Four-char code 'CPSC' used as the hotkey signature.
    private static let signature = OSType(0x4350_5343)

    private init() {}

    /// Register a system-wide hotkey. `id` must be unique per hotkey.
    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        installHandlerIfNeeded()
        callbacks[id] = callback

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: HotKeyCenter.signature, id: id)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        refs[id] = ref
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, eventRef, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if status == noErr {
                    HotKeyCenter.shared.dispatch(id: hotKeyID.id)
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }

    private func dispatch(id: UInt32) {
        callbacks[id]?()
    }
}
