//
//  HeaderView.swift
//  Notebar
//
//  Created by Jay Stakelon on 1/30/21.
//
import SwiftUI
struct HeaderView: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var shortcutManager: ShortcutManager
    var onClear: () -> Void
    var onSaveToNotes: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(shortcutManager.isRecording ? "Premi la combinazione (Esc annulla)" : "Notebar")
                    .font(Font.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(shortcutManager.isRecording ? .orange : .primary)
                    .lineLimit(1)
                Spacer()
                Button(action: onClear) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .keyboardShortcut("k", modifiers: .command)
                .help("Clear (⌘K)")

                Button(action: onSaveToNotes) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .keyboardShortcut("s", modifiers: .command)
                .help("Salva come file (⌘S)")

                DropdownMenuView(themeManager: themeManager, shortcutManager: shortcutManager).frame(width: 24, height: 24)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            Divider().background(Color.gray.opacity(0.1))
        }.background(Color(.windowBackgroundColor))
    }
}
