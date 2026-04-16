import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "assets/AppIcon-1024.png"
let size: CGFloat = 1024
let rect = NSRect(x: 0, y: 0, width: size, height: size)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Failed to create bitmap context\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSColor.clear.setFill()
rect.fill()

let canvas = NSBezierPath(roundedRect: rect.insetBy(dx: 24, dy: 24), xRadius: 220, yRadius: 220)
canvas.addClip()

let bg = NSGradient(
    colors: [
        NSColor(calibratedRed: 0.09, green: 0.52, blue: 0.93, alpha: 1),
        NSColor(calibratedRed: 0.15, green: 0.72, blue: 0.57, alpha: 1),
    ]
)!
bg.draw(in: rect, angle: -28)

NSColor.white.withAlphaComponent(0.16).setFill()
NSBezierPath(ovalIn: NSRect(x: 610, y: 630, width: 320, height: 320)).fill()
NSColor.white.withAlphaComponent(0.10).setFill()
NSBezierPath(ovalIn: NSRect(x: 120, y: 120, width: 260, height: 260)).fill()

let plate = NSBezierPath(
    roundedRect: NSRect(x: 180, y: 180, width: 664, height: 664),
    xRadius: 170,
    yRadius: 170
)
NSColor.white.withAlphaComponent(0.18).setFill()
plate.fill()

// Main "C" glyph
let cPath = NSBezierPath()
cPath.lineCapStyle = .round
cPath.lineWidth = 84
cPath.appendArc(
    withCenter: NSPoint(x: 512, y: 512),
    radius: 220,
    startAngle: 40,
    endAngle: 318,
    clockwise: false
)
NSColor.white.setStroke()
cPath.stroke()

func bar(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
    let p = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: h / 2, yRadius: h / 2)
    NSColor.white.setFill()
    p.fill()
}

bar(x: 420, y: 590, w: 180, h: 46)
bar(x: 420, y: 490, w: 200, h: 46)
bar(x: 420, y: 390, w: 160, h: 46)

let accent = NSBezierPath(ovalIn: NSRect(x: 688, y: 308, width: 70, height: 70))
NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.20, alpha: 1.0).setFill()
accent.fill()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

let outURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try data.write(to: outURL)
print("Generated icon PNG: \(outURL.path)")
