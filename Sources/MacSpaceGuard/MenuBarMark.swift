import AppKit

enum MenuBarMark {
    enum Level {
        case normal
        case warning
        case critical

        var symbolName: String {
            switch self {
            case .normal: return "externaldrive.badge.checkmark"
            case .warning: return "externaldrive.badge.questionmark"
            case .critical: return "externaldrive.badge.exclamationmark"
            }
        }
    }

    static func image(for level: Level) -> NSImage {
        makeImage(for: level, ink: .black, template: true)
    }

    static func previewImage(for level: Level, ink: NSColor) -> NSImage {
        makeImage(for: level, ink: ink, template: false)
    }

    private static func makeImage(for level: Level, ink: NSColor, template: Bool) -> NSImage {
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size, flipped: false) { bounds in
            let symbolStyle = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
                .applying(NSImage.SymbolConfiguration(paletteColors: [ink]))
            if let symbol = NSImage(systemSymbolName: level.symbolName, accessibilityDescription: "MSG")?
                .withSymbolConfiguration(symbolStyle) {
                symbol.draw(in: NSRect(x: 0, y: 0.5, width: bounds.width, height: 18))
            }

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let initial = NSAttributedString(string: "G", attributes: [
                .font: NSFont.systemFont(ofSize: 6.5, weight: .medium),
                .foregroundColor: ink,
                .paragraphStyle: paragraph
            ])
            initial.draw(in: NSRect(x: 8, y: 8, width: 9, height: 9))
            return true
        }
        image.isTemplate = template
        return image
    }
}
