# Streamen feature TODO

Ideas queued for later. Rebrand cleanup lives in `REBRAND_TODO.md`.

## Mac app: more up-to-date look

Already done: glass Live TV category panel with a collapse button, hover
effects on posters, tiles and channel rows, and the Go menu (⌘1–⌘5, ⌘F).
Tried and dropped: an app-wide sidebar in place of the top tab bar (the
glass tab bar is preferred).

- [x] **Settings in its own window.** Tried and dropped: the sheet is
      preferred. (Note if revisited: the system `Settings` scene centres its
      toolbar, so a back button lands mid-bar; use an ordinary `Window`.)
- [x] **Artwork under the glass.** Done by macOS itself: content already runs
      under the toolbar, which frosts it (the "scroll edge"), in a window and
      in full screen. Only the window title was hidden. Don't hide the toolbar
      background (`toolbarBackgroundVisibility(.hidden, for: .windowToolbar)`):
      it makes the band fully clear in a window but turns full screen into a
      solid grey bar.
- [x] **Playback menu.** Done: the player's shortcuts as a Playback menu,
      driven from the focused player window. Later: Audio / Subtitles track
      submenus and Picture in Picture.
- [ ] **Player window polish.** Glass playback controls in the Apple TV app
      style.
- [ ] **New menu strings.** Build once in Xcode so the Go menu's titles
      ("Go", "Live TV", …) land in `Localizable.xcstrings`, then commit it.
