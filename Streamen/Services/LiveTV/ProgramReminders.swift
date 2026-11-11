//
//  ProgramReminders.swift
//  Streamen
//
//  Reminders for upcoming guide programmes. Setting one schedules a local
//  notification for the programme's start; tapping it (or its Watch action)
//  tunes the channel through the same `streamen://play/live/` link the widgets
//  use. The link is handed to `MainTabView` as `pendingLink` rather than opened
//  as a URL, which on macOS would open a second main window.
//

#if !os(tvOS)
    import Foundation
    import OSLog
    import UserNotifications

    @MainActor
    @Observable
    final class ProgramReminders {
        static let shared = ProgramReminders()

        nonisolated struct Reminder: Codable, Equatable, Identifiable {
            let streamID: String
            let channelName: String
            let title: String
            let start: Date

            var id: String {
                ProgramReminders.id(streamID: streamID, start: start)
            }
        }

        /// Why a reminder couldn't be set.
        enum Failure: Error {
            /// Notifications are turned off for Streamen in System Settings.
            case notAuthorized
            case schedulingFailed
        }

        private(set) var reminders: [String: Reminder] = [:]
        /// A tapped reminder's channel link, waiting for `MainTabView` to play it.
        var pendingLink: URL?
        /// A reminder was asked for with notifications turned off; `MainTabView`
        /// explains where to turn them on.
        var showsPermissionAlert = false

        private static let defaultsKey = "programReminders"
        private static let categoryID = "programReminder"
        private static let watchActionID = "watch"
        private static let linkKey = "link"
        private static let logger = Logger(subsystem: "hardheaded.streamen", category: "ProgramReminders")

        private let center = UNUserNotificationCenter.current()
        private let delegate = Delegate()

        private init() {
            load()
        }

        /// Installs the notification delegate and the Watch action. Called from
        /// the app delegate's launch hook, so a tap that launched the app is
        /// delivered.
        func activate() {
            center.delegate = delegate
            let watch = UNNotificationAction(identifier: Self.watchActionID, title: String(localized: "Watch"), options: [.foreground])
            center.setNotificationCategories([
                UNNotificationCategory(identifier: Self.categoryID, actions: [watch], intentIdentifiers: [])
            ])
        }

        nonisolated static func id(streamID: String, start: Date) -> String {
            "\(streamID)|\(Int(start.timeIntervalSince1970))"
        }

        func isSet(streamID: String, start: Date) -> Bool {
            reminders[Self.id(streamID: streamID, start: start)] != nil
        }

        /// Schedules a notification for `start`, asking for permission the first
        /// time.
        func set(streamID: String, channelName: String, title: String, start: Date) async throws(Failure) {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { throw .notAuthorized }
            let reminder = Reminder(streamID: streamID, channelName: channelName, title: title, start: start)

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = String(localized: "Starting now on \(channelName)")
            content.sound = .default
            content.categoryIdentifier = Self.categoryID
            content.threadIdentifier = Self.categoryID
            if let link = WidgetDeepLink.play(kind: .live, id: streamID) {
                content.userInfo = [Self.linkKey: link.absoluteString]
            }
            let interval = max(1, start.timeIntervalSinceNow)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
            } catch {
                Self.logger.error("Couldn't schedule a reminder: \(error.localizedDescription, privacy: .public)")
                throw .schedulingFailed
            }
            reminders[reminder.id] = reminder
            save()
        }

        func cancel(streamID: String, start: Date) {
            let id = Self.id(streamID: streamID, start: start)
            center.removePendingNotificationRequests(withIdentifiers: [id])
            reminders[id] = nil
            save()
        }

        fileprivate func delivered(id: String) {
            guard reminders[id] != nil else { return }
            reminders[id] = nil
            save()
        }

        private func load() {
            guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
                  let saved = try? JSONDecoder().decode([Reminder].self, from: data) else { return }
            // A reminder whose programme has started has fired (or was missed).
            let now = Date()
            reminders = Dictionary(saved.filter { $0.start > now }.map { ($0.id, $0) }) { first, _ in first }
            if reminders.count != saved.count {
                save()
            }
        }

        private func save() {
            guard let data = try? JSONEncoder().encode(Array(reminders.values)) else { return }
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }

        private final class Delegate: NSObject, UNUserNotificationCenterDelegate {
            /// Shows the banner even while Streamen is in front.
            func userNotificationCenter(
                _: UNUserNotificationCenter,
                willPresent notification: UNNotification
            ) async -> UNNotificationPresentationOptions {
                let id = notification.request.identifier
                await MainActor.run { ProgramReminders.shared.delivered(id: id) }
                return [.banner, .list, .sound]
            }

            func userNotificationCenter(
                _: UNUserNotificationCenter,
                didReceive response: UNNotificationResponse
            ) async {
                let request = response.notification.request
                guard request.content.categoryIdentifier == ProgramReminders.categoryID else { return }
                let id = request.identifier
                let link = (request.content.userInfo[ProgramReminders.linkKey] as? String).flatMap(URL.init(string:))
                let tunes = response.actionIdentifier == UNNotificationDefaultActionIdentifier
                    || response.actionIdentifier == ProgramReminders.watchActionID
                await MainActor.run {
                    let reminders = ProgramReminders.shared
                    reminders.delivered(id: id)
                    if tunes, let link {
                        reminders.pendingLink = link
                    }
                }
            }
        }
    }
#endif
