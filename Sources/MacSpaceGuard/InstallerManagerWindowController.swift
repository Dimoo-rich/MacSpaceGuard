import AppKit
import MacSpaceGuardCore

final class InstallerManagerWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let scanner = InstallerScanner()
    private let trashService = InstallerTrashService()
    private let onClose: () -> Void
    private var directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
    private var findings: [InstallerFinding] = []
    private var selectedPaths: Set<String> = []
    private var busy = false
    private var hasScanned = false

    private let pathLabel = NSTextField(labelWithString: "")
    private let summaryLabel = NSTextField(wrappingLabelWithString: "尚未扫描。")
    private let detailLabel = NSTextField(wrappingLabelWithString: "点选一行，可查看包内是什么、电脑上是否找到对应应用。")
    private let table = NSTableView()
    private let selectAllButton = NSButton(title: "全选", target: nil, action: nil)
    private let clearAllButton = NSButton(title: "全不选", target: nil, action: nil)
    private let scanButton = NSButton(title: "重新扫描", target: nil, action: nil)
    private let trashButton = NSButton(title: "移到废纸篓…", target: nil, action: nil)

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 575),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "清理下载的安装包"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
        buildInterface(in: window)
        updatePathLabel()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        if !hasScanned { scanFolder() }
    }

    func windowWillClose(_ notification: Notification) { onClose() }

    func numberOfRows(in tableView: NSTableView) -> Int { findings.count }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = table.selectedRow
        detailLabel.stringValue = findings.indices.contains(row)
            ? "下载文件：\(findings[row].url.lastPathComponent)。\(findings[row].evidence.explanation)"
            : "点选一行，可查看包内是什么、电脑上是否找到对应应用。"
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn, findings.indices.contains(row) else { return nil }
        let finding = findings[row]
        if column.identifier.rawValue == "selected" {
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleSelection(_:)))
            checkbox.tag = row
            checkbox.state = selectedPaths.contains(finding.url.path) ? .on : .off
            return checkbox
        }
        let value: String
        switch column.identifier.rawValue {
        case "status": value = finding.evidence.title
        case "contents": value = finding.evidence.containedAppName
        case "size": value = ByteCountFormatter.string(fromByteCount: finding.bytes, countStyle: .file)
        default: value = finding.url.lastPathComponent
        }
        let label = NSTextField(labelWithString: value)
        label.lineBreakMode = .byTruncatingMiddle
        label.toolTip = ["status", "contents"].contains(column.identifier.rawValue)
            ? finding.evidence.explanation : finding.url.path
        return label
    }

    private func buildInterface(in window: NSWindow) {
        guard let content = window.contentView else { return }
        let heading = NSTextField(labelWithString: "清理下载的安装包")
        heading.font = .boldSystemFont(ofSize: 20)
        heading.frame = NSRect(x: 20, y: 530, width: 720, height: 29)
        content.addSubview(heading)

        let explanation = NSTextField(wrappingLabelWithString: "默认扫描下方文件夹；换文件夹后会自动扫描，不必再点“重新扫描”。这里只处理 .dmg 和 .pkg 下载文件，不会卸载应用。勾选后移到废纸篓并二次确认；清空废纸篓后才会腾出空间。")
        explanation.textColor = .secondaryLabelColor
        explanation.frame = NSRect(x: 20, y: 476, width: 720, height: 47)
        content.addSubview(explanation)

        pathLabel.frame = NSRect(x: 20, y: 446, width: 490, height: 22)
        pathLabel.lineBreakMode = .byTruncatingMiddle
        content.addSubview(pathLabel)
        let chooseButton = NSButton(title: "选择文件夹…", target: self, action: #selector(chooseFolder))
        chooseButton.frame = NSRect(x: 610, y: 442, width: 130, height: 30)
        content.addSubview(chooseButton)

        for (identifier, title, width) in [
            ("selected", "选", CGFloat(43)),
            ("name", "下载文件", CGFloat(200)),
            ("contents", "实际包含", CGFloat(135)),
            ("status", "识别结果", CGFloat(220)),
            ("size", "大小", CGFloat(70))
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
        let scroll = NSScrollView(frame: NSRect(x: 20, y: 180, width: 720, height: 248))
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.documentView = table
        content.addSubview(scroll)

        detailLabel.frame = NSRect(x: 20, y: 96, width: 720, height: 80)
        detailLabel.textColor = .secondaryLabelColor
        content.addSubview(detailLabel)
        summaryLabel.frame = NSRect(x: 20, y: 59, width: 720, height: 35)
        content.addSubview(summaryLabel)
        selectAllButton.target = self
        selectAllButton.action = #selector(selectAllFindings)
        selectAllButton.isEnabled = false
        selectAllButton.frame = NSRect(x: 20, y: 17, width: 80, height: 32)
        content.addSubview(selectAllButton)
        clearAllButton.target = self
        clearAllButton.action = #selector(clearAllFindings)
        clearAllButton.isEnabled = false
        clearAllButton.frame = NSRect(x: 105, y: 17, width: 90, height: 32)
        content.addSubview(clearAllButton)
        scanButton.target = self
        scanButton.action = #selector(scanFolder)
        scanButton.frame = NSRect(x: 405, y: 17, width: 145, height: 32)
        content.addSubview(scanButton)
        trashButton.target = self
        trashButton.action = #selector(trashSelected)
        trashButton.isEnabled = false
        trashButton.frame = NSRect(x: 570, y: 17, width: 170, height: 32)
        content.addSubview(trashButton)
    }

    private func updatePathLabel() {
        pathLabel.stringValue = "扫描文件夹：\(directory.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))"
        pathLabel.toolTip = directory.path
    }

    private func setBusy(_ value: Bool) {
        busy = value
        scanButton.isEnabled = !value
        updateSelectionControls()
    }

    private func updateSelectionControls() {
        selectAllButton.isEnabled = !busy && !findings.isEmpty && selectedPaths.count < findings.count
        clearAllButton.isEnabled = !busy && !selectedPaths.isEmpty
        trashButton.isEnabled = !busy && !selectedPaths.isEmpty
    }

    private func updateSelectionSummary() {
        summaryLabel.stringValue = "已勾选 \(selectedPaths.count) / \(findings.count) 个下载文件。移到废纸篓前还会列出文件名，请再次确认。"
        updateSelectionControls()
    }

    @objc private func chooseFolder() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory
        panel.prompt = "选择文件夹"
        guard panel.runModal() == .OK, let chosen = panel.url else { return }
        directory = chosen.standardizedFileURL.resolvingSymlinksInPath()
        updatePathLabel()
        findings = []
        selectedPaths = []
        hasScanned = false
        table.reloadData()
        detailLabel.stringValue = "点选一行，可查看包内是什么、电脑上是否找到对应应用。"
        summaryLabel.stringValue = "已选择新文件夹，正在扫描；扫描不会删除或运行安装程序。"
        updateSelectionControls()
        scanFolder()
    }

    @objc private func scanFolder() {
        guard !busy else { return }
        setBusy(true)
        selectedPaths = []
        summaryLabel.stringValue = "正在扫描下载文件并识别包内内容；不会删除文件…"
        let currentDirectory = directory
        let scanner = self.scanner
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let outcome = Result { try scanner.scan(directory: currentDirectory) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.setBusy(false)
                self.hasScanned = true
                switch outcome {
                case .success(let findings):
                    self.findings = findings
                    self.table.reloadData()
                    self.updateSelectionControls()
                    if findings.isEmpty {
                        self.detailLabel.stringValue = "这个文件夹第一层没有找到 .dmg 或 .pkg 文件。"
                    } else {
                        self.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                    }
                    self.summaryLabel.stringValue = "找到 \(findings.count) 个下载的安装包。只会处理你勾选并确认的文件。"
                case .failure(let error):
                    self.findings = []
                    self.table.reloadData()
                    self.updateSelectionControls()
                    self.summaryLabel.stringValue = "检查失败：\(error.localizedDescription)"
                }
            }
        }
    }

    @objc private func toggleSelection(_ sender: NSButton) {
        guard findings.indices.contains(sender.tag) else { return }
        let path = findings[sender.tag].url.path
        if sender.state == .on { selectedPaths.insert(path) } else { selectedPaths.remove(path) }
        updateSelectionSummary()
    }

    @objc private func selectAllFindings() {
        guard !busy, !findings.isEmpty else { return }
        selectedPaths = Set(findings.map { $0.url.path })
        table.reloadData()
        updateSelectionSummary()
    }

    @objc private func clearAllFindings() {
        guard !busy else { return }
        selectedPaths.removeAll()
        table.reloadData()
        updateSelectionSummary()
    }

    @objc private func trashSelected() {
        guard !busy, !selectedPaths.isEmpty else { return }
        let selected = findings.filter { selectedPaths.contains($0.url.path) }
        let names = selected.prefix(12).map { "• \($0.url.lastPathComponent) → \($0.evidence.containedAppName)（\($0.evidence.title)）" }.joined(separator: "\n")
        let remaining = selected.count > 12 ? "\n另有 \(selected.count - 12) 个，请以窗口勾选为准。" : ""
        let alert = NSAlert()
        alert.messageText = "把 \(selected.count) 个安装包移到废纸篓？"
        alert.informativeText = "只会把下列下载文件移到废纸篓，不会卸载应用；清空废纸篓后才会腾出空间。以后离线重装可能需要原文件；对内容不符或无法识别的项目，请确认不再需要。找到对应应用也不代表它来自该文件。\n\n\(names)\(remaining)"
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "移到废纸篓")
        guard alert.runModal() == .alertSecondButtonReturn else { return }

        setBusy(true)
        summaryLabel.stringValue = "正在移到废纸篓；文件变化或不在所选文件夹内时会跳过…"
        let trashService = self.trashService
        let currentDirectory = directory
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = trashService.moveToTrash(selected, from: currentDirectory)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.setBusy(false)
                self.scanFolder()
                let message = NSAlert()
                message.messageText = "已移到废纸篓 \(result.movedFiles) 个安装包"
                message.informativeText = "可以在废纸篓中恢复。若想腾出磁盘空间，请自行检查并清空废纸篓。" +
                    (result.failures.isEmpty ? "" : "\n跳过或失败 \(result.failures.count) 个：\n" + result.failures.prefix(5).joined(separator: "\n"))
                message.runModal()
            }
        }
    }
}
