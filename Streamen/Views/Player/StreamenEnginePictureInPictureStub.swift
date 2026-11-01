//
//  StreamenEnginePictureInPictureStub.swift
//  Streamen
//
//  StreamenEngine compiles `PictureInPictureBridge` for iOS, macOS and tvOS only,
//  so `StreamenEngineCoordinator` doesn't build for visionOS. This stand-in has
//  the same surface and never supports Picture in Picture there.
//

#if os(visionOS)

    import StreamenEngine

    @MainActor
    final class PictureInPictureBridge {
        let isSupported = false
        let isActive = false

        init(session _: PlayerSession, mediaInfo _: MediaInfo) {}

        func toggle() {}
    }

#endif
