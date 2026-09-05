//
//  ShortcutManager.swift
//  Notebar
//
//  Stores the user's chosen open/close shortcut and remembers it between launches.
//
import Foundation
import Carbon.HIToolbox

final class ShortcutManager: ObservableObject {

    private let modifiersKey = "NotebarShortcutModifiers"
    private let keyCodeKey = "NotebarShortcutKeyCode"

    @Published private(set) var modifiers: UInt32
    @Published private(set) var keyCode: UInt32

    // True while the user is actively pressing keys to set a new shortcut.
    @Published var isRecording: Bool = false

    // AppDelegate sets this so it can re-register the system-wide shortcut
    // whenever the user picks a new one.
    var onShortcutChanged: (() -> Void)?

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: modifiersKey) != nil {
            modifiers = UInt32(defaults.integer(forKey: modifiersKey))
            keyCode = UInt32(defaults.integer(forKey: keyCodeKey))
        } else {
            // Default: ⌃⌥⌘N
            modifiers = UInt32(controlKey | optionKey | cmdKey)
            keyCode = UInt32(kVK_ANSI_N)
        }
    }

    func set(modifiers: UInt32, keyCode: UInt32) {
        self.modifiers = modifiers
        self.keyCode = keyCode
        let defaults = UserDefaults.standard
        defaults.set(Int(modifiers), forKey: modifiersKey)
        defaults.set(Int(keyCode), forKey: keyCodeKey)
        onShortcutChanged?()
    }

    /// Human-readable version, e.g. "⌃⌥⌘N", shown in the menu.
    var displayString: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        s += ShortcutManager.label(forKeyCode: keyCode)
        return s
    }

    /// Rough key-code → label mapping covering the keys people are likely to pick.
    static func label(forKeyCode keyCode: UInt32) -> String {
        let map: [UInt32: String] = [
            UInt32(kVK_Space): "Space", UInt32(kVK_Return): "↩︎", UInt32(kVK_Tab): "⇥",
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
            UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
            UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
            UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
            UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
            UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z"
        ]
        return map[keyCode] ?? "Key\(keyCode)"
    }
}
