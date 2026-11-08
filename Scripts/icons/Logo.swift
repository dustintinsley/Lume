import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// The Streamen logo, redrawn as vector geometry on a 1024-point canvas
// (y down), traced from the original 1024px artwork. `draw` re-centres the
// logo's bounding box on the canvas.

struct RGB {
    let r: CGFloat, g: CGFloat, b: CGFloat
    init(_ hex: UInt32) {
        r = CGFloat((hex >> 16) & 0xFF) / 255
        g = CGFloat((hex >> 8) & 0xFF) / 255
        b = CGFloat(hex & 0xFF) / 255
    }
    var cg: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: 1) }
}

struct Variant {
    let id: String       // asset-name suffix
    let title: String
    let background: RGB
    let logo: RGB
}

enum Logo {
    static let stroke: CGFloat = 36
    // Bounding box of the traced geometry, strokes included.
    static let bounds = CGRect(x: 100, y: 227, width: 645, height: 551)

    static func tvBody() -> CGPath {
        let p = CGMutablePath()
        let tl = CGPoint(x: 317, y: 320), tr = CGPoint(x: 727, y: 320)
        let br = CGPoint(x: 727, y: 706), bl = CGPoint(x: 317, y: 763)
        let r: CGFloat = 26
        p.move(to: CGPoint(x: (tl.x + tr.x) / 2, y: tl.y))
        p.addArc(tangent1End: tr, tangent2End: br, radius: r)
        p.addArc(tangent1End: br, tangent2End: bl, radius: r)
        p.addArc(tangent1End: bl, tangent2End: tl, radius: r)
        p.addArc(tangent1End: tl, tangent2End: tr, radius: r)
        p.closeSubpath()
        return p
    }

    static func strokes() -> CGPath {
        let p = CGMutablePath()
        // Waves: arcs of circles centred to the right of them.
        p.addArc(center: CGPoint(x: 356, y: 513), radius: 238,
                 startAngle: atan2(-148, -186), endAngle: atan2(149, -184), clockwise: true)
        p.move(to: CGPoint(x: 238, y: 417))
        p.addArc(center: CGPoint(x: 373, y: 513), radius: 166,
                 startAngle: atan2(-96, -135), endAngle: atan2(97, -135), clockwise: true)
        // Antenna.
        p.move(to: CGPoint(x: 380, y: 245)); p.addLine(to: CGPoint(x: 462, y: 318))
        p.move(to: CGPoint(x: 543, y: 245)); p.addLine(to: CGPoint(x: 462, y: 318))
        return p
    }

    static func play() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 460, y: 438))
        p.addLine(to: CGPoint(x: 607, y: 527))
        p.addLine(to: CGPoint(x: 460, y: 617))
        p.closeSubpath()
        return p
    }

    /// Draws the logo into `ctx` (already y-down), centred in `rect`, with
    /// the logo's width a `fraction` of the rect's shorter side.
    static func draw(in ctx: CGContext, rect: CGRect, color: CGColor, fraction: CGFloat) {
        let side = min(rect.width, rect.height)
        let scale = side * fraction / bounds.width
        ctx.saveGState()
        ctx.translateBy(x: rect.midX, y: rect.midY)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -bounds.midX, y: -bounds.midY)
        ctx.setStrokeColor(color)
        ctx.setFillColor(color)
        ctx.setLineWidth(stroke)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.addPath(tvBody()); ctx.strokePath()
        ctx.addPath(strokes()); ctx.strokePath()
        ctx.addPath(play()); ctx.fillPath()
        // Soften the triangle's points a touch.
        ctx.setLineWidth(6); ctx.addPath(play()); ctx.strokePath()
        ctx.restoreGState()
    }
}

/// A y-down sRGB bitmap context.
func makeContext(width: Int, height: Int, opaque: Bool) -> CGContext {
    let ctx = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast).rawValue
    )!
    ctx.translateBy(x: 0, y: CGFloat(height))
    ctx.scaleBy(x: 1, y: -1)
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    return ctx
}

func writePNG(_ ctx: CGContext, to path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

/// A square, full-bleed icon (the system masks the corners).
func renderSquare(_ v: Variant, size: Int, fraction: CGFloat = 0.62) -> CGContext {
    let ctx = makeContext(width: size, height: size, opaque: true)
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    ctx.setFillColor(v.background.cg); ctx.fill(rect)
    Logo.draw(in: ctx, rect: rect, color: v.logo.cg, fraction: fraction)
    return ctx
}
