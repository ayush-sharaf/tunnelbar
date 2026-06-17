#!/usr/bin/env swift
// Generates Resources/AppIcon.icns: three connected nodes in a triangle with a
// dotted path (echoing the menu-bar glyph "point.3.connected.trianglepath.dotted"),
// in white on a blue squircle. Drawn with primitives so it renders correctly
// from a plain `swift` invocation (SF Symbols don't render outside an app).
//
// Run from the project root:  swift scripts/generate-icon.swift
import AppKit
import Foundation

let fm = FileManager.default
let root = fm.currentDirectoryPath
let resourcesDir = "\(root)/Resources"
try? fm.createDirectory(atPath: resourcesDir, withIntermediateDirectories: true)

let iconsetDir = NSTemporaryDirectory() + "Tunnelbar.iconset"
try? fm.removeItem(atPath: iconsetDir)
try! fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

func renderPNG(pixels: Int) -> Data {
    let dim = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    // Squircle background with a vertical blue gradient (macOS-style padding).
    let inset = dim * 0.08
    let bgRect = NSRect(x: inset, y: inset, width: dim - inset * 2, height: dim - inset * 2)
    let radius = bgRect.width * 0.2237
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(
        starting: NSColor(srgbRed: 0.20, green: 0.55, blue: 1.00, alpha: 1),
        ending:   NSColor(srgbRed: 0.05, green: 0.30, blue: 0.85, alpha: 1))!
    gradient.draw(in: bgPath, angle: -90)

    // Three nodes in an upward triangle, connected by dotted edges, in white.
    NSColor.white.setStroke()
    NSColor.white.setFill()

    let cx = dim / 2, cy = dim / 2
    let R = dim * 0.205
    let angles: [CGFloat] = [90, 210, 330] // top, bottom-left, bottom-right
    let nodes = angles.map { a -> NSPoint in
        let rad = a * .pi / 180
        return NSPoint(x: cx + R * cos(rad), y: cy + R * sin(rad))
    }

    // Dotted edges between every pair of nodes.
    let edges = NSBezierPath()
    edges.lineWidth = max(1, dim * 0.022)
    edges.lineCapStyle = .round
    let dash: [CGFloat] = [0.0001, dim * 0.052] // round caps + gaps => dots
    edges.setLineDash(dash, count: 2, phase: 0)
    for i in 0..<nodes.count {
        for j in (i + 1)..<nodes.count {
            edges.move(to: nodes[i])
            edges.line(to: nodes[j])
        }
    }
    edges.stroke()

    // Solid node circles on top.
    let nodeR = dim * 0.058
    for p in nodes {
        let r = NSRect(x: p.x - nodeR, y: p.y - nodeR, width: nodeR * 2, height: nodeR * 2)
        NSBezierPath(ovalIn: r).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// (pixels, iconset filename) per Apple's .iconset spec.
let entries: [(Int, String)] = [
    (16,  "icon_16x16.png"),     (32,  "icon_16x16@2x.png"),
    (32,  "icon_32x32.png"),     (64,  "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),   (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),   (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),   (1024, "icon_512x512@2x.png"),
]
for (pixels, name) in entries {
    let data = renderPNG(pixels: pixels)
    try! data.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name)"))
}

// Convert the iconset to .icns.
let icns = "\(resourcesDir)/AppIcon.icns"
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir, "-o", icns]
try! proc.run()
proc.waitUntilExit()
print(proc.terminationStatus == 0 ? "Wrote \(icns)" : "iconutil failed (\(proc.terminationStatus))")
