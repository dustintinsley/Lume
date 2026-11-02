//
//  VLCPlayerFrameSource.swift
//  Streamen
//
//  Feeds the folded-screen reflection (`FoldedReflectionView`) from VLCKit.
//  VLC 4 on iOS renders into an `AVSampleBufferDisplayLayer` (the surface its
//  Picture in Picture needs), which it inserts into our host view through
//  `VLCDrawable.addSubview`. That layer's renderer can hand back the frame it
//  is showing (`displayedPixelBuffer()`, iOS 17.4), so find the layer once
//  and ask it on each tick. VLC has no Fill/Fit switch, so the picture is
//  always fitted.
//

#if os(iOS)

    import AVFoundation
    import CoreVideo
    import UIKit

    final class VLCPlayerFrameSource: ReflectionFrameSource {
        /// Set by the engine view; weak so the source never outlives playback.
        weak var coordinator: VLCPlayerCoordinator?
        private weak var displayLayer: AVSampleBufferDisplayLayer?

        var fillsUpperScreen: Bool {
            false
        }

        func latestFrame() -> CVPixelBuffer? {
            // VLC replaces its surface when the video output restarts (a new
            // stream, a track change), so look again once ours is detached.
            if displayLayer?.superlayer == nil {
                displayLayer = coordinator?.hostView.flatMap { Self.displayLayer(in: $0.layer) }
            }
            return displayLayer?.sampleBufferRenderer.displayedPixelBuffer()
        }

        func stop() {
            displayLayer = nil
        }

        private static func displayLayer(in layer: CALayer) -> AVSampleBufferDisplayLayer? {
            if let found = layer as? AVSampleBufferDisplayLayer { return found }
            for sublayer in layer.sublayers ?? [] {
                if let found = displayLayer(in: sublayer) { return found }
            }
            return nil
        }
    }

#endif
