import AppKit

// Generates every Streamen app icon asset from the vector logo in Logo.swift:
// the primary icon (Streamen.icon, SVG layer), an alternate iOS icon set per
// colourway at every size, the picker / Dock artwork, and the tvOS layered
// icons and Top Shelf banners. To add or change a colourway, edit `variants`
// here and the matching case in AppIconChoice (AppIconSettings.swift), and
// list any new set in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
//
// Run through Scripts/generate-icons.sh rather than directly.
// Usage: generate <Assets.xcassets path> <Streamen.icon path> <preview dir>

let variants: [Variant] = [
    Variant(id: "Midnight", title: "Midnight", background: RGB(0x0E1626), logo: RGB(0x4FD1FF)),
    Variant(id: "Onyx", title: "Onyx", background: RGB(0x0B0B0D), logo: RGB(0xFFFFFF)),
    Variant(id: "Cobalt", title: "Cobalt", background: RGB(0x0B3184), logo: RGB(0xBFE6FF)),
    Variant(id: "Plum", title: "Plum", background: RGB(0x25123D), logo: RGB(0xFF8AD8)),
    Variant(id: "Forest", title: "Forest", background: RGB(0x0C261E), logo: RGB(0x6EF0B5)),
    Variant(id: "Ember", title: "Ember", background: RGB(0x2A120C), logo: RGB(0xFFA24C)),
    Variant(id: "Daylight", title: "Daylight", background: RGB(0xEEF3FA), logo: RGB(0x1450D9)),
    Variant(id: "Paper", title: "Paper", background: RGB(0xFFFFFF), logo: RGB(0x141821)),
    Variant(id: "Sky", title: "Sky", background: RGB(0xD6E9FF), logo: RGB(0x0A3A8C)),
    Variant(id: "Sunny", title: "Sunny", background: RGB(0xFFD84D), logo: RGB(0x1E2230)),
    Variant(id: "Blush", title: "Blush", background: RGB(0xFFE1EA), logo: RGB(0xA3164F)),
    Variant(id: "Mint", title: "Mint", background: RGB(0xD9F5E8), logo: RGB(0x0D5E44)),
]
let midnight = variants[0], daylight = variants[6]

let args = CommandLine.arguments
let assets = args[1], iconBundle = args[2], previewDir = args[3]
let fm = FileManager.default

func writeJSON(_ object: Any, to path: String) {
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try! fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try! data.write(to: URL(fileURLWithPath: path))
}

func resetDir(_ path: String) {
    try? fm.removeItem(atPath: path)
    try! fm.createDirectory(atPath: path, withIntermediateDirectories: true)
}

let info: [String: Any] = ["author": "xcode", "version": 1]

// MARK: - iOS / iPadOS app icon sets (every slot of Xcode's "All Sizes")

/// (points, scales)
let iosSlots: [(Double, [Int])] = [
    (20, [2, 3]), (29, [2, 3]), (38, [2, 3]), (40, [2, 3]),
    (60, [2, 3]), (64, [2, 3]), (68, [2]), (76, [2]), (83.5, [2]),
]

func pointsLabel(_ p: Double) -> String {
    p == p.rounded() ? String(Int(p)) : String(p)
}

