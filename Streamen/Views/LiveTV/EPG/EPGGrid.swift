//
//  EPGGrid.swift
//  Streamen
//
//  The guide's single 2D-scrollable programme surface: it owns the scroll
//  position, executes the scroller's programmatic scroll requests, and
//  publishes the measured geometry back to the shared sync. Split from
//  `EPGGridScroller` to keep each file within the lint length budget.
//

import SwiftUI

/// The single scrollable surface. Owns its scroll position, executes the
/// scroller's scroll requests and publishes the measured geometry to the
/// shared sync. Its programme rows live in a separate child so parent updates
/// never rebuild them wholesale.
///
/// `Equatable` (wrapped in `.equatable()` by the scroller): the scroller's
/// body re-runs on virtual-focus changes, and without the gate each press
/// would re-evaluate this whole subtree. The comparison covers everything the
/// subtree renders or reacts to.
struct EPGGrid: View, Equatable {
    let rows: [EPGChannelRow]
    let timeline: EPGTimeline
    let metrics: EPGMetrics
    let now: Date
    let sync: EPGScrollSync
    let dataVersion: Int
    let nowTarget: CGFloat
    let scrollRequest: EPGScrollRequest?
    let virtualFocus: EPGVirtualFocus?
    let onPlay: (EPGChannelRow, EPGProgramCell) -> Void
    let onWatchFromStart: (EPGChannelRow, EPGProgramCell) -> Void
    let onShowDetails: (EPGChannelRow, EPGProgramCell) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.dataVersion == rhs.dataVersion
            && lhs.rows.count == rhs.rows.count
            && lhs.nowTarget == rhs.nowTarget
            && lhs.scrollRequest == rhs.scrollRequest
            && lhs.virtualFocus == rhs.virtualFocus
            && lhs.timeline == rhs.timeline
    }

    @State private var position = ScrollPosition()
    @State private var didInitialScroll = false
    /// The initial scroll, kept until the grid has actually reached it. The
    /// first `scrollTo` runs while the container is still a few points wide,
    /// and OS 26 replays it after layout. OS 18 drops it, along with any
    /// replay issued from inside the layout pass, and leaves the grid at the
    /// window's start, hours before now, while the ruler mirrors now.
    @State private var pendingInitialScroll: CGPoint?
    @State private var initialScrollReplays = 0
    /// A combined horizontal+vertical ScrollView centers content that is shorter
    /// than the viewport. The frozen channel column pins its cells to the top, so
    /// without this the two panes drift apart when a category has only a few
    /// channels. Pinning the rows to at least the viewport height (top-aligned)
    /// keeps them level on every platform.
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            EPGRows(
                rows: rows,
                timeline: timeline,
                metrics: metrics,
                now: now,
                sync: sync,
                dataVersion: dataVersion,
                virtualFocus: virtualFocus,
                onPlay: onPlay,
                onWatchFromStart: onWatchFromStart,
                onShowDetails: onShowDetails
            )
            .equatable()
            .frame(minHeight: viewportHeight, alignment: .topLeading)
            #if os(iOS) || os(macOS)
                .background { EPGDirectionalLock() }
            #endif
        }
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { viewportHeight = geo.size.height }
                    .onChange(of: geo.size.height) { viewportHeight = $1 }
            }
        }
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGRect.self) { CGRect(origin: $0.contentOffset, size: $0.containerSize) } action: { _, new in
            replayInitialScrollIfDropped(at: new)
            let clamped = CGPoint(x: max(0, new.origin.x), y: max(0, new.origin.y))
            sync.offset = clamped
            sync.viewport = new.size
            #if !os(tvOS)
                // Touch scrolling has no known target — the panes mirror the
                // measured offset per frame. tvOS mirrors per programmatic
                // move instead (see EPGGridScroller.requestScroll).
                sync.mirror = clamped
            #endif
            let window = EPGRealizeWindow.around(
                offset: clamped.x,
                viewport: new.width,
                blockLength: 30 * metrics.pointsPerMinute
            )
            if sync.window != window {
                sync.window = window
            }
            let rowWindow = EPGRealizeWindow.around(
                offset: clamped.y,
                viewport: new.height,
                blockLength: 2 * (metrics.rowHeight + metrics.rowSpacing)
            )
            if sync.rowWindow != rowWindow {
                sync.rowWindow = rowWindow
            }
        }
        .onAppear {
            guard !didInitialScroll else { return }
            didInitialScroll = true
            // Seed the realization windows and the pane mirror around the
            // initial scroll target so the first build already realizes the
            // right cells; the estimated viewports are corrected by the first
            // geometry event.
            sync.window = EPGRealizeWindow.around(
                offset: nowTarget,
                viewport: 2400,
                blockLength: 30 * metrics.pointsPerMinute
            )
            sync.rowWindow = EPGRealizeWindow.around(
                offset: 0,
                viewport: 1400,
                blockLength: 2 * (metrics.rowHeight + metrics.rowSpacing)
            )
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                sync.mirror = CGPoint(x: nowTarget, y: 0)
            }
            pendingInitialScroll = CGPoint(x: nowTarget, y: 0)
            position.scrollTo(point: CGPoint(x: nowTarget, y: 0))
        }
        .onChange(of: scrollRequest) { _, request in
            guard let request else { return }
            pendingInitialScroll = nil
            if request.animated {
                withAnimation(.easeOut(duration: 0.25)) {
                    position.scrollTo(point: request.point)
                }
            } else {
                position.scrollTo(point: request.point)
            }
        }
    }

    /// Re-issues a dropped initial scroll once the grid has a real size,
    /// a turn later and outside the layout pass. It gives up after a few
    /// tries so it can never fight a drag on touch platforms.
    private func replayInitialScrollIfDropped(at geometry: CGRect) {
        guard let pending = pendingInitialScroll, geometry.width > 0, geometry.height > 0 else { return }
        let reached = abs(geometry.origin.x - pending.x) <= 1 && abs(geometry.origin.y - pending.y) <= 1
        guard !reached, initialScrollReplays < 3 else {
            pendingInitialScroll = nil
            return
        }
        initialScrollReplays += 1
        Task { @MainActor in
            guard pendingInitialScroll == pending else { return }
            // The binding still holds the dropped target, and writing the
            // same point again is no change to SwiftUI, so it doesn't scroll.
            // Clear it first.
            position = ScrollPosition()
            await Task.yield()
            guard pendingInitialScroll == pending else { return }
            position.scrollTo(point: pending)
        }
    }
}

