# Streamen feature TODO

Ideas queued for later. Rebrand cleanup lives in `REBRAND_TODO.md`.

## Mac app: more up-to-date look

Already done: glass Live TV category panel with a collapse button, hover
effects on posters, tiles and channel rows, and the Go menu (⌘1–⌘5, ⌘F).
Tried and dropped: an app-wide sidebar in place of the top tab bar (the
glass tab bar is preferred).

- [ ] **Settings in its own window.** Open with ⌘, like other Mac apps,
      instead of the toolbar sheet.
- [x] **Artwork under the glass.** Done by macOS itself: content already runs
      under the toolbar, which frosts it (the "scroll edge"), in a window and
      in full screen. Only the window title was hidden. Don't hide the toolbar
      background (`toolbarBackgroundVisibility(.hidden, for: .windowToolbar)`):
      it makes the band fully clear in a window but turns full screen into a
      solid grey bar.
- [ ] **Playback menu.** Play/Pause, skip ±10s, next/previous channel and
      similar commands with shortcuts, driven from the focused player window.
- [ ] **Player window polish.** Glass playback controls in the Apple TV app
      style.
- [ ] **New menu strings.** Build once in Xcode so the Go menu's titles
      ("Go", "Live TV", …) land in `Localizable.xcstrings`, then commit it.
