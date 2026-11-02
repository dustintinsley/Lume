//
//  KSPlayerFrameSource.swift
//  Streamen
//
//  Feeds the folded-screen reflection (`FoldedReflectionView`) from KSPlayer,
//  whichever of its two players is running: KSMEPlayer (FFmpeg) keeps the
//  frame it last drew, so read it on each tick; KSAVPlayer wraps an AVPlayer,
//  so tap that the same way the AVPlayer engine is tapped.
//

#if os(iOS)

    import CoreVideo
    import KSPlayer

    final class KSPlayerFrameSource: ReflectionFrameSource {
        /// Set by the engine view; weak so the source never outlives playback.
        weak var coordinator: KSVideoPlayer.Coordinator?
        private let avTap = AVPlayerFrameSource()

        var fillsUpperScreen: Bool {
            coordinator?.isScaleAspectFill ?? false
        }

        func latestFrame() -> CVPixelBuffer? {
            switch coordinator?.playerLayer?.player {
            case let player as KSMEPlayer:
                return player.videoOutput?.pixelBuffer?.cvPixelBuffer
            case let player as KSAVPlayer:
                if avTap.player !== player.player { avTap.player = player.player }
                return avTap.latestFrame()
            default:
                return nil
            }
        }

        func stop() {
            avTap.stop()
        }
    }

#endif
