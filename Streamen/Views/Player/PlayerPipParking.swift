//
//  PlayerPipParking.swift
//  Streamen
//
//  Lets the iOS player page step aside while its video plays in Picture in
//  Picture, so the viewer can keep browsing, and come back on restore.
//
//  KSPlayer dismisses the page's view controller when PiP starts from the
//  player's button (`KSOptions.isPipPopViewController`) and presents the same
//  controller again from PiP's restore button. The other engines own their
//  PiP controller, so the page does the same for them: it dismisses its
//  hosting controller once PiP is up and presents it again on restore.
//  SwiftUI sees that as the page disappearing and reappearing, and the page's
//  teardown would stop the very stream PiP is showing. So while the page is
//  parked its `onDisappear` work is held back: dropped on restore (the page
//  carries on as it was), run when PiP is closed with its ✕ or another player
//  page opens.
//

import SwiftUI
#if os(iOS)
    import UIKit
#endif

@MainActor
final class PlayerPipParking {
    static let shared = PlayerPipParking()

    private enum State {
        case idle
        case parked(page: UUID)
        case restoring(page: UUID)
    }

    private var state = State.idle
    private var deferred: [() -> Void] = []
    private var stopPip: (() -> Void)?
    private var closePage: (() -> Void)?
    private var isStillPlaying: (() -> Bool)?
    private var hasStarted = false
    /// The page last brought back from PiP. UIKit presented it again, out
    /// of SwiftUI's sight, so SwiftUI's dismiss no longer reaches it.
    private var restoredPage: UUID?
    #if os(iOS)
        private weak var anchor: UIView?
        private var anchorPage: UUID?
        /// The page's hosting controller while it is dismissed, kept alive so
        /// the same page (and its player) comes back on restore.
        private var detachedPage: UIViewController?
        private weak var presenter: UIViewController?
    #endif

    private init() {}

    /// Call as PiP starts from the player's own button. `close` sets the
    /// page's presentation back to nil and `stop` ends PiP, for when the
    /// parked session has to finish. `isStillPlaying`, when given, tells a
    /// restore from the ✕ for engines whose PiP does not report a restore
    /// (the ✕ pauses the stream; a restore leaves it playing).
    func park(
        page: UUID,
        isPipActive: @escaping () -> Bool,
        isStillPlaying: (() -> Bool)? = nil,
        close: @escaping () -> Void,
        stop: @escaping () -> Void
    ) {
        endParkedSession()
        state = .parked(page: page)
        deferred = []
        hasStarted = false
        closePage = close
        stopPip = stop
        self.isStillPlaying = isStillPlaying
        // KSPlayer dismisses the page whether or not PiP actually starts; a
        // PiP that never comes up must not leave the stream playing unseen.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard self.isParked(page), !isPipActive() else { return }
            self.endParkedSession()
        }
    }

    func isParked(_ page: UUID) -> Bool {
        if case let .parked(parked) = state { parked == page } else { false }
    }

    /// PiP is up for the parked page: dismiss the page, for engines that do
    /// not do it themselves.
    func pictureInPictureDidStart(page: UUID, detachesPage: Bool) {
        guard isParked(page), !hasStarted else { return }
        hasStarted = true
        #if os(iOS)
            if detachesPage { detachPage(page) }
        #endif
    }

    /// PiP's restore button, for engines whose PiP delegate reports it: the
    /// page comes back before the PiP window flies home.
    func restoreParkedPage(completion: @escaping (Bool) -> Void) {
        guard case let .parked(page) = state else { return completion(true) }
        #if os(iOS)
            reattachPage(page, completion: completion)
        #else
            completion(true)
        #endif
    }

    /// The engine's PiP window went away. True when the parked session took
    /// care of it: restored, or closed with its ✕ and finished here.
    func pictureInPictureDidStop(page: UUID?) -> Bool {
        guard let page else { return false }
        if case let .restoring(restoring) = state, restoring == page { return true }
        guard isParked(page) else { return false }
        #if os(iOS)
            if detachedPage != nil, let isStillPlaying {
                // Restoring brings the app forward first, so a stop in the
                // background was the ✕.
                guard UIApplication.shared.applicationState != .background else {
                    endParkedSession()
                    return true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    guard self.isParked(page) else { return }
                    if isStillPlaying() {
                        self.reattachPage(page) { _ in }
                    } else {
                        self.endParkedSession()
                    }
                }
                return true
            }
        #endif
        endParkedSession()
        return true
    }

    /// The page's `onAppear` work. Skipped when the parked page comes back
    /// from PiP; a different page appearing ends the parked session first.
    /// Views outside a player page (`page` nil) just run it.
    func onAppear(page: UUID?, _ body: () -> Void) {
        guard let page else { return body() }
        switch state {
        case let .parked(parked) where parked == page:
            // Restored: the page carries on with the session it left.
            beginRestoring(page)
            fallthrough
        case .restoring(page):
            // Every hook of the returning page appears in this same pass.
            Task { @MainActor in self.state = .idle }
        default:
            endParkedSession()
            body()
        }
    }

    /// The page's `onDisappear` work: run now, or held while the page is parked.
    func onDisappear(page: UUID?, _ body: @escaping () -> Void) {
        if let page, isParked(page) {
            deferred.append(body)
        } else {
            body()
        }
    }

    /// PiP closed with its ✕, or the session is being replaced: stop PiP, run
    /// the page's held-back teardown and drop its presentation.
    func endParkedSession() {
        guard case .parked = state else { return }
        state = .idle
        let stop = stopPip, close = closePage, teardown = deferred
        clearSession()
        stop?()
        teardown.forEach { $0() }
        close?()
    }

    private func beginRestoring(_ page: UUID) {
        clearSession()
        state = .restoring(page: page)
        restoredPage = page
    }

    private func clearSession() {
        deferred = []
        stopPip = nil
        closePage = nil
        isStillPlaying = nil
        #if os(iOS)
            detachedPage = nil
        #endif
    }

    #if os(iOS)
        /// The page's anchor view, from which its hosting controller is found.
        func register(anchor view: UIView, page: UUID) {
            anchor = view
            anchorPage = page
        }

        /// Closes a page that came back from PiP, after SwiftUI's own
        /// dismiss has had its go: UIKit re-presented it, so that may miss.
        func dismissRestoredPage() {
            guard let page = restoredPage, anchorPage == page, var controller = anchor?.owningViewController else { return }
            restoredPage = nil
            while let parent = controller.parent {
                controller = parent
            }
            Task { @MainActor in
                guard controller.presentingViewController != nil, !controller.isBeingDismissed else { return }
                controller.dismiss(animated: true)
            }
        }

        private func detachPage(_ page: UUID) {
            guard anchorPage == page, var controller = anchor?.owningViewController else { return }
            while let parent = controller.parent {
                controller = parent
            }
            guard let presenting = controller.presentingViewController else { return }
            detachedPage = controller
            presenter = presenting
            controller.dismiss(animated: true)
        }

        private func reattachPage(_ page: UUID, completion: @escaping (Bool) -> Void) {
            guard let controller = detachedPage, var top = presenter else {
                endParkedSession()
                return completion(true)
            }
            while let presented = top.presentedViewController {
                top = presented
            }
            // The page's appear hooks see a restore, not a new session.
            beginRestoring(page)
            top.present(controller, animated: true) { completion(true) }
        }
    #endif
}

