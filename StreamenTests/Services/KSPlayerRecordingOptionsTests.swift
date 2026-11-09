import Foundation
import KSPlayer
@testable import Streamen
import Testing

/// A recording's HLS playlist is served without `Accept-Ranges`, so FFmpeg
/// reports its connection unseekable and KSPlayer drops skips and scrubs.
@MainActor
struct KSPlayerRecordingOptionsTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func recording(status: ServerRecordingStatus) -> ServerRecording {
        ServerRecording(
            id: RecordingID(UUID()),
            title: "Late Show",
            start: start,
            end: start.addingTimeInterval(3600),
            status: status,
            createdAt: start
        )
    }

    private func options(for url: String, status: ServerRecordingStatus = .completed) -> KSOptions {
        let media = PlayableMedia.recording(
            recording(status: status),
            playback: RecordingPlayback(url: URL(string: url)!),
            startTime: 0,
            now: start.addingTimeInterval(600)
        )
        return KSPlayerOptionsFactory.make(for: media)
    }

    @Test func `a recording playlist is declared seekable`() {
        let finished = options(for: "http://dvr.local:8090/play/x/1/sig/index.m3u8")
        let capturing = options(for: "http://dvr.local:8090/play/x/1/sig/index.m3u8", status: .recording)
        #expect(finished.formatContextOptions["seekable"] as? Int == 1)
        #expect(capturing.formatContextOptions["seekable"] as? Int == 1)
        #expect(capturing.formatContextOptions["live_start_index"] as? Int == 0)
    }

    @Test func `a recording served as one file is left to the server`() {
        let file = options(for: "http://dispatcharr.local/api/recordings/7/file.mkv")
        #expect(file.formatContextOptions["seekable"] == nil)
    }
}
