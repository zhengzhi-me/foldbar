import AppKit
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let source = root.appendingPathComponent("img/foldbar-icon.svg")
let destination = root.appendingPathComponent("hidden/Assets.xcassets/AppIcon.appiconset")
guard let image = NSImage(contentsOf: source) else {
    fatalError("Could not open the FoldBar icon SVG.")
}
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            fatalError("Could not allocate the icon bitmap.")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let bounds = NSRect(x: 0, y: 0, width: pixels, height: pixels)
        NSColor.clear.setFill()
        bounds.fill(using: .copy)
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Could not encode the icon.")
        }
        try png.write(to: destination.appendingPathComponent("icon_\(points)@\(scale)x.png"), options: .atomic)
    }
}