/// One appiconset; `dark` adds a dark-appearance copy of every image.
func writeAppIconSet(name: String, light: Variant, dark: Variant? = nil) {
    let dir = "\(assets)/\(name).appiconset"
    resetDir(dir)
    var images: [[String: Any]] = []
    func add(_ v: Variant, appearance: String?) {
        let suffix = appearance.map { "-\($0)" } ?? ""
        let appearances: [[String: String]]? = appearance.map { [["appearance": "luminosity", "value": $0]] }
        var entry: [String: Any] = ["idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "icon\(suffix)-1024.png"]
        if let appearances { entry["appearances"] = appearances }
        writePNG(renderSquare(v, size: 1024), to: "\(dir)/icon\(suffix)-1024.png")
        images.append(entry)
        for (points, scales) in iosSlots {
            for scale in scales {
                let px = Int((points * Double(scale)).rounded())
                let file = "icon\(suffix)-\(pointsLabel(points))@\(scale)x.png"
                writePNG(renderSquare(v, size: px), to: "\(dir)/\(file)")
                var e: [String: Any] = [
                    "idiom": "universal", "platform": "ios", "scale": "\(scale)x",
                    "size": "\(pointsLabel(points))x\(pointsLabel(points))", "filename": file,
                ]
                if let appearances { e["appearances"] = appearances }
                images.append(e)
            }
        }
    }
    add(light, appearance: nil)
    if let dark { add(dark, appearance: "dark") }
    writeJSON(["images": images, "info": info], to: "\(dir)/Contents.json")
}

for v in variants.dropFirst() { writeAppIconSet(name: "Streamen\(v.id)", light: v) }

// MARK: - Picker previews / Mac Dock artwork (flat squares at the sizes shown)

for v in variants {
    let dir = "\(assets)/AppIconArt\(v.id).imageset"
    resetDir(dir)
    // The picker tile is 56pt; the Mac Dock icon is drawn from the 1024.
    for (scale, px) in [(1, 56), (2, 112), (3, 168)] {
        writePNG(renderSquare(v, size: px), to: "\(dir)/art@\(scale)x.png")
    }
    writePNG(renderSquare(v, size: 1024), to: "\(dir)/art-1024.png")
    writeJSON([
        "images": [
            ["idiom": "universal", "scale": "1x", "filename": "art@1x.png"],
            ["idiom": "universal", "scale": "2x", "filename": "art@2x.png"],
            ["idiom": "universal", "scale": "3x", "filename": "art@3x.png"],
            ["idiom": "mac", "scale": "2x", "filename": "art-1024.png"],
        ],
        "info": info,
    ], to: "\(dir)/Contents.json")
}

// MARK: - Primary icon (Icon Composer): vector logo layer over a solid fill

func svgLogo(color: RGB, canvas: CGFloat = 1024, fraction: CGFloat = 0.62) -> String {
    let scale = canvas * fraction / Logo.bounds.width
    let tx = canvas / 2 - Logo.bounds.midX * scale, ty = canvas / 2 - Logo.bounds.midY * scale
    func f(_ v: CGFloat) -> String { String(format: "%.2f", v) }
    func pt(_ p: CGPoint) -> String { "\(f(p.x)) \(f(p.y))" }
    // TV body: the rounded quad, with corner arcs resolved to tangent points.
    let corners = [CGPoint(x: 317, y: 320), CGPoint(x: 727, y: 320), CGPoint(x: 727, y: 706), CGPoint(x: 317, y: 763)]
    let r: CGFloat = 26
    var body = ""
    for i in 0 ..< 4 {
        let p = corners[i], a = corners[(i + 3) % 4], b = corners[(i + 1) % 4]
        func unit(_ q: CGPoint) -> CGPoint { let d = hypot(q.x - p.x, q.y - p.y); return CGPoint(x: (q.x - p.x) / d, y: (q.y - p.y) / d) }
        let ua = unit(a), ub = unit(b)
        let theta = acos(ua.x * ub.x + ua.y * ub.y)
        let d = r / tan(theta / 2)
        let t1 = CGPoint(x: p.x + ua.x * d, y: p.y + ua.y * d), t2 = CGPoint(x: p.x + ub.x * d, y: p.y + ub.y * d)
        body += (i == 0 ? "M" : "L") + pt(t1) + " A\(f(r)) \(f(r)) 0 0 1 " + pt(t2) + " "
    }
    body += "Z"
    func arcPoint(_ c: CGPoint, _ r: CGFloat, _ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
        let a = atan2(dy, dx); return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
    }
    let oc = CGPoint(x: 356, y: 513), ic = CGPoint(x: 373, y: 513)
    let waves = "M\(pt(arcPoint(oc, 238, -186, -148))) A238 238 0 0 0 \(pt(arcPoint(oc, 238, -184, 149))) "
        + "M\(pt(arcPoint(ic, 166, -135, -96))) A166 166 0 0 0 \(pt(arcPoint(ic, 166, -135, 97)))"
    let antenna = "M380 245 L462 318 M543 245 L462 318"
    let hex = String(format: "#%02X%02X%02X", Int(color.r * 255), Int(color.g * 255), Int(color.b * 255))
    return """
    <svg xmlns="http://www.w3.org/2000/svg" width="\(Int(canvas))" height="\(Int(canvas))" viewBox="0 0 \(Int(canvas)) \(Int(canvas))">
      <g transform="translate(\(f(tx)) \(f(ty))) scale(\(String(format: "%.5f", scale)))" fill="none" stroke="\(hex)" stroke-linecap="round" stroke-linejoin="round">
        <path d="\(body)" stroke-width="36"/>
        <path d="\(waves) \(antenna)" stroke-width="36"/>
        <path d="M460 438 L607 527 L460 617 Z" fill="\(hex)" stroke-width="6"/>
      </g>
    </svg>

    """
}

resetDir("\(iconBundle)/Assets")
try! svgLogo(color: midnight.logo).write(toFile: "\(iconBundle)/Assets/streamen-logo.svg", atomically: true, encoding: .utf8)
func p3(_ c: RGB) -> String { String(format: "srgb:%.5f,%.5f,%.5f,1.00000", c.r, c.g, c.b) }
writeJSON([
    "fill": ["solid": p3(midnight.background)],
    "groups": [[
        "layers": [[
            "blend-mode": "normal", "glass": false, "hidden": false,
            "image-name": "streamen-logo.svg", "name": "streamen",
            "position": ["scale": 1, "translation-in-points": [0, 0]],
        ]],
        "shadow": ["kind": "none", "opacity": 0],
        "specular": false,
        "translucency": ["enabled": false, "value": 0],
    ]],
    "supported-platforms": ["circles": ["watchOS"], "squares": "shared"],
], to: "\(iconBundle)/icon.json")

// MARK: - tvOS layered icons and Top Shelf

/// The front (logo) layer of a tvOS icon: transparent, logo centred.
func tvFront(_ v: Variant, width: Int, height: Int) -> CGContext {
    let ctx = makeContext(width: width, height: height, opaque: false)
    Logo.draw(in: ctx, rect: CGRect(x: 0, y: 0, width: width, height: height), color: v.logo.cg, fraction: 0.66)
    return ctx
}

/// The back layer: the background colour with a soft glow behind the logo.
func tvBack(_ v: Variant, width: Int, height: Int, glow: CGFloat = 0.10) -> CGContext {
    let ctx = makeContext(width: width, height: height, opaque: true)
    ctx.setFillColor(v.background.cg)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let colors = [v.logo.cg.copy(alpha: glow)!, v.logo.cg.copy(alpha: 0)!] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
    let center = CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
    ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center,
                           endRadius: CGFloat(max(width, height)) * 0.55, options: [])
    return ctx
}

