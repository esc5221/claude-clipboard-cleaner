import AppKit

// Render at 2x for Retina crisp
let pointW: CGFloat = 52
let pointH: CGFloat = 18
let scale: CGFloat = 2
let pxW = Int(pointW * scale)
let pxH = Int(pointH * scale)

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pxW, pixelsHigh: pxH,
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
)!
rep.size = NSSize(width: pointW, height: pointH)  // point size for Retina

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let ctx = NSGraphicsContext.current!.cgContext
ctx.scaleBy(x: scale, y: scale)

// ⌘ — medium weight, slightly smaller
let cmdFont = NSFont.systemFont(ofSize: 11, weight: .medium)
let cmdAttrs: [NSAttributedString.Key: Any] = [
    .font: cmdFont,
    .foregroundColor: NSColor.black,
]
let cmdStr = NSAttributedString(string: "⌘", attributes: cmdAttrs)
let cmdSize = cmdStr.size()
let cmdX: CGFloat = 1
let cmdY = (pointH - cmdSize.height) / 2
cmdStr.draw(at: NSPoint(x: cmdX, y: cmdY))

// CC — bold, tight kerning
let ccFont = NSFont.systemFont(ofSize: 13, weight: .bold)
let ccAttrs: [NSAttributedString.Key: Any] = [
    .font: ccFont,
    .foregroundColor: NSColor.black,
    .kern: -0.8 as CGFloat,
]
let ccStr = NSAttributedString(string: "CC", attributes: ccAttrs)
let ccSize = ccStr.size()
let ccX = cmdX + cmdSize.width + 0.5
let ccY = (pointH - ccSize.height) / 2
ccStr.draw(at: NSPoint(x: ccX, y: ccY))

NSGraphicsContext.restoreGraphicsState()

// Save
if let png = rep.representation(using: .png, properties: [:]) {
    try! png.write(to: URL(fileURLWithPath: "build/menubar_icon.png"))
    print("✅ build/menubar_icon.png (\(pxW)x\(pxH)px, \(Int(pointW))x\(Int(pointH))pt)")
}
