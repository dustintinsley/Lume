//
//  AetherEngineFrameSource.swift
//  Streamen
//
//  Feeds the folded-screen reflection (`FoldedReflectionView`) from
//  AetherEngine, the same two ways its Hue source reads frames: the native
//  route through an `AVPlayerItemVideoOutput` tap on its `AVPlayer`, the
//  software route (interlaced live channels) from its sample-buffer layer.
//  AetherEngine has no Fill/Fit switch, so the picture is always fitted.
//

#if os(iOS)

    import CoreVideo
    import StreamenAetherBridge

    final class AetherEngineFrameSource: ReflectionFrameSource {
        /// Set by the engine view; weak so the source never outlives playback.
        weak var coordinator: AetherEngineCoordinator?
        private let avTap = AVPlayerFrameSource()

        func latestFrame() -> CVPixelBuffer? {
            guard let session = coordinator?.session, session.isSampleable else { return nil }
            if let player = session.nativePlayer {
                if avTap.player !== player { avTap.player = player }
                return avTap.latestFrame()
            }
            return session.displayedSoftwareFrame()
        }

        func stop() {
            avTap.stop()
        }
    }

#endif