func writeImageStack(_ dir: String, v: Variant, sizes: [(scale: Int, w: Int, h: Int)]) {
    resetDir(dir)
    writeJSON(["info": info, "layers": [["filename": "Front.imagestacklayer"], ["filename": "Back.imagestacklayer"]]],
              to: "\(dir)/Contents.json")
    for (layer, render) in [("Front", tvFront), ("Back", { tvBack($0, width: $1, height: $2) })] {
        let ldir = "\(dir)/\(layer).imagestacklayer"
        writeJSON(["info": info], to: "\(ldir)/Contents.json")
        var images: [[String: Any]] = []
        for s in sizes {
            let file = "\(layer.lowercased())_\(s.w)x\(s.h).png"
            writePNG(render(v, s.w, s.h), to: "\(ldir)/Content.imageset/\(file)")
            images.append(["idiom": "tv", "scale": "\(s.scale)x", "filename": file])
        }
        writeJSON(["images": images, "info": info], to: "\(ldir)/Content.imageset/Contents.json")
    }
}

/// Top Shelf: logo plus the "Streamen" wordmark, centred on a glow.
func topShelf(_ v: Variant, width: Int, height: Int) -> CGContext {
    let ctx = tvBack(v, width: width, height: height, glow: 0.16)
    let h = CGFloat(height)
    let logoHeight = h * 0.30
    let logoWidth = logoHeight * Logo.bounds.width / Logo.bounds.height
    let fontSize = h * 0.16
    let base = NSFont.systemFont(ofSize: fontSize, weight: .regular)
    let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: fontSize) } ?? base
    let text = NSAttributedString(string: "Streamen", attributes: [
        .font: font, .foregroundColor: NSColor.white, .kern: fontSize * 0.01,
    ])
    let textSize = text.size()
    let gap = h * 0.045
    let total = logoWidth + gap + textSize.width
    let x0 = (CGFloat(width) - total) / 2
    Logo.draw(in: ctx, rect: CGRect(x: x0, y: (h - logoHeight) / 2, width: logoWidth, height: logoHeight),
              color: v.logo.cg, fraction: logoWidth / logoHeight)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    // Optically centre the wordmark on the logo: cap height, not line height.
    let textY = (h - font.capHeight) / 2 - (font.ascender - font.capHeight)
    text.draw(at: NSPoint(x: x0 + logoWidth + gap, y: textY))
    NSGraphicsContext.restoreGraphicsState()
    return ctx
}

let brand = "\(assets)/Streamen.brandassets"
writeImageStack("\(brand)/App Icon.imagestack", v: midnight, sizes: [(1, 400, 240), (2, 800, 480)])
writeImageStack("\(brand)/App Icon - App Store.imagestack", v: midnight, sizes: [(1, 1280, 768)])
for (name, w, file) in [("Top Shelf Image", 1920, "topshelf"), ("Top Shelf Image Wide", 2320, "topshelfwide")] {
    let dir = "\(brand)/\(name).imageset"
    resetDir(dir)
    writePNG(topShelf(midnight, width: w, height: 720), to: "\(dir)/\(file)_1x.png")
    writePNG(topShelf(midnight, width: w * 2, height: 1440), to: "\(dir)/\(file)_2x.png")
    writeJSON(["images": [
        ["idiom": "tv", "scale": "1x", "filename": "\(file)_1x.png"],
        ["idiom": "tv", "scale": "2x", "filename": "\(file)_2x.png"],
    ], "info": info], to: "\(dir)/Contents.json")
}

// Previews for review.
writePNG(topShelf(midnight, width: 2320, height: 720), to: "\(previewDir)/topshelf-wide.png")
let tvPreview = tvBack(midnight, width: 800, height: 480)
let front = tvFront(midnight, width: 800, height: 480).makeImage()!
tvPreview.saveGState(); tvPreview.translateBy(x: 0, y: 480); tvPreview.scaleBy(x: 1, y: -1)
tvPreview.draw(front, in: CGRect(x: 0, y: 0, width: 800, height: 480)); tvPreview.restoreGState()
writePNG(tvPreview, to: "\(previewDir)/tv-icon.png")
print("done")
