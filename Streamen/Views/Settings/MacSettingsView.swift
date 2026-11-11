//
//  MacSettingsView.swift
//  Streamen
//
//  The macOS Settings window (Streamen › Settings…, ⌘,): toolbar tabs, the
//  way Mac apps lay out their settings, in place of the iOS-style list sheet.
//  The fifteen Settings categories fold into eight tabs; a tab holding more
//  than one category switches between them with a segmented control. Every
//  page is the same SwiftUI page iOS shows (`SettingsCategoryDestination`),
//  in its own navigation stack so drill-ins keep working.
//

#if os(macOS)

    import SwiftData
    import SwiftUI

    enum MacSettingsTab: String, CaseIterable, Identifiable {
        case general, playlists, player, liveTV, sports, accounts, storage, about

        var id: String {
            rawValue
        }

        var title: LocalizedStringKey {
            switch self {
            case .general: "General"
            case .playlists: "Playlists"
            case .player: "Player"
            case .liveTV: "Live TV"
            case .sports: "Sports"
            case .accounts: "Accounts"
            case .storage: "Storage"
            case .about: "About"
            }
        }

        var systemImage: String {
            switch self {
            case .general: "gearshape"
            case .playlists: "list.bullet.rectangle"
            case .player: "play.rectangle"
            case .liveTV: "antenna.radiowaves.left.and.right"
            case .sports: "sportscourt"
            case .accounts: "person.crop.circle"
            case .storage: "internaldrive"
            case .about: "info.circle"
            }
        }

        /// The categories this tab holds, in `SettingsCategory` order. About
        /// holds none: it shows the Help & Feedback and About sections.
        var categories: [SettingsCategory] {
            switch self {
            case .general: [.appearance, .home, .library]
            case .playlists: [.playlists, .epg]
            case .player: [.player, .downloads]
            case .liveTV: [.liveTV]
            case .sports: [.sports]
            case .accounts: [.premium, .profiles, .iCloud, .connectedServices]
            case .storage: [.storage, .developer]
            case .about: []
            }
        }
    }

    struct MacSettingsView: View {
        @AppStorage("macSettings.selectedTab") private var selectedTab = MacSettingsTab.general
        @AppStorage(PlaylistSelectionStore.key) private var selectedPlaylistID: String = ""
        @Query private var playlists: [Playlist]
        @State private var premium = PremiumManager.shared

        var body: some View {
            TabView(selection: $selectedTab) {
                ForEach(MacSettingsTab.allCases) { tab in
                    MacSettingsTabContent(tab: tab)
                        .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                        .tag(tab)
                }
            }
            .scenePadding(.minimum)
            .frame(width: 720, height: 600)
            // Its own scene, so it resolves the main window's scope itself:
            // the Library tab switches and other per-playlist pages read it.
            .catalogScope(playlists.scope(for: selectedPlaylistID, isPremium: premium.isPremium), playlists: playlists)
        }
    }

    /// One tab: its single page, or a segmented switcher over its pages.
    private struct MacSettingsTabContent: View {
        let tab: MacSettingsTab
        @State private var page: SettingsCategory?

        private var pages: [SettingsCategory] {
            let hasConnectedServices = TraktService.shared.isConfigured || SimklService.shared.isConfigured
                || MDBListService.shared.isConfigured
            let visible = Set(SettingsCategory.visible(hasConnectedServices: hasConnectedServices))
            return tab.categories.filter { visible.contains($0) }
        }

        var body: some View {
            if tab == .about {
                List {
                    HelpFeedbackSection()
                    AboutSection()
                }
            } else {
                VStack(spacing: 0) {
                    if pages.count > 1 {
                        Picker("Section", selection: Binding(get: { page ?? pages.first }, set: { page = $0 })) {
                            ForEach(pages) { category in
                                Text(category.title).tag(Optional(category))
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                        .padding(.bottom, 12)
                    }
                    if let current = page ?? pages.first {
                        NavigationStack {
                            SettingsCategoryDestination(category: current)
                        }
                        // A fresh stack per page, so switching pages never
                        // lands inside another page's drill-in.
                        .id(current)
                    }
                }
            }
        }
    }

#endif
