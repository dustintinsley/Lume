//
//  TVCategoryRail.swift
//  Streamen
//
//  The tvOS Live TV category sidebar: the shared glass rail listing the
//  virtual collections and the provider's categories, beside the channel list
//  or guide.
//

#if os(tvOS)
    import SwiftUI

    /// The Live TV categories as a `TVSidebarRail`: the virtual collections,
    /// the Recordings entry, then the provider's categories.
    struct TVCategoryRail: View {
        let sections: [LiveTVSection]
        @Binding var selectedSection: LiveTVSection?
        /// Fired when the user activates (clicks, or presses Right on) a
        /// category.
        var onCategoryActivated: () -> Void = {}
        /// Fired when focus rests on a category and selects it.
        var onCategoryFocused: () -> Void = {}
        /// The Recordings entry, below the virtual collections and above the
        /// first category; nil hides it.
        var recordings: TVCategoryRailRecordingsEntry?
        /// Told whether focus is inside the rail, for the tab-bar entry catcher.
        @Environment(TVLiveTVFocusRegions.self) private var focusRegions: TVLiveTVFocusRegions?

        var body: some View {
            // Resting on a category loads it into the pane; Right then moves
            // into it, as Select does.
            TVSidebarRail(
                items: items,
                selectedID: selectedID,
                onFocusChange: { isFocused in
                    if let focusRegions, focusRegions.railFocused != isFocused {
                        focusRegions.railFocused = isFocused
                    }
                },
                rightRunsAction: true
            )
        }

        /// Visual order is focus order: Favorites and Recently Watched
        /// (whichever exist), Recordings, then the provider's categories.
        private var items: [TVSidebarRailItem] {
            let pinnedCount = sections.prefix(while: \.isVirtual).count
            var items = sections.prefix(pinnedCount).map(categoryItem)
            if let recordings {
                items.append(TVSidebarRailItem(
                    id: TVCategoryRailRecordingsEntry.id,
                    title: Text("Recordings"),
                    icon: recordings.isLocked ? "crown" : "recordingtape",
                    // Locked, Select raises the paywall: Right shouldn't.
                    runsOnRight: !recordings.isLocked,
                    action: recordings.onActivate
                ))
            }
            items += sections.dropFirst(pinnedCount).map(categoryItem)
            return items
        }

        /// The row that reads as selected: Recordings while its library shows,
        /// else the selected category.
        private var selectedID: String? {
            recordings?.isSelected == true ? TVCategoryRailRecordingsEntry.id : selectedSection?.id
        }

        private func categoryItem(_ section: LiveTVSection) -> TVSidebarRailItem {
            TVSidebarRailItem(
                id: section.id,
                title: section.titleText,
                icon: section.icon,
                focusSettleAction: {
                    selectedSection = section
                    onCategoryFocused()
                },
                action: {
                    selectedSection = section
                    onCategoryActivated()
                }
            )
        }
    }

    /// The Recordings row under the virtual collections, shown while a
    /// recording server is paired and Settings › Live TV lists it in the rail.
    /// Locked (no Streamen Pro) it carries the crown.
    struct TVCategoryRailRecordingsEntry {
        static let id = "streamen.liveSection.recordings"

        let isSelected: Bool
        let isLocked: Bool
        let onActivate: () -> Void
    }
#endif
