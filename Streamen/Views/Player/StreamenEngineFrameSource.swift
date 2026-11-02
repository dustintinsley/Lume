//
//  StreamenEngineFrameSource.swift
//  Streamen
//
//  Feeds the folded-screen reflection (`FoldedReflectionView`) from
//  StreamenEngine. Its `SystemRenderer` presents decoded frames through an
//  `AVSampleBufferDisplayLayer` (`StreamenDisplayLayer`), which the coordinator
//  exposes; that layer's renderer hands back the frame it is showing
//  (`displayedPixelBuffer()`, iOS 17.4), so nothing in the engine changes.
//  StreamenEngine has no Fill/Fit switch, so the picture is always fitted.
//

#if os(iOS)

    import AVFoundation
    import CoreVideo

    final class StreamenEngineFrameSource: ReflectionFrameSource {
        /// Set by the engine view; weak so the source never outlives playback.
        weak var coordinator: StreamenEngineCoordinator?

        func latestFrame() -> CVPixelBuffer? {
            coordinator?.displayLayer?.sampleBufferRenderer.displayedPixelBuffer()
        }
    }

#endif
