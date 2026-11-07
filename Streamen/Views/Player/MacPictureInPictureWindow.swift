//
//  MacPictureInPictureWindow.swift
//  Streamen
//
//  Hides the macOS player window while its video plays in Picture in Picture.
//
//  Once the video moves into the PiP panel the window behind it only shows
//  AVKit's "playing in Picture in Picture" placeholder, so it steps out of the
//  way and comes back when PiP ends (the panel's return button, the player's
//  own toggle, or its close button, which leaves the stream paused).
//

import SwiftUI

#if os(macOS)
    import AppKit

    extension View {
        /// Order the player window out while `isActive`, and back in after.
        func hidesPlayerWindowDuringPictureInPicture(_ isActive: Bool) -> some View {
            modifier(PictureInPictureWindowHiding(isActive: isActive))
        }
    }

    private struct PictureInPictureWindowHiding: ViewModifier {
        let isActive: Bool

        /// Weak, so the window's own view tree does not keep it alive.
        @State private var host = WeakWindow()

        func body(content: Content) -> some View {
            content
                .background(PlayerWindowAccessor { host.window = $0 })
                .onChange(of: isActive) { _, active in
                    if active { host.hide() } else { host.restore() }
                }
        }
    }

    private final class WeakWindow {
        weak var window: NSWindow?
        private var isHidden = false

        func hide() {
            // A full-screen window owns its Space: ordering it out would leave
            // an empty Space behind, so full screen keeps the placeholder.
            guard let window, window.isVisible, !window.styleMask.contains(.fullScreen) else { return }
            isHidden = true
            window.orderOut(nil)
        }

        func restore() {
            guard isHidden, let window else { return }
            isHidden = false
            if window.isMiniaturized { window.deminiaturize(nil) }
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
        }
    }

#else

    extension View {
        /// No-op off macOS, where the player is not a window of its own.
        func hidesPlayerWindowDuringPictureInPicture(_: Bool) -> some View {
            self
        }
    }

#endif
