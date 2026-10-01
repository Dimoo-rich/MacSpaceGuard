import AppKit
import MacSpaceGuardCore

private final class FlippedCacheListView: NSView {
    override var isFlipped: Bool { true }
}

final class CacheManagerWindowController: NSWindowController, NSWindowDelegate {
    private let scanner = CacheScanner()
    private let cleaner = CleanupService()
    private let rules = CacheScanner.defaultRules
    private let onClose: () -> Void
    private let onCleanup: () -> Void
    private let cutoffPopup = NSPopUpButton()
    private let cutoffHint = NSTextField(labelWithString: "")
    private var selectedPresetDays = 30
    private var customCutoffDate: Date?
    private let summaryLabel = NSTextField(wrappingLabelWithString: "先勾选缓存类别并选择时间，再点击“扫描并选择文件”。")
    private let scanButton = NSButton(title: "扫描并选择文件", target: nil, action: nil)
    private let cleanupButton = NSButton(title: "移到废纸篓", target: nil, action: nil)
    private let selectAllButton = NSButton(title: "全选", target: nil, action: nil)
    private let clearAllButton = NSButton(title: "全不选", target: nil, action: nil)
    private var checkboxes: [String: NSButton] = [:]
    private var scannedReports: [CacheAreaReport] = []
    private var selectedCandidateKeys: Set<String> = []
    private var hasReviewedSelection = false
    private var busy = false

