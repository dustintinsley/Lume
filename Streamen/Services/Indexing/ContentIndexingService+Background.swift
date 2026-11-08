//
//  ContentIndexingService+Background.swift
//  Streamen
//
//  Lets iOS finish the content index overnight. In the foreground the pass
//  stands aside for browsing and playback, and it stops the moment the app is
//  suspended, so on an iPhone a large catalog never got to the end. A
//  `BGProcessingTask` — which iOS runs while the phone is charging and on
//  Wi-Fi, typically overnight — gives it uninterrupted time instead.
//
//  The task is asked for each time the app goes to the background with titles
//  still unindexed, and asks for the next one when it runs, until the index is
//  complete. Everywhere but iOS these are no-ops: tvOS and macOS have no
//  processing tasks, and a Mac keeps indexing while the app is open anyway.
//

import Foundation
import OSLog
import SwiftData
#if os(iOS)
    import BackgroundTasks
#endif

extension ContentIndexingService {
    /// Must match `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    static let backgroundTaskIdentifier = "com.hardheaded.streamen.content-index"

    /// Registers the processing task's handler. Called from `StreamenApp.init`,
    /// because iOS requires registration before launch finishes — and a
    /// background launch for the task runs no launch `.task`, so the container
    /// is configured here too.
    static func registerBackgroundProcessing(container: ModelContainer) {
        #if os(iOS)
            shared.configure(container: container)
            BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: .main) { task in
                guard let task = task as? BGProcessingTask else { return }
                MainActor.assumeIsolated {
                    shared.runBackgroundProcessing(task)
                }
            }
        #endif
    }

    /// Asks iOS for an overnight run when titles are still unindexed. Called
    /// when the app goes to the background; asking again replaces the
    /// pending request, so repeat calls are harmless.
    func scheduleBackgroundProcessingIfNeeded() {
        #if os(iOS)
            guard state != .upToDate, state != .unavailable else { return }
            let request = BGProcessingTaskRequest(identifier: Self.backgroundTaskIdentifier)
            request.requiresExternalPower = true
            request.requiresNetworkConnectivity = true
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                Logger.indexing.info("Background indexing not scheduled: \(error.localizedDescription)")
            }
        #endif
    }

    #if os(iOS)
        /// Runs a pass for the processing task, ending it when the pass ends
        /// and cancelling the pass if iOS takes the time back first.
        private func runBackgroundProcessing(_ backgroundTask: BGProcessingTask) {
            kick()
            guard let pass = indexingTask else {
                backgroundTask.setTaskCompleted(success: state == .upToDate)
                return
            }
            backgroundTask.expirationHandler = { @Sendable in
                pass.cancel()
            }
            Task {
                await pass.value
                // Not finished (expired or interrupted): ask for another night.
                scheduleBackgroundProcessingIfNeeded()
                backgroundTask.setTaskCompleted(success: state == .upToDate)
            }
        }
    #endif
}
