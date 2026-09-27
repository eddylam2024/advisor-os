// Draws the Advisor OS app icon and writes every size into AppIcon.appiconset.
// Style: DesignCode UI kit colours (blue with a coral glow) and a frosted-glass calendar page with a check mark.
// Run: swift scripts/make-icon.swift
import AppKit

let out = URL(fileURLWithPath: "AdvisorOS/Resources/Assets.xcassets/AppIcon.appiconset")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    // macOS icon grid: 824 pt body on a 1024 pt canvas, corner radius about 22% of the body.
    let inset = s * 100 / 1024
    let body = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = body.width * 0.2237
    let shape = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

    // Drop shadow under the whole icon, like system icons.
    NSGraphicsContext.saveGraphicsState()
    let outer = NSShadow()
    outer.shadowColor = color(0x000000, 0.28)
    outer.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    outer.shadowBlurRadius = s * 0.03
    outer.set()
    color(0x3552D6).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    // Base: kit blue, lighter at the top.
    NSGradient(colors: [color(0x7B97F5), color(0x4A6CE6), color(0x2E47C4)], atLocations: [0, 0.55, 1],
               colorSpace: .sRGB)!.draw(in: body, angle: -90)
    // Coral glow, bottom right.
    let coral = NSPoint(x: body.maxX - s * 0.05, y: body.minY + s * 0.02)
    NSGradient(colors: [color(0xF4957B, 0.95), color(0xF08C74, 0.45), color(0xF08C74, 0)], atLocations: [0, 0.45, 1], colorSpace: .sRGB)!
        .draw(fromCenter: coral, radius: 0, toCenter: coral, radius: s * 0.55, options: [])
    // Lavender glow, top left.
    let lavender = NSPoint(x: body.minX + s * 0.05, y: body.maxY - s * 0.08)
    NSGradient(colors: [color(0xC3B5F7, 0.6), color(0xB7A6F2, 0)])!
        .draw(fromCenter: lavender, radius: 0, toCenter: lavender, radius: s * 0.5, options: [])
    // Soft top gloss.
    NSGradient(colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)])!
        .draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Thin light rim.
    let rim = NSBezierPath(roundedRect: body.insetBy(dx: s * 0.003, dy: s * 0.003), xRadius: radius, yRadius: radius)
    rim.lineWidth = s * 0.006
    color(0xFFFFFF, 0.28).setStroke()
    rim.stroke()

    // Frosted-glass calendar page.
    let page = NSRect(x: s * 0.245, y: s * 0.235, width: s * 0.51, height: s * 0.49)
    let pageRadius = page.width * 0.16
    let pagePath = NSBezierPath(roundedRect: page, xRadius: pageRadius, yRadius: pageRadius)
    NSGraphicsContext.saveGraphicsState()
    let pageShadow = NSShadow()
    pageShadow.shadowColor = color(0x10205F, 0.35)
    pageShadow.shadowOffset = NSSize(width: 0, height: -s * 0.018)
    pageShadow.shadowBlurRadius = s * 0.045
    pageShadow.set()
    color(0xFFFFFF, 0.2).setFill()
    pagePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    pagePath.addClip()
    NSGradient(colors: [color(0xFFFFFF, 0.42), color(0xFFFFFF, 0.14)])!.draw(in: page, angle: -90)
    // Header band.
    let header = NSRect(x: page.minX, y: page.maxY - page.height * 0.27, width: page.width, height: page.height * 0.27)
    NSGradient(colors: [color(0xFFFFFF, 0.55), color(0xFFFFFF, 0.35)])!.draw(in: header, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    pagePath.lineWidth = s * 0.008
    color(0xFFFFFF, 0.85).setStroke()
    pagePath.stroke()

    // Binder rings.
    for x in [0.3, 0.7] {
        let ring = NSRect(x: page.minX + page.width * x - s * 0.022, y: page.maxY - s * 0.055, width: s * 0.044, height: s * 0.11)
        let ringPath = NSBezierPath(roundedRect: ring, xRadius: s * 0.022, yRadius: s * 0.022)
        NSGraphicsContext.saveGraphicsState()
        let ringShadow = NSShadow()
        ringShadow.shadowColor = color(0x10205F, 0.3)
        ringShadow.shadowOffset = NSSize(width: 0, height: -s * 0.006)
        ringShadow.shadowBlurRadius = s * 0.012
        ringShadow.set()
        color(0xFFFFFF).setFill()
        ringPath.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    // Check mark.
    let check = NSBezierPath()
    check.move(to: NSPoint(x: page.minX + page.width * 0.25, y: page.minY + page.height * 0.40))
    check.line(to: NSPoint(x: page.minX + page.width * 0.43, y: page.minY + page.height * 0.22))
    check.line(to: NSPoint(x: page.minX + page.width * 0.76, y: page.minY + page.height * 0.58))
    check.lineWidth = s * 0.055
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    NSGraphicsContext.saveGraphicsState()
    let checkShadow = NSShadow()
    checkShadow.shadowColor = color(0x10205F, 0.35)
    checkShadow.shadowOffset = NSSize(width: 0, height: -s * 0.008)
    checkShadow.shadowBlurRadius = s * 0.02
    checkShadow.set()
    color(0xFFFFFF).setStroke()
    check.stroke()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        try! render(base * scale).write(to: out.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let json = try! JSONSerialization.data(withJSONObject: ["images": images, "info": ["author": "xcode", "version": 1]],
                                       options: [.prettyPrinted, .sortedKeys])
try! json.write(to: out.appendingPathComponent("Contents.json"))
try! render(1024).write(to: URL(fileURLWithPath: "design/AppIcon-1024.png"))
print("Wrote \(images.count) icon sizes and design/AppIcon-1024.png")