    private let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        return formatter
    }()

    init(onClose: @escaping () -> Void, onCleanup: @escaping () -> Void) {
        self.onClose = onClose
        self.onCleanup = onCleanup
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "资源库缓存管理"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
        buildInterface(in: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        refreshRunningRules()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        refreshRunningRules()
    }

    private func buildInterface(in window: NSWindow) {
        guard let content = window.contentView else { return }

        let heading = NSTextField(labelWithString: "清理资源库缓存")
        heading.font = .boldSystemFont(ofSize: 20)
        heading.frame = NSRect(x: 20, y: 575, width: 640, height: 29)
        content.addSubview(heading)

        let explanation = NSTextField(wrappingLabelWithString: "① 选缓存和时间 → ② 扫描并逐文件选择 → ③ 确认移到废纸篓。仅处理下方白名单；运行中应用需额外确认。清空废纸篓后才会腾出空间。")
        explanation.frame = NSRect(x: 20, y: 530, width: 640, height: 42)
        explanation.textColor = .secondaryLabelColor
        content.addSubview(explanation)

        let dateLabel = NSTextField(labelWithString: "时间范围：")
        dateLabel.frame = NSRect(x: 20, y: 502, width: 86, height: 22)
        content.addSubview(dateLabel)

        cutoffPopup.frame = NSRect(x: 108, y: 496, width: 300, height: 32)
        for (title, days) in [
            ("昨天及更早（不含今天）", 0),
            ("早于 7 天前", 7),
            ("早于 30 天前", 30),
            ("早于 90 天前", 90),
            ("自选日期…", -1)
        ] {
            cutoffPopup.addItem(withTitle: title)
            cutoffPopup.lastItem?.tag = days
        }
        cutoffPopup.selectItem(withTag: selectedPresetDays)
        cutoffPopup.target = self
        cutoffPopup.action = #selector(cutoffSelectionChanged(_:))
        content.addSubview(cutoffPopup)

        let openButton = NSButton(title: "在访达中打开资源库", target: self, action: #selector(openLibrary))
        openButton.frame = NSRect(x: 448, y: 496, width: 212, height: 32)
        content.addSubview(openButton)

        cutoffHint.textColor = .secondaryLabelColor
        cutoffHint.font = .systemFont(ofSize: 11)
        cutoffHint.frame = NSRect(x: 20, y: 474, width: 640, height: 17)
        content.addSubview(cutoffHint)
        updateCutoffHint()

        let listLabel = NSTextField(labelWithString: "缓存类别：")
        listLabel.frame = NSRect(x: 20, y: 443, width: 90, height: 20)
        content.addSubview(listLabel)
        selectAllButton.target = self
        selectAllButton.action = #selector(selectAllRules)
        selectAllButton.frame = NSRect(x: 113, y: 439, width: 80, height: 28)
        content.addSubview(selectAllButton)
        clearAllButton.target = self
        clearAllButton.action = #selector(clearAllRules)
        clearAllButton.frame = NSRect(x: 198, y: 439, width: 90, height: 28)
        content.addSubview(clearAllButton)

        let scroll = NSScrollView(frame: NSRect(x: 20, y: 137, width: 640, height: 300))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let rowHeight: CGFloat = 52
        let document = FlippedCacheListView(frame: NSRect(x: 0, y: 0, width: 620, height: rowHeight * CGFloat(rules.count)))
        for (index, rule) in rules.enumerated() {
            let originY = rowHeight * CGFloat(index)
            let checkbox = NSButton(checkboxWithTitle: rule.displayName, target: self, action: #selector(selectionChanged))
            checkbox.frame = NSRect(x: 12, y: originY + 4, width: 595, height: 22)
            document.addSubview(checkbox)
            checkboxes[rule.id] = checkbox

            let path = NSTextField(labelWithString: "~/\(rule.relativePath)")
            path.textColor = .secondaryLabelColor
            path.font = .systemFont(ofSize: 11)
            path.lineBreakMode = .byTruncatingMiddle
            path.frame = NSRect(x: 37, y: originY + 28, width: 565, height: 17)
            document.addSubview(path)
        }
        scroll.documentView = document
        content.addSubview(scroll)

        summaryLabel.frame = NSRect(x: 20, y: 86, width: 640, height: 43)
        content.addSubview(summaryLabel)

        scanButton.target = self
        scanButton.action = #selector(scanSelection)
        scanButton.isEnabled = false
        scanButton.frame = NSRect(x: 290, y: 28, width: 225, height: 32)
        content.addSubview(scanButton)

        cleanupButton.target = self
        cleanupButton.action = #selector(confirmCleanup)
        cleanupButton.isEnabled = false
        cleanupButton.frame = NSRect(x: 525, y: 28, width: 135, height: 32)
        content.addSubview(cleanupButton)
    }

    private func runningBundleIdentifiers() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }

    private func refreshRunningRules() {
        let running = runningBundleIdentifiers()
        for rule in rules {
            guard let checkbox = checkboxes[rule.id] else { continue }
            let isRunning = !rule.relatedBundleIdentifiers.isDisjoint(with: running)
            checkbox.isEnabled = !busy
            checkbox.title = "[\(rule.effectiveRisk(whileRunning: running).title)] \(rule.displayName)" + (isRunning ? "（运行中）" : "")
            checkbox.toolTip = isRunning ? "相关应用正在运行；\(rule.riskReason)" : rule.riskReason
        }
    }

    @objc private func selectionChanged() {
        scannedReports = []
        selectedCandidateKeys = []
        hasReviewedSelection = false
        cleanupButton.isEnabled = false
        scanButton.isEnabled = checkboxes.values.contains { $0.state == .on }
        summaryLabel.stringValue = scanButton.isEnabled
            ? "类别或时间已更新。点击“扫描并选择文件”查看文件清单。"
            : "请先勾选至少一个缓存类别，再点击“扫描并选择文件”。"
    }

    @objc private func selectAllRules() {
        guard !busy else { return }
        for checkbox in checkboxes.values { checkbox.state = .on }
        selectionChanged()
    }

    @objc private func clearAllRules() {
        guard !busy else { return }
        for checkbox in checkboxes.values { checkbox.state = .off }
        selectionChanged()
    }

    @objc private func cutoffSelectionChanged(_ sender: NSPopUpButton) {
        let chosen = sender.selectedTag()
        if chosen == -1 {
            let picker = NSDatePicker(frame: NSRect(x: 0, y: 0, width: 280, height: 230))
            picker.datePickerStyle = .clockAndCalendar
            picker.datePickerElements = .yearMonthDay
            picker.dateValue = customCutoffDate ?? cutoffDate()
            picker.maxDate = Date()

            let alert = NSAlert()
            alert.messageText = "选择截止日期"
            alert.informativeText = "仅筛选该日期之前修改的文件，不含所选日期当天。"
            alert.accessoryView = picker
            alert.addButton(withTitle: "使用此日期")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else {
                sender.selectItem(withTag: selectedPresetDays)
                return
            }
            customCutoffDate = Calendar.current.startOfDay(for: picker.dateValue)
            selectedPresetDays = -1
            if let customCutoffDate {
                sender.itemArray.first(where: { $0.tag == -1 })?.title = "自选：\(DateFormatter.localizedString(from: customCutoffDate, dateStyle: .short, timeStyle: .none)) 之前"
            }
            sender.selectItem(withTag: -1)
        } else {
            selectedPresetDays = chosen
        }
        updateCutoffHint()
        selectionChanged()
    }

    private func cutoffDate() -> Date {
        if selectedPresetDays == -1, let customCutoffDate { return customCutoffDate }
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: -selectedPresetDays, to: today) ?? today
    }

    private func updateCutoffHint() {
        let date = DateFormatter.localizedString(from: cutoffDate(), dateStyle: .medium, timeStyle: .none)
        cutoffHint.stringValue = "筛选 \(date) 之前修改的文件（不含当天）；旧文件也可能仍被应用使用。"
    }

    @objc private func openLibrary() {
        let library = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)
        NSWorkspace.shared.open(library)
    }

    @objc private func scanSelection() {
        guard !busy else { return }
        refreshRunningRules()
        let chosenRules = rules.filter { checkboxes[$0.id]?.state == .on }
        guard !chosenRules.isEmpty else {
            showMessage("请先勾选至少一个缓存目录。")
            return
        }
        let cutoff = cutoffDate()
        guard cutoff <= Calendar.current.startOfDay(for: Date()) else {
            showMessage("请选择今天或更早的截止日期。")
            return
        }
        setBusy(true)
        hasReviewedSelection = false
        cleanupButton.isEnabled = false
        summaryLabel.stringValue = "正在扫描所选缓存；完成后会打开文件清单，不会自动移动文件…"
        let scanner = self.scanner
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let reports = scanner.scan(rules: chosenRules, cutoffDate: cutoff)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.scannedReports = reports
                self.selectedCandidateKeys = []
                self.hasReviewedSelection = false
                let count = reports.reduce(0) { $0 + $1.candidates.count }
                let bytes = reports.reduce(Int64(0)) { $0 + $1.reclaimableBytes }
                self.summaryLabel.stringValue = "扫描完成：\(count) 个文件，原大小约 \(self.formatter.string(fromByteCount: bytes))。\n正在打开文件清单；默认不勾选，需主动选择。"
                self.setBusy(false)
                if count > 0 {
                    self.reviewCandidates()
                } else {
                    self.summaryLabel.stringValue = "扫描完成：没有符合所选时间的缓存文件。可调整类别或时间后重试。"
                }
            }
        }
    }

    @objc private func reviewCandidates() {
        guard !busy, !scannedReports.isEmpty else { return }
        let controller = CacheReviewWindowController(
            reports: scannedReports,
            runningBundleIdentifiers: runningBundleIdentifiers(),
            selectedKeys: selectedCandidateKeys
        )
        guard let reviewWindow = controller.window else { return }
        NSApp.runModal(for: reviewWindow)
        guard let selection = controller.appliedSelection else {
            summaryLabel.stringValue = "尚未确认文件清单。点击“扫描并选择文件”重新选择；不会移动任何文件。"
            return
        }
        selectedCandidateKeys = selection
        hasReviewedSelection = true
        let selected = selectedReports()
        let count = selected.reduce(0) { $0 + $1.candidates.count }
        let bytes = selected.reduce(Int64(0)) { $0 + $1.reclaimableBytes }
        summaryLabel.stringValue = "已选择 \(count) 个文件，原大小约 \(formatter.string(fromByteCount: bytes))。\n现在可点“移到废纸篓”；清空废纸篓后才会腾出空间。"
        cleanupButton.isEnabled = count > 0
    }

    private func selectedReports() -> [CacheAreaReport] {
        scannedReports.compactMap { report in
            let candidates = report.candidates.filter { selectedCandidateKeys.contains(CacheReviewWindowController.selectionKey(for: $0)) }
            guard !candidates.isEmpty else { return nil }
            return CacheAreaReport(
                rule: report.rule,
                rootURL: report.rootURL,
                cutoffDate: report.cutoffDate,
                reclaimableBytes: candidates.reduce(0) { $0 + $1.bytes },
                candidates: candidates
            )
        }
    }

    @objc private func confirmCleanup() {
        guard !busy, hasReviewedSelection, !scannedReports.isEmpty else { return }
        let reports = selectedReports()
        let count = reports.reduce(0) { $0 + $1.candidates.count }
        let bytes = reports.reduce(Int64(0)) { $0 + $1.reclaimableBytes }
        guard count > 0 else { return }
        let runningBeforeConfirmation = runningBundleIdentifiers()
        let details = reports.map { report in
            let running = !report.rule.relatedBundleIdentifiers.isDisjoint(with: runningBeforeConfirmation)
            let risk = running ? "高风险·运行中" : report.rule.riskLevel.title
            return "• [\(risk)] \(report.rule.displayName)：\(report.candidates.count) 个文件，\(formatter.string(fromByteCount: report.reclaimableBytes))\n  \(report.rule.riskReason)"
        }.joined(separator: "\n")
        let alert = NSAlert()
        alert.messageText = "确认将 \(count) 个文件移到废纸篓？"
        alert.informativeText = "早于 \(DateFormatter.localizedString(from: reports[0].cutoffDate, dateStyle: .medium, timeStyle: .none))，文件原大小共 \(formatter.string(fromByteCount: bytes))。\n\n\(details)\n\n移到废纸篓后可以恢复；若要腾出磁盘空间，还需自行清空废纸篓。相关应用仍在运行时，会再次提示风险。"
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "移到废纸篓")
        guard alert.runModal() == .alertSecondButtonReturn else { return }

        let running = runningBundleIdentifiers()
        let runningReports = reports.filter { !$0.rule.relatedBundleIdentifiers.isDisjoint(with: running) }
        var confirmedRunningRuleIDs = Set<String>()
        if !runningReports.isEmpty {
            let names = runningReports.map { "• \($0.rule.displayName)" }.joined(separator: "\n")
            let warning = NSAlert()
            warning.alertStyle = .critical
            warning.messageText = "相关应用仍在运行。还要移动其缓存吗？"
            warning.informativeText = "\(names)\n\n即使文件早于所选日期，也可能仍被应用读取或被缓存索引引用。移到废纸篓仍可能导致应用异常、缓存重建或重新下载；要腾出空间还需自行清空废纸篓。建议先退出应用，再重新扫描。"
            warning.addButton(withTitle: "我先退出应用")
            warning.addButton(withTitle: "仍要移到废纸篓")
            warning.addButton(withTitle: "取消")
            let choice = warning.runModal()
            if choice == .alertFirstButtonReturn {
                showMessage("请先退出相关应用，然后重新扫描并清理。")
                return
            }
            guard choice == .alertSecondButtonReturn else { return }
            confirmedRunningRuleIDs = Set(runningReports.map(\.rule.id))
        }

        let latestRunning = runningBundleIdentifiers()
        let unconfirmedRunning = reports.filter {
            !$0.rule.relatedBundleIdentifiers.isDisjoint(with: latestRunning) &&
            !confirmedRunningRuleIDs.contains($0.rule.id)
        }
        guard unconfirmedRunning.isEmpty else {
            showMessage("确认后又有相关应用启动。为避免未经确认就移动运行中的缓存，本次操作已取消；请重新扫描。")
            return
        }
        setBusy(true)
        summaryLabel.stringValue = "正在将所选缓存移到废纸篓…"
        let cleaner = self.cleaner
        let confirmedRuleIDs = confirmedRunningRuleIDs
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = cleaner.moveToTrash(
                reports: reports,
                runningBundleIdentifiers: latestRunning,
                confirmedRunningRuleIDs: confirmedRuleIDs
            )
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.scannedReports = []
                self.selectedCandidateKeys = []
                self.hasReviewedSelection = false
                self.setBusy(false)
                self.cleanupButton.isEnabled = false
                self.summaryLabel.stringValue = "移动结束。若要再次处理，请重新扫描。"
                self.onCleanup()
                self.showMessage("已将 \(result.movedFiles) 个文件移到废纸篓（原大小 \(self.formatter.string(fromByteCount: result.originalBytes))）。\n如需腾出磁盘空间，请自行检查并清空废纸篓。" +
                    (confirmedRuleIDs.isEmpty ? "" : "\n相关应用仍在运行，建议退出并检查应用是否正常。") +
                    (result.failures.isEmpty ? "" : "\n跳过或失败：\(result.failures.count) 个文件。\n" + result.failures.prefix(5).joined(separator: "\n")))
            }
        }
    }

    private func setBusy(_ value: Bool) {
        busy = value
        scanButton.isEnabled = !value && checkboxes.values.contains { $0.state == .on }
        selectAllButton.isEnabled = !value
        clearAllButton.isEnabled = !value
        cutoffPopup.isEnabled = !value
        cleanupButton.isEnabled = !value && hasReviewedSelection && !selectedCandidateKeys.isEmpty
        refreshRunningRules()
    }

    private func showMessage(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "资源库缓存管理"
        alert.informativeText = message
        alert.runModal()
    }
}
