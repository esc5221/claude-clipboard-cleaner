import AppKit

func generateIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: s, height: s)

    // Background: warm Claude gradient (terracotta → warm orange)
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: s * 0.22, yRadius: s * 0.22)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.82, green: 0.33, blue: 0.18, alpha: 1.0),  // #D15430 deep terracotta
        NSColor(red: 0.76, green: 0.37, blue: 0.24, alpha: 1.0),  // #C15F3C Crail (Claude primary)
        NSColor(red: 0.85, green: 0.50, blue: 0.28, alpha: 1.0),  // #D98047 warm orange
    ], atLocations: [0.0, 0.5, 1.0], colorSpace: .deviceRGB)!
    gradient.draw(in: bgPath, angle: -45)

    // Subtle warm highlight at top
    let highlightRect = NSRect(x: s * 0.1, y: s * 0.55, width: s * 0.8, height: s * 0.4)
    let highlightPath = NSBezierPath(ovalIn: highlightRect)
    NSColor.white.withAlphaComponent(0.08).setFill()
    highlightPath.fill()

    // "C" letter — centered, bold, white
    let fontSize = s * 0.55
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
    ]
    let str = NSAttributedString(string: "C", attributes: attrs)
    let strSize = str.size()
    let strX = (s - strSize.width) / 2
    let strY = (s - strSize.height) / 2 - s * 0.02
    str.draw(at: NSPoint(x: strX, y: strY))

    image.unlockFocus()
    return image
}

// MARK: - Generate iconset

let iconsetPath = "build/AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let iconSizes: [(name: String, px: Int)] = [
    ("icon_16x16",      16),
    ("icon_16x16@2x",   32),
    ("icon_32x32",      32),
    ("icon_32x32@2x",   64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x", 1024),
]

for entry in iconSizes {
    let img = generateIcon(size: entry.px)
    if let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        let path = "\(iconsetPath)/\(entry.name).png"
        try! png.write(to: URL(fileURLWithPath: path))
    }
}

print("✅ Iconset generated")

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["--convert", "icns", iconsetPath, "--output", "build/AppIcon.icns"]
try! task.run()
task.waitUntilExit()

if task.terminationStatus == 0 {
    print("✅ AppIcon.icns created")
} else {
    print("❌ iconutil failed")
}
