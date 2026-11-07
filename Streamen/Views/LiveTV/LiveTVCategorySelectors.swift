//
//  LiveTVCategorySelectors.swift
//  Streamen
//
//  How the viewer picks which collection of live channels to browse: the macOS
//  sidebar list and the iOS button-plus-searchable-sheet. Split out of
//  `LiveTVView` to keep that file focused on cross-platform composition (and
//  inside the project's file-length cap).
//

import SwiftData
import SwiftUI

// MARK: - Category Sidebar

/// The macOS category rail: a floating glass panel beside the channels, in the
/// shape of a system sidebar, using the list's own selection so the selected
/// row gets the platform highlight.
struct CategorySidebar: View {
    let sections: [LiveTVSection]
    @Binding var selectedSection: LiveTVSection?

    /// Routes the list's id selection to the section binding. A click on the
    /// selected row reports nil, which keeps the current section.
    private var selectedID: Binding<String?> {
        Binding(
            get: { selectedSection?.id },
            set: { id in
                guard let id, let section = sections.first(where: { $0.id == id }) else { return }
                selectedSection = section
            }
        )
    }

    var body: some View {
        List(selection: selectedID) {
            Section("Categories") {
                ForEach(sections) { section in
                    Label {
                        section.titleText
                            .lineLimit(1)
                    } icon: {
                        if let icon = section.icon {
                            Image(systemName: icon)
                        }
                    }
                    .tag(section.id)
                }
            }
        }
        #if !os(tvOS)
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        #endif
        .glassEffectCompat(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(8)
    }
}

/// Settings for the macOS category rail, kept per device like the guide's.
enum CategorySidebarSettings {
    /// Whether the rail is open; the toolbar's sidebar button flips it.
    static let visibleKey = "streamen.liveTV.categorySidebarVisible"
    static let width: CGFloat = 240
}

// MARK: - iOS Category Bar

#if os(iOS)
    /// iOS category selector. A horizontal pill strip is unscannable once a
    /// playlist syncs hundreds of categories, so the current section is shown as a
    /// single button that opens a searchable list of every section instead.
    struct CategoryBar: View {
        let sections: [LiveTVSection]
        @Binding var selectedSection: LiveTVSection?

        @State private var showingPicker = false

        /// The section the button reflects — the user's selection, or the first
        /// available one if that selection has since disappeared (mirrors
        /// `displayedSection(in:)`).
        private var currentSection: LiveTVSection? {
            guard let selectedSection else { return sections.first }
            return sections.first { $0.id == selectedSection.id } ?? sections.first
        }

        var body: some View {
            Button {
                showingPicker = true
            } label: {
                HStack(spacing: 8) {
                    if let icon = currentSection?.icon {
                        Image(systemName: icon)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    (currentSection?.titleText ?? Text("Select a Category"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(.bar)
            .sheet(isPresented: $showingPicker) {
                CategoryPickerSheet(sections: sections, selectedSection: $selectedSection)
            }

            Divider()
        }
    }

    /// Searchable list of every Live TV section. Type to filter hundreds of
    /// synced categories down to a handful; the virtual collections stay pinned
    /// at the top while the search field is empty.
    private struct CategoryPickerSheet: View {
        let sections: [LiveTVSection]
        @Binding var selectedSection: LiveTVSection?

        @Environment(\.dismiss) private var dismiss
        @State private var query = ""

        private var filteredSections: [LiveTVSection] {
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return sections }
            return sections.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
        }

        var body: some View {
            NavigationStack {
                List(filteredSections) { section in
                    let isSelected = selectedSection?.id == section.id
                    Button {
                        selectedSection = section
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            if let icon = section.icon {
                                Image(systemName: icon)
                                    .foregroundStyle(.secondary)
                            }
                            section.titleText
                                .foregroundStyle(.primary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .overlay {
                    if filteredSections.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
                .searchable(text: $query, prompt: "Search categories")
                .navigationTitle("Categories")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }
#endif
