//
//  KeyableBorderlessWindow.swift
//  capturescu
//
//  A borderless NSWindow that is still allowed to become key/main.
//  Borderless windows refuse key status by default, which breaks mouse
//  tracking on the selection overlay and text/Canvas input on the
//  annotation window. Overriding these flags fixes both.
//

import AppKit

final class KeyableBorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
