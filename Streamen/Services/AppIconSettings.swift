//
//  AppIconSettings.swift
//  Streamen
//
//  The user's app icon choice: one of twelve colourways. Midnight is the
//  primary icon (`Streamen.icon`); every other colourway is an alternate icon
//  set (`Streamen<Name>`). All of them are rendered from the same vector logo
//  at every size, so none is ever upscaled.
//
//  iOS swaps the home-screen icon through the alternate-icon API — the sets
//  listed for the iPhone SDK in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`.
//  macOS has no alternate icons, so the Mac sets the Dock icon while Streamen
//  runs; Finder and the Dock at rest keep the primary icon. Not offered on
//  tvOS, whose layered icon is Midnight and whose UI is pinned dark.
//

import SwiftUI
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

enum AppIconChoice: String, CaseIterable, Identifiable {
    // Raw values `dark` / `light` predate the colourways; kept so a saved
    // choice carries over.
    case midnight = "dark"
    case onyx, cobalt, plum, forest, ember
    case daylight = "light"
    case paper, sky, sunny, blush, mint

    static let storageKey = "app.icon"
    static let defaultValue: AppIconChoice = .midnight

    /// Light logo on a dark background.
    static let darkColorways: [AppIconChoice] = [.midnight, .onyx, .cobalt, .plum, .forest, .ember]
    /// Dark logo on a light background.
    static let lightColorways: [AppIconChoice] = [.daylight, .paper, .sky, .sunny, .blush, .mint]

    /// Resolves a persisted raw value, falling back to Midnight for missing
    /// or unknown values (including the retired `automatic`).
    static func resolve(_ raw: String) -> AppIconChoice {
        AppIconChoice(rawValue: raw) ?? defaultValue
    }

    var id: String {
        rawValue
    }

    /// The colourway's name, also the suffix of its asset names.
    private var assetName: String {
        switch self {
        case .midnight: "Midnight"
        case .onyx: "Onyx"
        case .cobalt: "Cobalt"
        case .plum: "Plum"
        case .forest: "Forest"
        case .ember: "Ember"
        case .daylight: "Daylight"
        case .paper: "Paper"
        case .sky: "Sky"
        case .sunny: "Sunny"
        case .blush: "Blush"
        case .mint: "Mint"
        }
    }

    var title: LocalizedStringKey {
        LocalizedStringKey(assetName)
    }

    /// The alternate app icon set's name; nil is the primary icon.
    var alternateIconName: String? {
        self == .midnight ? nil : "Streamen\(assetName)"
    }

    /// The flat artwork, for the picker's previews and the Mac's Dock icon.
    var artworkName: String {
        "AppIconArt\(assetName)"
    }
}

extension View {
    /// Keeps the app icon in step with the user's choice. No-op on tvOS.
    func appIcon(_ choice: AppIconChoice) -> some View {
        modifier(AppIconModifier(choice: choice))
    }
}

/// Applies the choice whenever it changes.
private struct AppIconModifier: ViewModifier {
    let choice: AppIconChoice

    func body(content: Content) -> some View {
        content
            .onChange(of: choice, initial: true) { _, newValue in
                AppIconApplier.apply(newValue)
            }
    }
}

@MainActor
enum AppIconApplier {
    static func apply(_ choice: AppIconChoice) {
        #if os(iOS)
            let app = UIApplication.shared
            guard app.supportsAlternateIcons, app.alternateIconName != choice.alternateIconName else { return }
            app.setAlternateIconName(choice.alternateIconName)
        #elseif os(macOS)
            // The bundle's own icon is Midnight; nil hands the Dock back to it.
            NSApp.applicationIconImage = choice == .midnight ? nil : dockIcon(named: choice.artworkName)
        #endif
    }

    /// The saved choice, read straight from defaults for use before any
    /// SwiftUI view exists.
    static var savedChoice: AppIconChoice {
        AppIconChoice.resolve(UserDefaults.standard.string(forKey: AppIconChoice.storageKey) ?? "")
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

#if os(macOS)
    /// Sets the Dock icon as early as AppKit allows. The Dock starts from the
    /// bundle's own (Midnight) icon, and `.appIcon` only runs once the first
    /// window's content appears, so a chosen colourway used to arrive about a
    /// second after launch.
    final class MacAppIconLaunchDelegate: NSObject, NSApplicationDelegate {
        func applicationWillFinishLaunching(_: Notification) {
            AppIconApplier.apply(AppIconApplier.savedChoice)
        }
    }
#endif
