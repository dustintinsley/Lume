//
//  MacSettingsView.swift
//  Streamen
//
//  The macOS Settings window (Streamen › Settings…, ⌘,): toolbar tabs, the
//  way Mac apps lay out their settings, in place of the iOS-style list sheet.
//  The tabs are the iPhone root list's groups, so both read the same; a tab
//  holding more than one category switches between them with a segmented
//  control. Every page is the same SwiftUI page iOS shows
//  (`SettingsCategoryDestination`), in its own navigation stack so drill-ins
//  keep working.
//

#if os(macOS)

    import SwiftData
    import SwiftUI

    /// The tabs follow the iPhone's root-list groups, so the two read the
    /// same: each tab is a group, its pages are the group's rows.
    enum MacSettingsTab: String, CaseIterable, Identifiable {
        case content, experience, playback, accountsSync, system, feedback, profiles, about

        var id: String {
            rawValue
        }

        var title: LocalizedStringKey {
            switch self {
            case .content: "Content"
            case .experience: "Experience"
            case .playback: "Playback"
            case .accountsSync: "Accounts & Sync"
            case .system: "System"
            case .feedback: "Feedback"
            case .profiles: "Profiles"
            case .about: "About"
            }
        }

        var systemImage: String {
            switch self {
            case .content: "tv"
            case .experience: "sparkles.tv"
            case .playback: "play.circle"
            case .accountsSync: "arrow.trianglehead.2.clockwise.rotate.90.icloud"
            case .system: "gearshape"
            case .feedback: "questionmark.bubble"
            case .profiles: "person.crop.circle"
            case .about: "info.circle"
            }
        }

        /// The categories this tab holds, in `SettingsCategory` order.
        /// Feedback and About hold none: they show the Help & Feedback and
        /// About sections.
        var categories: [SettingsCategory] {
            switch self {
            case .content: [.playlists, .epg, .library]
            case .experience: [.home, .liveTV, .sports, .appearance]
            case .playback: [.player, .downloads]
            // Streamen Pro sits beside Profiles on the iPhone; Profiles has
            // its own tab here.
            case .accountsSync: [.premium, .iCloud, .connectedServices]
            case .system: [.storage, .developer]
            case .feedback, .about: []
            case .profiles: [.profiles]
            }
        }
    }

    struct MacSettingsView: View {
        @AppStorage("macSettings.selectedTab") private var selectedTab = MacSettingsTab.content
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
            .toggleStyle(TrailingSwitchToggleStyle())
        }
    }

    /// A switch at the row's trailing edge, as the iPhone's settings show it,
    /// in place of the Mac list's leading checkbox.
    struct TrailingSwitchToggleStyle: ToggleStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack {
                configuration.label
                    .accessibilityHidden(true)
                Spacer(minLength: 12)
                Toggle(isOn: configuration.$isOn) {
                    configuration.label
                }
                .toggleStyle(.switch)
                .labelsHidden()
            }
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
            if tab == .feedback {
                SettingsList {
                    HelpFeedbackSection()
                }
            } else if tab == .about {
                SettingsList {
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
