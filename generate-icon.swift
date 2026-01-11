#!/usr/bin/swift

import AppKit

// Create icon using SF Symbol
let symbolName = "computermouse.fill"
let sizes: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]

// Create iconset directory
let iconsetPath = "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for size in sizes {
    // Create image from SF Symbol
    let config = NSImage.SymbolConfiguration(pointSize: size * 0.8, weight: .regular)
    guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
        print("Failed to create symbol")
        exit(1)
    }

    let image = symbol.withSymbolConfiguration(config)!

    // Create bitmap with blue color
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let bitmap = NSBitmapImageRep(
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
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    // Blue gradient background
    let gradient = NSGradient(colors: [
        NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),
        NSColor(red: 0.1, green: 0.4, blue: 0.9, alpha: 1.0)
    ])
    gradient?.draw(in: rect, angle: 135)

    // Draw symbol in white
    NSColor.white.set()
    image.draw(in: rect.insetBy(dx: size * 0.1, dy: size * 0.1))

    NSGraphicsContext.restoreGraphicsState()

    // Save PNG files for iconset
    let pngData = bitmap.representation(using: .png, properties: [:])!

    if size <= 512 {
        try pngData.write(to: URL(fileURLWithPath: "\(iconsetPath)/icon_\(Int(size))x\(Int(size)).png"))
        try pngData.write(to: URL(fileURLWithPath: "\(iconsetPath)/icon_\(Int(size/2))x\(Int(size/2))@2x.png"))
    } else {
        try pngData.write(to: URL(fileURLWithPath: "\(iconsetPath)/icon_\(Int(size))x\(Int(size)).png"))
    }
}

print("✅ Iconset created at: \(iconsetPath)")
print("Now run: iconutil -c icns \(iconsetPath)")
