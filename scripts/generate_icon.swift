import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift generate_icon.swift OUTPUT.png\n", stderr)
    exit(2)
}

let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Unable to create icon bitmap")
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let tile = NSBezierPath(roundedRect: NSRect(x: 62, y: 62, width: 900, height: 900), xRadius: 205, yRadius: 205)
NSGradient(starting: color(11, 37, 76), ending: color(21, 105, 183))?.draw(in: tile, angle: -35)

let innerBorder = NSBezierPath(roundedRect: NSRect(x: 78, y: 78, width: 868, height: 868), xRadius: 190, yRadius: 190)
innerBorder.lineWidth = 3
color(255, 255, 255, 0.18).setStroke()
innerBorder.stroke()

let glow = NSBezierPath(ovalIn: NSRect(x: 704, y: 674, width: 156, height: 156))
color(99, 224, 229, 0.16).setFill()
glow.fill()

let textStyle = NSMutableParagraphStyle()
textStyle.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 260, weight: .heavy),
    .foregroundColor: NSColor.white,
    .kern: -13,
    .paragraphStyle: textStyle
]
NSAttributedString(string: "MSG", attributes: attributes).draw(in: NSRect(x: 90, y: 342, width: 844, height: 340))

let underline = NSBezierPath(roundedRect: NSRect(x: 270, y: 275, width: 484, height: 28), xRadius: 14, yRadius: 14)
color(94, 228, 225).setFill()
underline.fill()

context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode icon PNG")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
