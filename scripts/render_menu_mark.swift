import AppKit
import Foundation

@main
struct RenderMenuMark {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            fputs("Usage: render_menu_mark OUTPUT.png\n", stderr)
            exit(2)
        }

        let scale = 4
        let markWidth = 20
        let markHeight = 20
        let gap = 12
        let width = 3 * markWidth + 4 * gap
        let height = 72
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width * scale,
            pixelsHigh: height * scale,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            fatalError("Unable to create preview")
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        NSColor(calibratedRed: 0.39, green: 0.44, blue: 0.55, alpha: 1).setFill()
        NSRect(x: 0, y: height / 2, width: width, height: height / 2).fill()
        NSColor(calibratedWhite: 0.93, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: width, height: height / 2).fill()

        for (index, level) in [
            MenuBarMark.Level.normal,
            .warning,
            .critical
        ].enumerated() {
            let x = gap + index * (markWidth + gap)
            MenuBarMark.previewImage(for: level, ink: .white).draw(
                in: NSRect(x: x, y: 42, width: markWidth, height: markHeight)
            )
            MenuBarMark.previewImage(for: level, ink: .black).draw(
                in: NSRect(x: x, y: 6, width: markWidth, height: markHeight)
            )
        }
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Unable to save preview")
        }
        try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}
