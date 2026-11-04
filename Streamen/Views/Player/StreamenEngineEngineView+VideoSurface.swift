import StreamenEngine
import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

// MARK: - Video surface

// Hosts the engine's `AVSampleBufferDisplayLayer` in the view hierarchy, kept in
// a companion file so `StreamenEngineEngineView` stays under the file-length limit.
#if canImport(UIKit)
    struct StreamenEngineVideoSurface: UIViewRepresentable {
        @ObservedObject var coordinator: StreamenEngineCoordinator

        func makeUIView(context _: Context) -> StreamenEngineHostView {
            StreamenEngineHostView()
        }

        func updateUIView(_ view: StreamenEngineHostView, context _: Context) {
            view.install(layer: coordinator.displayLayer)
        }
    }

    final class StreamenEngineHostView: UIView {
        private weak var hosted: StreamenDisplayLayer?

        func install(layer: StreamenDisplayLayer?) {
            guard hosted !== layer else { return }
            hosted?.removeFromSuperlayer()
            hosted = nil
            if let layer {
                layer.frame = bounds
                self.layer.addSublayer(layer)
                hosted = layer
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hosted?.frame = bounds
            CATransaction.commit()
        }
    }

#elseif canImport(AppKit)
    struct StreamenEngineVideoSurface: NSViewRepresentable {
        @ObservedObject var coordinator: StreamenEngineCoordinator

        func makeNSView(context _: Context) -> StreamenEngineHostView {
            let view = StreamenEngineHostView()
            view.wantsLayer = true
            return view
        }

        func updateNSView(_ view: StreamenEngineHostView, context _: Context) {
            view.install(layer: coordinator.displayLayer)
        }
    }

    final class StreamenEngineHostView: NSView {
        private weak var hosted: StreamenDisplayLayer?

        func install(layer: StreamenDisplayLayer?) {
            guard hosted !== layer else { return }
            hosted?.removeFromSuperlayer()
            hosted = nil
            if let layer {
                layer.frame = bounds
                self.layer?.addSublayer(layer)
                hosted = layer
            }
        }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hosted?.frame = bounds
            CATransaction.commit()
        }
    }
#endif
