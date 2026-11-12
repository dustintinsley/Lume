//
//  ReorderHandle.swift
//  Streamen
//

import SwiftUI
#if os(macOS)
    import UniformTypeIdentifiers
#endif

extension View {
    /// The three-line grip iOS shows on a reorderable row in edit mode. A Mac
    /// list drags `onMove` rows without one, so nothing would say they move;
    /// elsewhere the system draws its own. `shown` is false while the rows
    /// can't move (a filtered list), so no grip promises a drag.
    func reorderHandle(_ shown: Bool = true) -> some View {
        #if os(macOS)
            HStack(spacing: 8) {
                self
                if shown {
                    Spacer(minLength: 0)
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        #else
            self
        #endif
    }

    /// A row of a reorderable `ForEach` inside a `SettingsList`. On the Mac
    /// that list is a grouped `Form`, which ignores `onMove`, so the row
    /// drags itself: it shows the grip and moves through `onMove` as it's
    /// dragged over the other rows. Elsewhere the list is a `List`, whose
    /// `onMove` on the `ForEach` does the work, and this is a no-op.
    ///
    /// - Parameters:
    ///   - id: This row's identity.
    ///   - ids: Every row's identity, in the order shown.
    ///   - onMove: The `ForEach`'s move action.
    func settingsReorderable<ID: Hashable>(
        _ id: ID,
        in ids: [ID],
        onMove: @escaping (IndexSet, Int) -> Void
    ) -> some View {
        #if os(macOS)
            reorderHandle()
                .onDrag {
                    MacReorderDrag.current = AnyHashable(id)
                    return NSItemProvider(object: String(describing: id) as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: MacReorderDropDelegate(target: AnyHashable(id), ids: ids.map(AnyHashable.init), onMove: onMove)
                )
        #else
            self
        #endif
    }
}

#if os(macOS)
    /// The row being dragged. One drag at a time on the Mac, so a single
    /// slot; the drop side reads it rather than decoding the pasteboard, so a
    /// row only ever moves within its own list.
    @MainActor
    private enum MacReorderDrag {
        static var current: AnyHashable?
    }

    @MainActor
    private struct MacReorderDropDelegate: DropDelegate {
        let target: AnyHashable
        let ids: [AnyHashable]
        let onMove: (IndexSet, Int) -> Void

        func validateDrop(info _: DropInfo) -> Bool {
            MacReorderDrag.current.map(ids.contains) ?? false
        }

        /// Moves the dragged row into this row's place as soon as it's over
        /// it, so the list reorders under the pointer the way a List does.
        func dropEntered(info _: DropInfo) {
            guard let dragged = MacReorderDrag.current, dragged != target,
                  let from = ids.firstIndex(of: dragged), let to = ids.firstIndex(of: target)
            else { return }
            withAnimation {
                onMove(IndexSet(integer: from), to > from ? to + 1 : to)
            }
        }

        func dropUpdated(info _: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }

        func performDrop(info _: DropInfo) -> Bool {
            MacReorderDrag.current = nil
            return true
        }
    }
#endif
