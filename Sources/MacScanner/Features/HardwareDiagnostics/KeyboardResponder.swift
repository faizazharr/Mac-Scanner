// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import SwiftUI
import AppKit

/// Key definition for Apple Mac keyboard layout.
struct KeyDef: Identifiable, Hashable {
    let id: String
    let label: String
    let sub: String?
    let keyCode: UInt16
    let widthRatio: CGFloat

    init(_ id: String, _ label: String, sub: String? = nil, code: UInt16, width: CGFloat = 1.0) {
        self.id = id
        self.label = label
        self.sub = sub
        self.keyCode = code
        self.widthRatio = width
    }
}

/// Native focusable NSView that intercepts keyboard events cleanly and safely.
final class KeyboardResponderNSView: NSView {
    var onKeyDown: ((UInt16, NSEvent.ModifierFlags, String?) -> Void)?
    var onKeyUp: ((UInt16) -> Void)?
    var onFlagsChanged: ((UInt16, NSEvent.ModifierFlags) -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            window?.makeFirstResponder(self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event.keyCode, event.modifierFlags, event.charactersIgnoringModifiers)
    }

    override func keyUp(with event: NSEvent) {
        onKeyUp?(event.keyCode)
    }

    override func flagsChanged(with event: NSEvent) {
        onFlagsChanged?(event.keyCode, event.modifierFlags)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown {
            keyDown(with: event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// SwiftUI wrapper for KeyboardResponderNSView using standard AppKit Coordinator pattern.
struct KeyboardResponderRepresentable: NSViewRepresentable {
    @ObservedObject var engine: DeviceTestingEngine

    func makeCoordinator() -> Coordinator {
        Coordinator(engine: engine)
    }

    func makeNSView(context: Context) -> KeyboardResponderNSView {
        let view = KeyboardResponderNSView()
        view.onKeyDown = { [weak coordinator = context.coordinator] code, flags, chars in
            coordinator?.engine.handleKeyDown(code: code, flags: flags, chars: chars)
        }
        view.onKeyUp = { [weak coordinator = context.coordinator] code in
            coordinator?.engine.handleKeyUp(code: code)
        }
        view.onFlagsChanged = { [weak coordinator = context.coordinator] code, flags in
            coordinator?.engine.handleFlagsChanged(code: code, flags: flags)
        }
        return view
    }

    func updateNSView(_ nsView: KeyboardResponderNSView, context: Context) {
        context.coordinator.engine = engine
    }

    final class Coordinator {
        var engine: DeviceTestingEngine
        init(engine: DeviceTestingEngine) {
            self.engine = engine
        }
    }
}
