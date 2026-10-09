import AppKit
import MacSpaceGuardCore

/// Read-only cache findings. There are no file selection or moving controls in this beta.
final class CacheReviewWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private struct Row {
        let candidate: CacheCandidate
        let rule: CacheRule
        let isAppRunning: Bool
        var riskTitle: String { isAppRunning ? "高风险·运行中" : rule.riskLevel.title }
        var riskReason: String {
            isAppRunning ? "相关应用正在运行。\(rule.riskReason)" : rule.riskReason
        }
    }

    private let rows: [Row]
    private let table = NSTableView()

    init(reports: [CacheAreaReport], runningBundleIdentifiers: Set<String>) {
        rows = reports.flatMap { report in
            let running = !report.rule.relatedBundleIdentifiers.isDisjoint(with: runningBundleIdentifiers)
            return report.candidates.map { Row(candidate: $0, rule: report.rule, isAppRunning: running) }
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.title = "缓存扫描结果（只读）"
        window.center()
        super.init(window: window)
        window.delegate = self
        buildInterface(in: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func windowWillClose(_ notification: Notification) { NSApp.stopModal() }
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn, rows.indices.contains(row) else { return nil }
        let item = rows[row]
        let value: String
        switch column.identifier.rawValue {
        case "risk": value = item.riskTitle
        case "size": value = ByteCountFormatter.string(fromByteCount: item.candidate.bytes, countStyle: .file)
        case "date": value = DateFormatter.localizedString(from: item.candidate.modificationDate, dateStyle: .short, timeStyle: .none)
        default: value = item.candidate.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        }
        let label = NSTextField(labelWithString: value)
        label.lineBreakMode = .byTruncatingMiddle
        label.toolTip = column.identifier.rawValue == "risk" ? item.riskReason : value
        label.textColor = column.identifier.rawValue == "risk" && item.isAppRunning ? .systemOrange : .labelColor
        return label
    }

    private func buildInterface(in window: NSWindow) {
        guard let content = window.contentView else { return }
        let help = NSTextField(wrappingLabelWithString: "\(ReleasePolicy.cacheReadOnlyExplanation) 风险标识用于了解文件用途，不是安全删除保证。橙色表示相关应用正在运行。")
        help.frame = NSRect(x: 20, y: 512, width: 860, height: 36)
        content.addSubview(help)
        for (identifier, title, width) in [
            ("risk", "风险", CGFloat(125)),
            ("size", "大小", CGFloat(95)),
            ("date", "修改日期", CGFloat(115)),
            ("path", "文件路径", CGFloat(480))
        ] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            table.addTableColumn(column)
        }
        table.rowHeight = 29
        table.delegate = self
        table.dataSource = self
        table.usesAlternatingRowBackgroundColors = true
        let scroll = NSScrollView(frame: NSRect(x: 20, y: 84, width: 860, height: 415))
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.borderType = .bezelBorder
        scroll.documentView = table
        content.addSubview(scroll)
        let bytes = rows.reduce(Int64(0)) { $0 + $1.candidate.bytes }
        let summary = NSTextField(labelWithString: "共 \(rows.count) 个文件，原大小 \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))；只读查看")
        summary.frame = NSRect(x: 20, y: 55, width: 700, height: 18)
        content.addSubview(summary)
        let close = NSButton(title: "关闭", target: self, action: #selector(closeReview))
        close.frame = NSRect(x: 765, y: 19, width: 115, height: 30)
        close.keyEquivalent = "\r"
        content.addSubview(close)
    }

    @objc private func closeReview() {
        NSApp.stopModal()
        window?.orderOut(nil)
    }
}
