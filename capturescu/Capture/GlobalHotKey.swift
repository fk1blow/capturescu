//
//  GlobalHotKey.swift
//  capturescu
//
//  Thin wrapper around the Carbon RegisterEventHotKey API. This gives us a
//  system-wide hotkey that fires even when Capturescu isn't the frontmost
//  app, without needing the Accessibility / Input Monitoring permission that
//  NSEvent global monitors require. Works under the App Sandbox.
//

import AppKit
import Carbon.HIToolbox

/// Default capture hotkey: Meh+G (⌃⌥⇧G). The "Meh" combo (Control+Option+Shift,
/// no Command) almost never collides with system or app shortcuts.
enum CaptureHotKey {
    static let keyCode = UInt32(kVK_ANSI_G)
    static let modifiers = UInt32(controlKey | optionKey | shiftKey)
}

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let callback: () -> Void

    // Four-char code 'CPSC' used as the hotkey signature.
    private static let signature = OSType(0x4350_5343)

    init(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        self.callback = callback
        register(keyCode: keyCode, modifiers: modifiers)
    }

    private func register(keyCode: UInt32, modifiers: UInt32) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // The C handler must be a non-capturing function pointer; recover `self`
        // from the userData pointer we pass in.
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                hotKey.callback()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        let hotKeyID = EventHotKeyID(signature: GlobalHotKey.signature, id: 1)
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}
