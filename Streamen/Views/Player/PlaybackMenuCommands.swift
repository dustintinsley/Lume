//
//  PlaybackMenuCommands.swift
//  Streamen
//
//  The macOS Playback menu: the player's keyboard shortcuts as menu items,
//  so they can be found, clicked, and still reach the player when its video
//  view has lost keyboard focus. Each item runs the same command the key
//  does (`PlayerKeyboardShortcuts`); the menu greys out unless a player
//  window is in front.
//

#if os(macOS)

    import SwiftUI

    struct PlaybackMenuCommands: Commands {
        @FocusedValue(\.playerMenuTarget) private var target

        var body: some Commands {
            CommandMenu("Playback") {
                item("Play/Pause", .togglePlay, key: .space)
                Divider()
                item("Skip Back 15 Seconds", .skipBackward, key: .leftArrow)
                item("Skip Forward 15 Seconds", .skipForward, key: .rightArrow)
                Divider()
                item("Next Channel", .nextChannel, key: .upArrow, modifiers: .command, liveOnly: true)
                item("Previous Channel", .previousChannel, key: .downArrow, modifiers: .command, liveOnly: true)
                Divider()
                item("Volume Up", .volumeUp, key: .upArrow)
                item("Volume Down", .volumeDown, key: .downArrow)
                item("Mute", .toggleMute, key: "m")
                Divider()
                item("Toggle Full Screen", .toggleFullScreen, key: "f")
                item("Close Player", .close, key: .escape)
            }
        }

        private func item(
            _ title: LocalizedStringKey,
            _ command: PlayerKeyCommand,
            key: KeyEquivalent,
            modifiers: EventModifiers = [],
            liveOnly: Bool = false
        ) -> some View {
            Button(title) { target?.perform(command) }
                .keyboardShortcut(key, modifiers: modifiers)
                .disabled(target == nil || (liveOnly && target?.isLive != true))
        }
    }

#endif
