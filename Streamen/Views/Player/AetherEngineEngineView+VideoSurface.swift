//
//  AetherEngineEngineView+VideoSurface.swift
//  Streamen
//
//  Hosts AetherEngine's player view. The bridge keeps AetherEngine out of
//  Streamen's compile, so `AetherPlayerSurface` is out of reach; the session binds
//  its own `AetherPlayerView` (what the surface does) and this mounts it.
//

#if !os(visionOS)

    import StreamenAetherBridge
    import SwiftUI

    #if canImport(UIKit)
        import UIKit

        struct AetherEngineVideoSurface: UIViewRepresentable {
            let videoView: StreamenAetherPlatformView?

            func makeUIView(context _: Context) -> AetherEngineHostView {
                let view = AetherEngineHostView()
                view.backgroundColor = .black
                return view
            }

            func updateUIView(_ view: AetherEngineHostView, context _: Context) {
                view.install(videoView)
            }
        }

    #elseif canImport(AppKit)
        import AppKit

        struct AetherEngineVideoSurface: NSViewRepresentable {
            let videoView: StreamenAetherPlatformView?

            func makeNSView(context _: Context) -> AetherEngineHostView {
                let view = AetherEngineHostView()
                view.wantsLayer = true
                view.layer?.backgroundColor = NSColor.black.cgColor
                return view
            }

            func updateNSView(_ view: AetherEngineHostView, context _: Context) {
                view.install(videoView)
            }
        }
    #endif

    final class AetherEngineHostView: StreamenAetherPlatformView {
        private weak var hosted: StreamenAetherPlatformView?

        func install(_ videoView: StreamenAetherPlatformView?) {
            guard hosted !== videoView else { return }
            hosted?.removeFromSuperview()
            hosted = nil
            guard let videoView else { return }
            videoView.frame = bounds
            #if canImport(UIKit)
                videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            #else
                videoView.autoresizingMask = [.width, .height]
            #endif
            addSubview(videoView)
            hosted = videoView
        }
    }

#endif
