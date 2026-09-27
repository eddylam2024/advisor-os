// Renders docs/images/social-preview.png (1280×640), the image shown when the repository link is shared.
// Run after the screenshots exist: swift scripts/make-social-preview.swift
import AppKit

let W: CGFloat = 1280, H: CGFloat = 640
func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * 2), pixelsHigh: Int(H * 2), bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let canvas = NSRect(x: 0, y: 0, width: W, height: H)

NSGradient(colors: [color(0x131A3A), color(0x0C1024)])!.draw(in: canvas, angle: -90)
for (center, radius, c) in [(NSPoint(x: W * 0.72, y: H * 1.05), 620.0, color(0x4A6CE6, 0.75)),
                            (NSPoint(x: W * 0.05, y: H * 0.05), 520.0, color(0xF08C74, 0.5)),
                            (NSPoint(x: W * 1.0, y: H * 0.2), 420.0, color(0xB7A6F2, 0.35))] {
    NSGradient(colors: [c, c.withAlphaComponent(0)])!.draw(fromCenter: center, radius: 0, toCenter: center, radius: CGFloat(radius), options: [])
}

// Screenshot, tilted into the right side.
if let shot = NSImage(contentsOfFile: "docs/images/today-dark.png") {
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.translateBy(x: 690, y: 70)
    ctx.rotate(by: 0.035)
    let w: CGFloat = 820, h = w * shot.size.height / shot.size.width
    shot.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
    ctx.restoreGState()
}

if let icon = NSImage(contentsOfFile: "design/AppIcon-1024.png") {
    icon.draw(in: NSRect(x: 64, y: 400, width: 150, height: 150))
}

func text(_ s: String, _ font: NSFont, _ c: NSColor, _ rect: NSRect, kern: CGFloat = 0) {
    let style = NSMutableParagraphStyle(); style.lineHeightMultiple = 1.05
    NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: c, .kern: kern, .paragraphStyle: style]).draw(in: rect)
}
text("Advisor OS", .systemFont(ofSize: 64, weight: .bold), .white, NSRect(x: 76, y: 300, width: 600, height: 90), kern: -1.5)
text("A local-first macOS workspace for\nCanadian financial advice and lending.", .systemFont(ofSize: 27, weight: .regular),
     color(0xFFFFFF, 0.82), NSRect(x: 78, y: 210, width: 600, height: 90))
text("SwiftUI  ·  EventKit  ·  On-device Foundation Models  ·  SwiftData", .systemFont(ofSize: 17, weight: .medium),
     color(0xFFFFFF, 0.6), NSRect(x: 78, y: 120, width: 640, height: 30))
text("Edouard Lam", .systemFont(ofSize: 19, weight: .semibold), color(0xFFFFFF, 0.9), NSRect(x: 78, y: 64, width: 400, height: 30))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "docs/images/social-preview.png"))
print("Wrote docs/images/social-preview.png")
