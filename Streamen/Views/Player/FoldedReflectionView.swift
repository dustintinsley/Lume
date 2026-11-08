//
//  FoldedReflectionView.swift
//  Streamen
//
//  The lower-screen half of the folded player (see `FoldedPlayerLayout`): a
//  mirrored, faded copy of the picture on the upper screen, as if the video
//  were reflecting off the lower panel. It is a cheap imitation rather than a
//  second render: up to 30 times a second it takes the engine's latest
//  decoded frame, shrinks it, flips it, optionally blurs it and hands the
//  result to a plain layer under a fade-out mask.
//

#if os(iOS)

    import AVFoundation
    import CoreImage
    import SwiftUI
    import UIKit
    import VideoToolbox

    /// Hands the reflection the engine's most recent decoded frame.
    @MainActor
    protocol ReflectionFrameSource: AnyObject {
        func latestFrame() -> CVPixelBuffer?
        /// Whether the engine is filling the upper screen (cropping) rather
        /// than fitting the picture inside it — the player's Fill/Fit button.
        /// Engines without the button always fit.
        var fillsUpperScreen: Bool { get }
        /// The reflection went away; drop any tap the source installed.
        func stop()
    }

    extension ReflectionFrameSource {
        var fillsUpperScreen: Bool {
            false
        }

        func stop() {}
    }

    /// How the reflection looks — Settings ▸ Appearance ▸ iPhone Duo.
    struct ReflectionStyle: Equatable {
        var blurred: Bool
        /// Opacity right at the fold.
        var strength: Double
        /// Share of the lower screen the fade-out spans; transparent below.
        var fadeLength: Double
    }

    /// AVPlayer doesn't expose its frames, so tap the current item with an
    /// `AVPlayerItemVideoOutput`. Installed lazily on the first read and moved
    /// along when the player swaps items (a new episode, a reload).
    final class AVPlayerFrameSource: ReflectionFrameSource {
        /// Set by the engine view once its coordinator is attached.
        weak var player: AVPlayer?
        /// Reads the engine's Fill/Fit state; set alongside `player`.
        var isScaleAspectFill: () -> Bool = { false }
        var fillsUpperScreen: Bool {
            isScaleAspectFill()
        }

        private weak var item: AVPlayerItem?
        private var output: AVPlayerItemVideoOutput?
        private var lastFrame: CVPixelBuffer?

        func latestFrame() -> CVPixelBuffer? {
            guard let current = player?.currentItem else { return nil }
            if current !== item {
                stop()
                let tap = AVPlayerItemVideoOutput(pixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ])
                current.add(tap)
                item = current
                output = tap
            }
            guard let output else { return lastFrame }
            let time = output.itemTime(forHostTime: CACurrentMediaTime())
            if output.hasNewPixelBuffer(forItemTime: time),
               let frame = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil)
            {
                lastFrame = frame
            }
            return lastFrame
        }

        func stop() {
            if let output, let item {
                item.remove(output)
            }
            output = nil
            item = nil
            lastFrame = nil
        }
    }

    /// The reflection as an engine adds it to its layer stack, right above the
    /// video surface: shown on the lower screen while folded, absent otherwise.
    /// The lower screen stays touchable through it, so a tap there reaches the
    /// engine's show/hide-controls gesture just as a tap on the video does —
    /// KSPlayer's gesture only fires where something can be hit, and with the
    /// video moved up, the reflection is all there is down here.
    struct FoldedReflectionLayer: View {
        let source: ReflectionFrameSource
        @Environment(\.playerFold) private var fold
        @AppStorage(PlayerSettings.FoldedReflection.blurKey)
        private var blurred = PlayerSettings.FoldedReflection.blurDefault
        @AppStorage(PlayerSettings.FoldedReflection.strengthKey)
        private var strength = PlayerSettings.FoldedReflection.strengthDefault
        @AppStorage(PlayerSettings.FoldedReflection.fadeLengthKey)
        private var fadeLength = PlayerSettings.FoldedReflection.fadeLengthDefault

        private var style: ReflectionStyle {
            ReflectionStyle(
                blurred: blurred,
                strength: Self.clamp(strength, to: PlayerSettings.FoldedReflection.strengthRange),
                fadeLength: Self.clamp(fadeLength, to: PlayerSettings.FoldedReflection.fadeLengthRange)
            )
        }

        private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
            min(max(value, range.lowerBound), range.upperBound)
        }

        var body: some View {
            if let fold {
                FoldedReflectionView(fold: fold, source: source, style: style)
                    .allowsHitTesting(false)
                    .background(Color.clear.contentShape(Rectangle()))
                    .padding(.top, fold.lowerEdge)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
    }

    struct FoldedReflectionView: UIViewRepresentable {
        let fold: PlayerFold
        let source: ReflectionFrameSource
        let style: ReflectionStyle

        func makeUIView(context _: Context) -> ReflectionView {
            ReflectionView()
        }

        func updateUIView(_ view: ReflectionView, context _: Context) {
            view.configure(fold: fold, source: source, style: style)
        }

        static func dismantleUIView(_ view: ReflectionView, coordinator _: ()) {
            view.tearDown()
        }
    }

    final class ReflectionView: UIView {
        /// Width the frame is shrunk to before filtering. The blur hides the
        /// low resolution; unblurred it still reads as a soft reflection.
        private static let blurredWidth: CGFloat = 320
        private static let sharpWidth: CGFloat = 640
        private static let blurSigma: Double = 7

        private static let context = CIContext(options: [.cacheIntermediates: false])

        private let imageLayer = CALayer()
        private let fadeMask = CAGradientLayer()
        private var displayLink: CADisplayLink?
        private var fold: PlayerFold?
        private var source: ReflectionFrameSource?
        private var style: ReflectionStyle?
        private var lastFrame: CVPixelBuffer?
        private var lastFills = false
        private var transferSession: VTPixelTransferSession?
        /// Reused destination for `shrink`, recreated when the size changes.
        private var shrunk: CVPixelBuffer?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            backgroundColor = .clear
            clipsToBounds = true
            imageLayer.contentsGravity = .resize
            layer.addSublayer(imageLayer)
            fadeMask.colors = [UIColor.white.cgColor, UIColor.clear.cgColor]
            layer.mask = fadeMask
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func configure(fold: PlayerFold, source: ReflectionFrameSource, style: ReflectionStyle) {
            // Strength and fade length live on the layers and apply at once;
            // a new fold, source or blur setting needs the frame drawn again.
            let redraw = fold != self.fold || source !== self.source || style.blurred != self.style?.blurred
            if source !== self.source { self.source?.stop() }
            self.fold = fold
            self.source = source
            if style != self.style {
                self.style = style
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                imageLayer.opacity = Float(style.strength)
                fadeMask.locations = [0, NSNumber(value: style.fadeLength)]
                CATransaction.commit()
            }
            if redraw {
                lastFrame = nil
                setNeedsLayout()
            }
        }

        func tearDown() {
            displayLink?.invalidate()
            displayLink = nil
            source?.stop()
            source = nil
            if let transferSession { VTPixelTransferSessionInvalidate(transferSession) }
            transferSession = nil
            shrunk = nil
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil {
                displayLink?.invalidate()
                displayLink = nil
            } else if displayLink == nil {
                let link = CADisplayLink(target: self, selector: #selector(step))
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
                link.add(to: .main, forMode: .common)
                displayLink = link
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            fadeMask.frame = bounds
            CATransaction.commit()
        }

        @objc private func step() {
            guard let fold, let source, let style, let frame = source.latestFrame() else { return }
            let fills = source.fillsUpperScreen
            // Paused video hands back the same buffer: nothing new to draw,
            // unless the viewer switched between Fill and Fit meanwhile.
            guard frame !== lastFrame || fills != lastFills else { return }
            lastFrame = frame
            lastFills = fills
            render(frame, fold: fold, fills: fills, blurred: style.blurred)
        }

        private func render(_ frame: CVPixelBuffer, fold: PlayerFold, fills: Bool, blurred: Bool) {
            let frameSize = CGSize(width: CVPixelBufferGetWidth(frame), height: CVPixelBufferGetHeight(frame))
            guard frameSize.width > 0, frameSize.height > 0, bounds.width > 0 else { return }

            // Where the engine draws the picture on the upper screen, so the
            // reflection lines up underneath it: mirrored across the fold, the
            // gap between the picture and the fold repeats below. Filling, the
            // picture overflows the upper screen, the gap is negative and the
            // overflow is clipped here just as the engine crops it there.
            let upper = CGRect(x: 0, y: 0, width: bounds.width, height: fold.upperEdge)
            let picture = fills ? Self.fillRect(for: frameSize, in: upper) : AVMakeRect(aspectRatio: frameSize, insideRect: upper)
            let gap = upper.maxY - picture.maxY
            let target = CGRect(x: picture.minX, y: gap, width: picture.width, height: picture.height)

            let width = min(blurred ? Self.blurredWidth : Self.sharpWidth, frameSize.width)
            guard let small = shrink(frame, toWidth: width) else { return }
            let smallHeight = CGFloat(CVPixelBufferGetHeight(small))
            var image = CIImage(cvPixelBuffer: small)
                .transformed(by: CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -smallHeight))
            let extent = image.extent
            if blurred {
                image = image.clampedToExtent()
                    .applyingGaussianBlur(sigma: Self.blurSigma)
                    .cropped(to: extent)
            }
            guard let rendered = Self.context.createCGImage(image, from: extent) else { return }

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            imageLayer.frame = target
            imageLayer.contents = rendered
            CATransaction.commit()
        }

        /// The aspect-fill counterpart of `AVMakeRect`: `size` scaled to cover
        /// `rect`, centred, overflowing it on one axis.
        private static func fillRect(for size: CGSize, in rect: CGRect) -> CGRect {
            let scale = max(rect.width / size.width, rect.height / size.height)
            let width = size.width * scale
            let height = size.height * scale
            return CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height)
        }

        /// Converts and shrinks a decoded frame to a small BGRA buffer in one
        /// VideoToolbox pass. Engines hand over whatever their decoder emits
        /// (KSPlayer's FFmpeg path gives three-plane `y420`, which Core Image
        /// can't read), so everything goes through here first.
        private func shrink(_ frame: CVPixelBuffer, toWidth width: CGFloat) -> CVPixelBuffer? {
            let frameWidth = CGFloat(CVPixelBufferGetWidth(frame))
            let frameHeight = CGFloat(CVPixelBufferGetHeight(frame))
            let targetWidth = Int(width) & ~1
            let targetHeight = Int((width * frameHeight / frameWidth).rounded()) & ~1
            guard targetWidth > 0, targetHeight > 0 else { return nil }

            if let shrunk, CVPixelBufferGetWidth(shrunk) != targetWidth || CVPixelBufferGetHeight(shrunk) != targetHeight {
                self.shrunk = nil
            }
            if shrunk == nil {
                var buffer: CVPixelBuffer?
                let attributes: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()]
                CVPixelBufferCreate(nil, targetWidth, targetHeight, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer)
                shrunk = buffer
            }
            if transferSession == nil {
                VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &transferSession)
            }
            guard let shrunk, let transferSession,
                  VTPixelTransferSessionTransferImage(transferSession, from: frame, to: shrunk) == noErr
            else { return nil }
            return shrunk
        }
    }

#endif
