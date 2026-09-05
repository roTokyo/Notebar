//
//  AppDelegate.swift
//  Notebar
//
//  Created by Jay Stakelon on 1/1/21.
//

import Cocoa
import SwiftUI
import Carbon.HIToolbox

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!
    var popover: NSPopover!
    var statusBarItem: NSStatusItem!

    // Holds the current keyboard shortcut and remembers it between launches.
    let shortcutManager = ShortcutManager()

    // Carbon hotkey used to open/close Notebar from anywhere.
    // Carbon hotkeys work system-wide WITHOUT needing the "Input Monitoring"
    // permission, unlike raw keyboard event monitors.
    var toggleHotKeyRef: EventHotKeyRef?
    var carbonEventHandler: EventHandlerRef?

    // Local monitor for Esc — only active while Notebar itself is frontmost.
    var localMonitor: Any?

    // Local monitor used only while the user is recording a new shortcut.
    var recordingMonitor: Any?

    // The app that was frontmost right before Notebar opened, so we can
    // give it focus back when Notebar closes.
    var previousApp: NSRunningApplication?

    // Notification we use to tell ContentView "put the cursor back in the text field"
    static let didOpenNotification = NSNotification.Name("NotebarDidOpen")

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView(shortcutManager: shortcutManager)

        // Make this into a menu bar app
        let popover = NSPopover()
        let vc = NSHostingController(rootView: contentView)
        popover.contentSize = NSSize(width: 436, height: 400)
        popover.behavior = .transient
        popover.contentViewController = vc
        self.popover = popover
        
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        if let button = self.statusBarItem.button {
             button.image = NSImage(named: "MenubarIcon")
             button.action = #selector(togglePopover(_:))
        }

        shortcutManager.onShortcutChanged = { [weak self] in
            self?.reregisterToggleHotKey()
        }

        installCarbonEventHandler()
        registerCarbonHotKeyOnly()
        registerEscMonitor()
    }

    // MARK: - Global toggle shortcut (Carbon)

    func installCarbonEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { (_, eventRef, userData) -> OSStatus in
            guard let eventRef = eventRef, let userData = userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if hotKeyID.id == 1 {
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                appDelegate.togglePopover(nil)
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &carbonEventHandler)
    }

    func registerCarbonHotKeyOnly() {
        let hotKeyID = EventHotKeyID(signature: fourCharCode("NbTg"), id: 1)
        RegisterEventHotKey(shortcutManager.keyCode, shortcutManager.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &toggleHotKeyRef)
    }

    func reregisterToggleHotKey() {
        if let ref = toggleHotKeyRef {
            UnregisterEventHotKey(ref)
            toggleHotKeyRef = nil
        }
        registerCarbonHotKeyOnly()
    }

    private func fourCharCode(_ string: String) -> FourCharCode {
        var result: FourCharCode = 0
        for character in string.utf16 {
            result = (result << 8) + FourCharCode(character)
        }
        return result
    }

    // MARK: - Recording a new shortcut from the menu

    func startRecordingShortcut() {
        // Stop listening for the old shortcut while we record a new one,
        // and show a little hint in the menu bar so it's clear what's happening.
        if let ref = toggleHotKeyRef {
            UnregisterEventHotKey(ref)
            toggleHotKeyRef = nil
        }
        statusBarItem.button?.title = " ⏺"
        shortcutManager.isRecording = true

        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }

            if event.keyCode == 53 { // Esc cancels, keeps the previous shortcut
                self.finishRecording()
                self.reregisterToggleHotKey()
                return nil
            }

            let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
            guard !flags.isEmpty else { return nil } // require at least one modifier key

            var carbonModifiers: UInt32 = 0
            if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
            if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
            if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
            if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }

            self.shortcutManager.set(modifiers: carbonModifiers, keyCode: UInt32(event.keyCode))
            self.finishRecording()
            return nil
        }
    }

    private func finishRecording() {
        if let monitor = recordingMonitor {
            NSEvent.removeMonitor(monitor)
            recordingMonitor = nil
        }
        statusBarItem.button?.title = ""
        shortcutManager.isRecording = false
        NSSound.beep()
    }

    // MARK: - Esc — close Notebar while it's frontmost

    func registerEscMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if event.keyCode == 53, self.popover.isShown { // 53 = Escape
                self.closePopover()
                return nil // swallow it so it doesn't do anything else
            }
            return event
        }
    }

    /// Closes the popover and hands focus back to whatever app was frontmost
    /// before Notebar opened.
    private func closePopover() {
        popover.performClose(nil)
        if let app = previousApp {
            app.activate(options: [])
        }
        previousApp = nil
    }

    // MARK: - Show/hide

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = self.statusBarItem.button {
            if self.popover.isShown {
                closePopover()
            } else {
                // Remember who had focus, so we can give it back when we close.
                previousApp = NSWorkspace.shared.frontmostApplication

                NSApp.activate(ignoringOtherApps: true)

                self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                self.popover.contentViewController?.view.window?.becomeKey()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NotificationCenter.default.post(name: AppDelegate.didOpenNotification, object: nil)
                }
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if let ref = toggleHotKeyRef { UnregisterEventHotKey(ref) }
        if let handler = carbonEventHandler { RemoveEventHandler(handler) }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = recordingMonitor { NSEvent.removeMonitor(monitor) }
    }

}
