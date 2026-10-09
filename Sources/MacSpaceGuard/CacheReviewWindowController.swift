import AppKit
import MacSpaceGuardCore

final class CacheReviewWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private struct Row {
        let candidate: CacheCandidate
        let rule: CacheRule
        let isAppRunning: Bool

        var key: String { "\(rule.id)\u{0}\(candidate.url.path)" }
        var riskTitle: String { isAppRunning ? "高风险·运行中" : rule.riskLevel.title }
        var riskReason: String {
            isAppRunning ? "相关应用正在运行。\(rule.riskReason) 即使移到废纸篓也可能影响当前应用。" : rule.riskReason
        }
    }

    private let rows: [Row]
    private var checkedKeys: Set<String>
    private let table = NSTableView()
    private let summary = NSTextField(labelWithString: "")
    private(set) var appliedSelection: Set<String>?

    init(reports: [CacheAreaReport], runningBundleIdentifiers: Set<String>, selectedKeys: Set<String>) {
        rows = reports.flatMap { report in
            let running = !report.rule.relatedBundleIdentifiers.isDisjoint(with: runningBundleIdentifiers)
            return report.candidates.map { Row(candidate: $0, rule: report.rule, isAppRunning: running) }
        }
        checkedKeys = selectedKeys
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "选择要清理的缓存文件"
        window.center()
        super.init(window: window)
        window.delegate = self
        buildInterface(in: window)
        updateSummary()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func windowWillClose(_ notification: Notification) {
        NSApp.stopModal()
    }

    static func selectionKey(for candidate: CacheCandidate) -> String {
        "\(candidate.ruleID)\u{0}\(candidate.url.path)"
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn, rows.indices.contains(row) else { return nil }
        let item = rows[row]
        if column.identifier.rawValue == "selected" {
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleRow(_:)))
            checkbox.tag = row
            checkbox.state = checkedKeys.contains(item.key) ? .on : .off
            return checkbox
        }
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
        let help = NSTextField(wrappingLabelWithString: "默认不勾选文件。逐项勾选或点“全选”，再点“确认选择”；不会立即移动。风险等级不是安全保证，橙色表示相关应用正在运行。核对风险理由后再决定。")
        help.frame = NSRect(x: 20, y: 512, width: 860, height: 36)
        content.addSubview(help)

        for (identifier, title, width) in [
            ("selected", "选", CGFloat(40)),
            ("risk", "风险", CGFloat(115)),
            ("size", "大小", CGFloat(90)),
            ("date", "修改日期", CGFloat(110)),
            ("path", "文件路径", CGFloat(410))
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

        summary.frame = NSRect(x: 20, y: 55, width: 430, height: 18)
        content.addSubview(summary)
        let selectAll = NSButton(title: "全选", target: self, action: #selector(selectAllRows))
        selectAll.frame = NSRect(x: 470, y: 48, width: 75, height: 30)
        content.addSubview(selectAll)
        let clearAll = NSButton(title: "全不选", target: self, action: #selector(clearAllRows))
        clearAll.frame = NSRect(x: 550, y: 48, width: 85, height: 30)
        content.addSubview(clearAll)
        let cancel = NSButton(title: "取消", target: self, action: #selector(cancelReview))
        cancel.frame = NSRect(x: 660, y: 19, width: 95, height: 30)
        content.addSubview(cancel)
        let apply = NSButton(title: "确认选择", target: self, action: #selector(applyReview))
        apply.frame = NSRect(x: 765, y: 19, width: 115, height: 30)
        apply.keyEquivalent = "\r"
        content.addSubview(apply)
    }

    private func updateSummary() {
        summary.stringValue = "已选 \(checkedKeys.count) / \(rows.count) 个文件"
    }

    @objc private func toggleRow(_ sender: NSButton) {
        guard rows.indices.contains(sender.tag) else { return }
        let key = rows[sender.tag].key
        if sender.state == .on { checkedKeys.insert(key) } else { checkedKeys.remove(key) }
        updateSummary()
    }

    @objc private func selectAllRows() {
        checkedKeys = Set(rows.map(\.key))
        table.reloadData()
        updateSummary()
    }

    @objc private func clearAllRows() {
        checkedKeys.removeAll()
        table.reloadData()
        updateSummary()
    }

    @objc private func applyReview() {
        appliedSelection = checkedKeys
        NSApp.stopModal()
        window?.orderOut(nil)
    }

    @objc private func cancelReview() {
        NSApp.stopModal()
        window?.orderOut(nil)
    }
}
