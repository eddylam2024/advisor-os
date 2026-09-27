// Draws the Advisor OS app icon (kit blue gradient, glass calendar) and writes AppIcon.appiconset.
// Run: swift scripts/make-icon.swift
import AppKit

let out = URL(fileURLWithPath: "AdvisorOS/Resources/Assets.xcassets/AppIcon.appiconset")

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.1, body = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let squircle = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)
    NSGradient(colors: [NSColor(red: 0.43, green: 0.55, blue: 0.94, alpha: 1), NSColor(red: 0.24, green: 0.39, blue: 0.87, alpha: 1),
                        NSColor(red: 0.94, green: 0.55, blue: 0.45, alpha: 1)], atLocations: [0, 0.6, 1],
               colorSpace: .deviceRGB)!.draw(in: squircle, angle: -60)
    // Glass calendar card
    let card = NSRect(x: body.minX + body.width * 0.2, y: body.minY + body.height * 0.18, width: body.width * 0.6, height: body.height * 0.6)
    let cardPath = NSBezierPath(roundedRect: card, xRadius: card.width * 0.14, yRadius: card.width * 0.14)
    NSColor(white: 1, alpha: 0.28).setFill(); cardPath.fill()
    NSColor(white: 1, alpha: 0.85).setStroke(); cardPath.lineWidth = s * 0.012; cardPath.stroke()
    let header = NSBezierPath(rect: NSRect(x: card.minX, y: card.maxY - card.height * 0.26, width: card.width, height: s * 0.008))
    NSColor(white: 1, alpha: 0.85).setFill(); header.fill()
    // Check mark
    let check = NSBezierPath()
    check.move(to: NSPoint(x: card.minX + card.width * 0.28, y: card.minY + card.height * 0.38))
    check.line(to: NSPoint(x: card.minX + card.width * 0.44, y: card.minY + card.height * 0.22))
    check.line(to: NSPoint(x: card.minX + card.width * 0.74, y: card.minY + card.height * 0.56))
    check.lineWidth = s * 0.045; check.lineCapStyle = .round; check.lineJoinStyle = .round
    NSColor.white.setStroke(); check.stroke()
    // Binder rings
    for x in [0.32, 0.68] {
        let ring = NSBezierPath(roundedRect: NSRect(x: card.minX + card.width * x - s * 0.02, y: card.maxY - s * 0.05, width: s * 0.04, height: s * 0.1),
                                xRadius: s * 0.02, yRadius: s * 0.02)
        NSColor.white.setFill(); ring.fill()
    }
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
let json = try! JSONSerialization.data(withJSONObject: ["images": images, "info": ["author": "xcode", "version": 1]], options: [.prettyPrinted, .sortedKeys])
try! json.write(to: out.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icon sizes")