extension View {
    /// Marks this view as the player page `page`, for `PlayerPipParking`.
    func playerPage(_ page: UUID) -> some View {
        #if os(iOS)
            // Where the page sits in UIKit, for PiP from engines that own it.
            environment(\.playerPageID, page).background(PlayerPageAnchor(page: page))
        #else
            environment(\.playerPageID, page)
        #endif
    }
}

extension View {
    /// For engines that own their PiP controller: on iOS a PiP started from
    /// the player's button (the app still in front; automatic PiP starts as
    /// it leaves) parks the page and dismisses it, like KSPlayer does.
    func parksPageDuringPictureInPicture(
        isPipActive: Bool,
        isPlaying: @escaping () -> Bool,
        stop: @escaping () -> Void,
        close: @escaping () -> Void
    ) -> some View {
        #if os(iOS)
            modifier(PipPageParking(isPipActive: isPipActive, isPlaying: isPlaying, stop: stop, close: close))
        #else
            self
        #endif
    }
}

extension EnvironmentValues {
    /// Identifies the player page a view belongs to, for `PlayerPipParking`;
    /// nil outside one (a Multi-View tile, an inline preview).
    @Entry var playerPageID: UUID?
}

extension PlayerSettings.Playback {
    /// Hide the whole app (Mac) while the player's video is in Picture in
    /// Picture. Off, only the player window steps aside. Not offered on iOS,
    /// where an app cannot send itself to the Home screen.
    static let hideAppDuringPipKey = "player.hideAppDuringPip"
    static let hideAppDuringPipDefault = false

    static var hideAppDuringPip: Bool {
        UserDefaults.standard.bool(hideAppDuringPipKey, default: hideAppDuringPipDefault)
    }
}

#if os(iOS)
    private extension UIResponder {
        var owningViewController: UIViewController? {
            var responder: UIResponder? = self
            while let current = responder {
                if let controller = current as? UIViewController { return controller }
                responder = current.next
            }
            return nil
        }
    }

    /// Marks where a player page sits in UIKit, so `PlayerPipParking` can
    /// dismiss and re-present its hosting controller.
    struct PlayerPageAnchor: UIViewRepresentable {
        let page: UUID

        func makeUIView(context _: Context) -> AnchorView {
            let view = AnchorView()
            view.page = page
            view.isUserInteractionEnabled = false
            return view
        }

        func updateUIView(_ view: AnchorView, context _: Context) {
            view.page = page
        }

        final class AnchorView: UIView {
            var page: UUID?

            override func didMoveToWindow() {
                super.didMoveToWindow()
                guard window != nil, let page else { return }
                PlayerPipParking.shared.register(anchor: self, page: page)
            }
        }
    }

    private struct PipPageParking: ViewModifier {
        let isPipActive: Bool
        let isPlaying: () -> Bool
        let stop: () -> Void
        let close: () -> Void
        @Environment(\.playerPageID) private var pageID

        func body(content: Content) -> some View {
            content.onChange(of: isPipActive) { _, active in
                guard active, let pageID, UIApplication.shared.applicationState == .active else { return }
                let parking = PlayerPipParking.shared
                guard !parking.isParked(pageID) else { return }
                parking.park(page: pageID, isPipActive: { true }, isStillPlaying: isPlaying, close: close, stop: stop)
                parking.pictureInPictureDidStart(page: pageID, detachesPage: true)
            }
        }
    }
#endif
