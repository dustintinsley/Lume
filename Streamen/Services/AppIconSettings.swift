//
//  AppIconSettings.swift
//  Streamen
//
//  The user's app icon choice (Dark / Light / Automatic). Dark is the primary
//  icon (`Streamen.icon`); Light pins the light artwork, and Automatic swaps
//  between the two with the device's appearance.
//
//  iOS swaps the home-screen icon through the alternate-icon API — the
//  `StreamenLight` / `StreamenAutomatic` app icon sets, listed for the iPhone
//  SDK in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`. macOS has no
//  alternate icons, so the Mac sets the Dock icon while Streamen runs; Finder
//  and the Dock at rest keep the primary icon. Not offered on tvOS, whose
//  layered icon is the dark artwork and whose UI is pinned dark.
//

import SwiftUI
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

enum AppIconChoice: String, CaseIterable, Identifiable {
    case dark
    case light
    case automatic

    static let storageKey = "app.icon"
    static let defaultValue: AppIconChoice = .dark

    /// Resolves a persisted raw value, falling back to `dark` for
    /// missing or unknown values.
    static func resolve(_ raw: String) -> AppIconChoice {
        AppIconChoice(rawValue: raw) ?? defaultValue
    }

    var id: String {
        rawValue
    }

    var title: LocalizedStringKey {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        case .automatic: "Automatic"
        }
    }

    /// The alternate app icon set's name; nil is the primary icon.
    var alternateIconName: String? {
        switch self {
        case .dark: nil
        case .light: "StreamenLight"
        case .automatic: "StreamenAutomatic"
        }
    }

    /// The flat artwork, for the picker's previews and the Mac's Dock icon;
    /// Automatic draws the one matching `scheme`.
    func artworkName(for scheme: ColorScheme = .light) -> String {
        switch self {
        case .dark: "AppIconArtDark"
        case .light: "AppIconArtLight"
        case .automatic: scheme == .dark ? "AppIconArtDark" : "AppIconArtLight"
        }
    }
}

extension View {
    /// Keeps the app icon in step with the user's choice. No-op on tvOS.
    func appIcon(_ choice: AppIconChoice) -> some View {
        modifier(AppIconModifier(choice: choice))
    }
}

/// Applies the choice, and on the Mac re-applies Automatic when the
/// appearance flips (iOS swaps an Automatic icon by itself).
private struct AppIconModifier: ViewModifier {
    let choice: AppIconChoice
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .onChange(of: choice, initial: true) { _, newValue in
                AppIconApplier.apply(newValue, scheme: colorScheme)
            }
            .onChange(of: colorScheme) { _, newValue in
                if choice == .automatic { AppIconApplier.apply(choice, scheme: newValue) }
            }
    }
}

@MainActor
enum AppIconApplier {
    static func apply(_ choice: AppIconChoice, scheme: ColorScheme) {
        #if os(iOS)
            let app = UIApplication.shared
            guard app.supportsAlternateIcons, app.alternateIconName != choice.alternateIconName else { return }
            app.setAlternateIconName(choice.alternateIconName)
        #elseif os(macOS)
            // The bundle's own icon is the dark one; nil hands the Dock back to it.
            let name = choice.artworkName(for: scheme)
            NSApp.applicationIconImage = name == AppIconChoice.dark.artworkName() ? nil : dockIcon(named: name)
        #endif
    }

    #if os(macOS)
        /// The artwork on the macOS icon grid: an 824pt rounded square centred
        /// in a 1024pt canvas, as the system draws app icons in the Dock.
        private static func dockIcon(named name: String) -> NSImage? {
            guard let art = NSImage(named: name) else { return nil }
            let canvas = NSSize(width: 1024, height: 1024)
            return NSImage(size: canvas, flipped: false) { _ in
                let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
                NSGraphicsContext.saveGraphicsState()
                let shadow = NSShadow()
                shadow.shadowColor = .black.withAlphaComponent(0.3)
                shadow.shadowOffset = NSSize(width: 0, height: -10)
                shadow.shadowBlurRadius = 20
                shadow.set()
                let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
                NSColor.black.setFill()
                shape.fill()
                NSGraphicsContext.restoreGraphicsState()
                shape.addClip()
                art.draw(in: tile)
                return true
            }
        }
    #endif
}
