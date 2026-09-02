// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// Catalog of Apple standard hardware keyboard layouts and key definitions.
///
/// Contains predefined rows matching the standard Mac ANSI layout, including
/// special function row keys, modifiers, alphanumeric clusters, and navigation arrows.
enum KeyboardLayoutCatalog {

    /// Apple Mac Function Row (F1 through F12, Escape, and Power/Eject key).
    static let functionRow: [KeyDef] = [
        KeyDef("ESC", "esc", code: 53, width: 1.3),
        KeyDef("F1", "F1", sub: "🔅", code: 122),
        KeyDef("F2", "F2", sub: "🔆", code: 120),
        KeyDef("F3", "F3", sub: "🪟", code: 99),
        KeyDef("F4", "F4", sub: "🔍", code: 118),
        KeyDef("F5", "F5", sub: "🎙️", code: 96),
        KeyDef("F6", "F6", sub: "🌙", code: 97),
        KeyDef("F7", "F7", sub: "⏮", code: 98),
        KeyDef("F8", "F8", sub: "⏯", code: 100),
        KeyDef("F9", "F9", sub: "⏭", code: 101),
        KeyDef("F10", "F10", sub: "🔇", code: 109),
        KeyDef("F11", "F11", sub: "🔉", code: 103),
        KeyDef("F12", "F12", sub: "🔊", code: 111),
        KeyDef("PWR", "⏻", code: 108, width: 1.3)
    ]

    /// Top number row including tilde, digits 1-0, symbols, and Backspace/Delete.
    static let numberRow: [KeyDef] = [
        KeyDef("Tilde", "`", sub: "~", code: 50),
        KeyDef("1", "1", sub: "!", code: 18),
        KeyDef("2", "2", sub: "@", code: 19),
        KeyDef("3", "3", sub: "#", code: 20),
        KeyDef("4", "4", sub: "$", code: 21),
        KeyDef("5", "5", sub: "%", code: 23),
        KeyDef("6", "6", sub: "^", code: 22),
        KeyDef("7", "7", sub: "&", code: 26),
        KeyDef("8", "8", sub: "*", code: 28),
        KeyDef("9", "9", sub: "(", code: 25),
        KeyDef("0", "0", sub: ")", code: 29),
        KeyDef("Minus", "-", sub: "_", code: 27),
        KeyDef("Equal", "=", sub: "+", code: 24),
        KeyDef("Delete", "delete", code: 51, width: 1.6)
    ]

    /// QWERTY alpha row including Tab and bracket delimiters.
    static let qwertyRow: [KeyDef] = [
        KeyDef("Tab", "tab", code: 48, width: 1.5),
        KeyDef("Q", "Q", code: 12),
        KeyDef("W", "W", code: 13),
        KeyDef("E", "E", code: 14),
        KeyDef("R", "R", code: 15),
        KeyDef("T", "T", code: 17),
        KeyDef("Y", "Y", code: 16),
        KeyDef("U", "U", code: 32),
        KeyDef("I", "I", code: 34),
        KeyDef("O", "O", code: 31),
        KeyDef("P", "P", code: 35),
        KeyDef("LBracket", "[", sub: "{", code: 33),
        KeyDef("RBracket", "]", sub: "}", code: 30),
        KeyDef("Backslash", "\\", sub: "|", code: 42, width: 1.2)
    ]

    /// Home row (ASDF) including Caps Lock and Return/Enter.
    static let asdfRow: [KeyDef] = [
        KeyDef("Caps", "caps lock", code: 57, width: 1.8),
        KeyDef("A", "A", code: 0),
        KeyDef("S", "S", code: 1),
        KeyDef("D", "D", code: 2),
        KeyDef("F", "F", code: 3),
        KeyDef("G", "G", code: 5),
        KeyDef("H", "H", code: 4),
        KeyDef("J", "J", code: 38),
        KeyDef("K", "K", code: 40),
        KeyDef("L", "L", code: 37),
        KeyDef("Semicolon", ";", sub: ":", code: 41),
        KeyDef("Quote", "'", sub: "\"", code: 39),
        KeyDef("Return", "return", code: 36, width: 1.8)
    ]

    /// Bottom letter row (ZXCV) with Left and Right Shift keys.
    static let zxcvRow: [KeyDef] = [
        KeyDef("Shift_L", "shift", code: 56, width: 2.2),
        KeyDef("Z", "Z", code: 6),
        KeyDef("X", "X", code: 7),
        KeyDef("C", "C", code: 8),
        KeyDef("V", "V", code: 9),
        KeyDef("B", "B", code: 11),
        KeyDef("N", "N", code: 45),
        KeyDef("M", "M", code: 46),
        KeyDef("Comma", ",", sub: "<", code: 43),
        KeyDef("Dot", ".", sub: ">", code: 47),
        KeyDef("Slash", "/", sub: "?", code: 44),
        KeyDef("Shift_R", "shift", code: 60, width: 2.2)
    ]

    /// Bottom modifier row: Fn, Control, Option, Command, Spacebar, and Arrow keys.
    static let bottomRow: [KeyDef] = [
        KeyDef("Fn", "fn 🌐", code: 63, width: 1.1),
        KeyDef("Ctrl_L", "control", code: 59, width: 1.1),
        KeyDef("Opt_L", "option", code: 58, width: 1.1),
        KeyDef("Cmd_L", "command", code: 55, width: 1.4),
        KeyDef("Space", "", code: 49, width: 5.5),
        KeyDef("Cmd_R", "command", code: 54, width: 1.4),
        KeyDef("Opt_R", "option", code: 61, width: 1.1),
        KeyDef("Arrow_L", "◀", code: 123, width: 0.9),
        KeyDef("Arrow_UD", "▲/▼", code: 126, width: 0.9),
        KeyDef("Arrow_R", "▶", code: 124, width: 0.9)
    ]

    /// Total count of all standard physical keys present across all 6 rows.
    static var totalStandardKeyCount: Int {
        functionRow.count + numberRow.count + qwertyRow.count + asdfRow.count + zxcvRow.count + bottomRow.count
    }
}
