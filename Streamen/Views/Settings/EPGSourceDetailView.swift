//
//  EPGSourceDetailView.swift
//  Streamen
//
//  One EPG source's page, pushed from the TV Guide settings list the way a
//  playlist's page is pushed from Playlists, and laid out to match it: the
//  source's details with Edit… / Delete beside them, its options, and its
//  refresh status. Only manual sources can be edited or deleted; a
//  playlist-linked source is rebuilt from its playlist on every reconcile, so
//  its page links to that playlist instead.
//
//  iOS / macOS only; tvOS keeps its inline rows in EPGSettingsView.
//

#if !os(tvOS)
    import SwiftData
    import SwiftUI

    struct EPGSourceDetailView: View {
        @Environment(\.modelContext) private var modelContext
        @Environment(\.dismiss) private var dismiss
        @Bindable var source: EPGSource
        @Query private var playlists: [Playlist]

        @State private var isEditing = false
        @State private var editName = ""
        @State private var editURL = ""
        @State private var showDeleteConfirmation = false

        private var linkedPlaylist: Playlist? {
            guard let id = source.playlistID else { return nil }
            return playlists.first { $0.id == id }
        }

        var body: some View {
            Form {
                if isEditing {
                    editingSection
                } else {
                    readOnlySection
                }
                #if os(macOS)
                    if source.isManual {
                        macEditButtons
                    }
                #endif
                optionsSection
                statusSection
                #if os(iOS)
                    if source.isManual {
                        Section {
                            Button("Delete Source", role: .destructive) { showDeleteConfirmation = true }
                        }
                    }
                #endif
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle(source.name)
            #if os(iOS)
                .toolbar {
                    if source.isManual {
                        ToolbarItem(placement: .primaryAction) {
                            if isEditing {
                                Button("Save") { saveChanges() }
                                    .disabled(trimmedURL.isEmpty)
                            } else {
                                Button("Edit") { startEditing() }
                            }
                        }
                        if isEditing {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { cancelEditing() }
                            }
                        }
                    }
                }
            #endif
                .confirmationDialog(
                    "Delete \(source.name)?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Source", role: .destructive) { deleteSource() }
                } message: {
                    Text("Guide data from this source is removed the next time the guide refreshes.")
                }
        }

        // MARK: - Sections

        private var readOnlySection: some View {
            Section {
                LabeledContent("Name", value: source.name)
                if source.isManual {
                    LabeledContent("XMLTV URL") {
                        Text(source.url)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                    }
                } else if let linkedPlaylist {
                    // Never show a linked source's URL: an Xtream guide URL
                    // carries the playlist's credentials.
                    NavigationLink {
                        PlaylistDetailView(playlist: linkedPlaylist)
                    } label: {
                        LabeledContent("Playlist", value: linkedPlaylist.name)
                    }
                }
                LabeledContent("Added") {
                    Text(source.addedAt, style: .date)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Source")
            } footer: {
                if !source.isManual {
                    Text("This guide comes from its playlist. Change its guide URL in the playlist's settings.")
                }
            }
        }

        private var editingSection: some View {
            Section("Source") {
                TextField("Name", text: $editName)
                TextField("XMLTV URL", text: $editURL)
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                #endif
                    .autocorrectionDisabled()
                    .textContentType(.URL)
            }
        }

        #if os(macOS)
            /// In the page, not the toolbar: the Settings window's toolbar holds
            /// its tabs, so items pushed pages add there never get clicks.
            private var macEditButtons: some View {
                Section {
                    HStack {
                        if !isEditing {
                            Button("Delete Source…", role: .destructive) { showDeleteConfirmation = true }
                        }
                        Spacer()
                        if isEditing {
                            Button("Cancel") { cancelEditing() }
                                .keyboardShortcut(.cancelAction)
                            Button("Save") { saveChanges() }
                                .keyboardShortcut(.defaultAction)
                                .disabled(trimmedURL.isEmpty)
                        } else {
                            Button("Edit…") { startEditing() }
                        }
                    }
                }
            }
        #endif

        private var optionsSection: some View {
            Section {
                Toggle("Enabled", isOn: $source.isEnabled)
                Toggle("Sync at Startup", isOn: $source.syncAtLaunch)
                    .disabled(!source.isEnabled)
            } header: {
                Text("Options")
            } footer: {
                Text("Sync at Startup refreshes the whole guide each time Streamen opens.")
            }
        }

        private var statusSection: some View {
            Section("Status") {
                LabeledContent("Status", value: statusText)
                LabeledContent("Last Refreshed") {
                    if let last = source.lastSyncDate {
                        Text(last.formatted(.relative(presentation: .named)))
                    } else {
                        Text("Never")
                    }
                }
            }
        }

        private var statusText: String {
            if !source.isEnabled { return String(localized: "Off") }
            switch source.syncStatus {
            case .error: return String(localized: "Last refresh failed")
            case .syncing: return String(localized: "Refreshing…")
            default: return source.lastSyncDate == nil ? String(localized: "Not refreshed yet") : String(localized: "Up to date")
            }
        }

        // MARK: - Actions

        private var trimmedURL: String {
            editURL.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        private func startEditing() {
            editName = source.name
            editURL = source.url
            withAnimation { isEditing = true }
        }

        private func cancelEditing() {
            withAnimation { isEditing = false }
        }

        private func saveChanges() {
            guard !trimmedURL.isEmpty else { return }
            let name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
            source.name = name.isEmpty ? String(localized: "Custom Guide") : name
            let urlChanged = source.url != trimmedURL
            source.url = trimmedURL
            try? modelContext.save()
            withAnimation { isEditing = false }
            if urlChanged, source.isEnabled {
                EPGSyncService.shared.syncNow()
            }
        }

        private func deleteSource() {
            modelContext.delete(source)
            try? modelContext.save()
            dismiss()
        }
    }
#endif