#if os(iOS)
    import UIKit

    /// Turns on directional lock for the guide's two-way scroll view: a drag
    /// that starts mostly vertical stays vertical (and horizontal likewise)
    /// until the finger lifts, so browsing channels doesn't drift through
    /// time. SwiftUI has no modifier for it; this finds the hosting
    /// `UIScrollView` from inside the content.
    struct EPGDirectionalLock: UIViewRepresentable {
        func makeUIView(context _: Context) -> ProbeView {
            ProbeView()
        }

        func updateUIView(_: ProbeView, context _: Context) {}

        final class ProbeView: UIView {
            override func didMoveToWindow() {
                super.didMoveToWindow()
                var view = superview
                while let current = view, !(current is UIScrollView) {
                    view = current.superview
                }
                (view as? UIScrollView)?.isDirectionalLockEnabled = true
            }
        }
    }
#elseif os(macOS)
    import AppKit

    /// The Mac's directional lock for the guide's two-way scroll view: a
    /// trackpad swipe moves along whichever axis it starts mostly on until it
    /// (and its momentum) ends, so browsing channels doesn't drift through
    /// time. SwiftUI's scroll view ignores `usesPredominantAxisScrolling`, so
    /// this filters the scroll events over the guide instead, zeroing the
    /// other axis. A mouse wheel's discrete events pass through untouched.
    struct EPGDirectionalLock: NSViewRepresentable {
        func makeNSView(context _: Context) -> ProbeView {
            ProbeView()
        }

        func updateNSView(_: ProbeView, context _: Context) {}

        final class ProbeView: NSView {
            private enum Axis {
                case horizontal, vertical
            }

            private var monitor: Any?
            /// The current gesture's axis; `nil` until it moves.
            private var axis: Axis?

            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                if window == nil {
                    if let monitor {
                        NSEvent.removeMonitor(monitor)
                    }
                    monitor = nil
                } else if monitor == nil {
                    monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                        self?.filter(event) ?? event
                    }
                }
            }

            private func filter(_ event: NSEvent) -> NSEvent {
                guard let window, event.window === window,
                      visibleRect.contains(convert(event.locationInWindow, from: nil)) else { return event }
                // Only trackpad (and Magic Mouse) gestures carry phases.
                guard !event.phase.isEmpty || !event.momentumPhase.isEmpty else { return event }
                if event.phase.contains(.mayBegin) || event.phase.contains(.began) {
                    axis = nil
                }
                if axis == nil {
                    let dx = abs(event.scrollingDeltaX), dy = abs(event.scrollingDeltaY)
                    guard dx > 0 || dy > 0 else { return event }
                    axis = dx > dy ? .horizontal : .vertical
                }
                guard let copy = event.cgEvent?.copy() else { return event }
                // Axis 1 is vertical, axis 2 horizontal.
                let fields: [CGEventField] = axis == .vertical
                    ? [.scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventPointDeltaAxis2]
                    : [.scrollWheelEventDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventPointDeltaAxis1]
                for field in fields {
                    copy.setIntegerValueField(field, value: 0)
                    copy.setDoubleValueField(field, value: 0)
                }
                return NSEvent(cgEvent: copy) ?? event
            }
        }
    }
#endif
