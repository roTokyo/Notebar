//
//  ContentView.swift
//  Notebar
//
//  Created by Jay Stakelon on 1/1/21.
//

import SwiftUI
import MbSwiftUIFirstResponder

extension NSTextView {
    open override var frame: CGRect {
        didSet {
            backgroundColor = .clear //<<here clear
            drawsBackground = true
        }
    }
}

enum FirstResponders: Int {
    case textEditor
}

struct ContentView: View {
    private var placeholder: String = "hello there"
    @State var firstResponder: FirstResponders? = FirstResponders.textEditor
    @ObservedObject var themeManager = ThemeManager()
    @ObservedObject var textManager = TextManager()
    @ObservedObject var shortcutManager: ShortcutManager

    init(shortcutManager: ShortcutManager) {
        self.shortcutManager = shortcutManager
    }
    
    func clearText() {
        textManager.text = ""
    }

    /// Saves the current note as a plain text file inside ~/Documents/Notebar Notes/.
    func saveToFile() {
        let text = textManager.text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            showSaveError("Non riesco a trovare la cartella Documenti.")
            return
        }
        let folderURL = documentsURL.appendingPathComponent("Notebar Notes", isDirectory: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let fileURL = folderURL.appendingPathComponent("Nota \(formatter.string(from: Date())).txt")

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            NSSound(named: "Glass")?.play()
        } catch {
            showSaveError(error.localizedDescription)
        }
    }

    private func showSaveError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Impossibile salvare su Notes"
        alert.informativeText = message
        alert.runModal()
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                HeaderView(themeManager: themeManager, shortcutManager: shortcutManager, onClear: clearText, onSaveToNotes: saveToFile)
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $textManager.text)
                        .firstResponder(id: FirstResponders.textEditor, firstResponder: $firstResponder)
                        .font(Font.system(.body, design: .monospaced))
                        .padding(.leading, -5)
                        .foregroundColor(themeManager.textColor)
                    if (textManager.text == "") {
                        Text(placeholder)
                            .font(Font.system(.body, design: .monospaced))
                            .foregroundColor(themeManager.textColor)
                            .opacity(0.4)
                    }
                }.accentColor(.yellow)
                .padding(12)
                .background(themeManager.bgColor)
            }
            ZStack {
                    Color(.shadowColor)
                        .opacity(themeManager.isThemeEditor ? 0.5 : 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture {
                            themeManager.hideThemeEditor()
                            firstResponder = FirstResponders.textEditor
                        }
                        .animation(.easeOut(duration: 0.25))
                    ThemeEditorView(themeManager: themeManager)
                        .frame(width: 240, height: 240)
                        .offset(y: themeManager.isThemeEditor ? 0 : 400)
                        .animation(.easeOut(duration: 0.25))
            }
        }
        .background(Color(.windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: AppDelegate.didOpenNotification)) { _ in
            firstResponder = FirstResponders.textEditor
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(shortcutManager: ShortcutManager())
    }
}
