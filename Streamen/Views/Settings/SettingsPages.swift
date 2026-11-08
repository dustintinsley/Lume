//
//  SettingsPages.swift
//  Streamen
//
//  The smaller iOS / macOS / visionOS pages behind root Settings rows:
//  Appearance, Downloads and Connected Services (Trakt, Simkl). tvOS has no Appearance or
//  Downloads, and shows Connected Services in its own pane.
//

#if !os(tvOS)

    import SwiftUI

    /// The app-wide appearance override (System / Dark / Light) and the app
    /// icon choice, both applied at the scene root in `StreamenApp`.
    struct AppearanceSettingsView: View {
        @AppStorage(AppAppearance.storageKey)
        private var appearanceRaw = AppAppearance.defaultValue.rawValue
        @AppStorage(AppIconChoice.storageKey)
        private var appIconRaw = AppIconChoice.defaultValue.rawValue

        var body: some View {
            List {
                Section {
                    Picker("Appearance", selection: $appearanceRaw) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    Text("Follow the device appearance, or keep Streamen always in Dark or Light Mode.")
                }

                #if os(iOS) || os(macOS)
                    Section {
                        Picker("App Icon", selection: $appIconRaw) {
                            ForEach(AppIconChoice.allCases) { choice in
                                AppIconChoiceRow(choice: choice).tag(choice.rawValue)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } header: {
                        Text("App Icon")
                    } footer: {
                        Text(appIconFooter)
                    }
                #endif

                #if os(iOS)
                    IPhoneDuoSettingsSection()
                #endif
            }
            .platformNavigationTitle("Appearance")
        }

        private var appIconFooter: LocalizedStringKey {
            #if os(macOS)
                "Light or Automatic sets the Dock icon while Streamen is open. Automatic follows the device appearance."
            #else
                "Automatic switches between the dark and light icons with the device appearance."
            #endif
        }
    }

    /// An app icon option with a preview of its artwork; Automatic shows the
    /// light and dark icons split down the middle.
    private struct AppIconChoiceRow: View {
        let choice: AppIconChoice

        var body: some View {
            HStack(spacing: 12) {
                preview
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(.primary.opacity(0.12))
                    }
                    .accessibilityHidden(true)
                Text(choice.title)
            }
        }

        @ViewBuilder
        private var preview: some View {
            if choice == .automatic {
                HStack(spacing: 0) {
                    Image(AppIconChoice.light.artworkName()).resizable().scaledToFill()
                        .frame(width: 20, height: 40, alignment: .leading).clipped()
                    Image(AppIconChoice.dark.artworkName()).resizable().scaledToFill()
                        .frame(width: 20, height: 40, alignment: .trailing).clipped()
                }
            } else {
                Image(choice.artworkName()).resizable().scaledToFill()
            }
        }
    }

    struct DownloadsSettingsView: View {
        @AppStorage(DownloadManager.maxConcurrentKey) private var maxConcurrent = 1
        @AppStorage(DownloadManager.autoDeleteKey) private var autoDeleteAfterWatching = false

        var body: some View {
            List {
                Section {
                    NavigationLink {
                        DownloadsView()
                    } label: {
                        Label("Manage Downloads", systemImage: "arrow.down.circle")
                    }
                }

                Section {
                    Stepper(
                        "Max Simultaneous Downloads: \(maxConcurrent)",
                        value: $maxConcurrent,
                        in: 1 ... 5
                    )

                    Toggle("Auto-Delete After Watching", isOn: $autoDeleteAfterWatching)
                } footer: {
                    Text("Download movies and episodes for offline playback. Auto-delete removes the file once you've finished watching.")
                }
            }
            .platformNavigationTitle("Downloads")
        }
    }

    /// Trakt, Simkl and MDBList — whichever this build has credentials for. OpenSubtitles
    /// lives under Player.
    struct ConnectedServicesView: View {
        @State private var trakt = TraktService.shared
        @State private var simkl = SimklService.shared
        @State private var mdblist = MDBListService.shared

        var body: some View {
            List {
                Section {
                    if trakt.isConfigured {
                        NavigationLink {
                            TraktIntegrationView()
                        } label: {
                            serviceLabel(
                                "Trakt",
                                systemImage: "arrow.trianglehead.2.clockwise.rotate.90.circle",
                                status: trakt.isConnected ? trakt.username.map { "@\($0)" } ?? String(localized: "Connected") : nil
                            )
                        }
                    }

                    if simkl.isConfigured {
                        NavigationLink {
                            SimklIntegrationView()
                        } label: {
                            serviceLabel(
                                "Simkl",
                                systemImage: "arrow.trianglehead.2.clockwise.rotate.90.circle",
                                status: simkl.isConnected ? simkl.username.map { "@\($0)" } ?? String(localized: "Connected") : nil
                            )
                        }
                    }

                    if mdblist.isConfigured {
                        NavigationLink {
                            MDBListIntegrationView()
                        } label: {
                            serviceLabel(
                                "MDBList",
                                systemImage: "arrow.trianglehead.2.clockwise.rotate.90.circle",
                                status: mdblist.isConnected ? mdblist.username.map { "@\($0)" } ?? String(localized: "Connected") : nil
                            )
                        }
                    }

                } footer: {
                    Text("Sync watched movies and episodes and show your Trakt, Simkl or MDBList watchlist on Home.")
                }
            }
            .platformNavigationTitle("Connected Services")
        }

        private func serviceLabel(_ title: LocalizedStringKey, systemImage: String, status: String?) -> some View {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                if let status {
                    Text(verbatim: status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

#endif
