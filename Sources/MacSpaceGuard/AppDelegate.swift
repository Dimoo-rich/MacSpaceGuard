import AppKit
import MacSpaceGuardCore
import ServiceManagement
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = SystemMonitor()
    private let scanner = CacheScanner()
    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()

    private var statusItem: NSStatusItem!
    private var cacheManager: CacheManagerWindowController?
    private var installerManager: InstallerManagerWindowController?
    private var timer: Timer?
    private var snapshot: SystemSnapshot?
    private var reports: [CacheAreaReport] = []
    private var isChecking = false

    private let intervalDefaultsKey = "automaticCheckIntervalHours"
    private let supportedIntervals = [1, 3, 6, 12]
    private var intervalHours: Int {
        let saved = UserDefaults.standard.integer(forKey: intervalDefaultsKey)
        return supportedIntervals.contains(saved) ? saved : 6
    }
    private let lowDiskWarningBytes: Int64 = 20 * 1_024 * 1_024 * 1_024
    private let urgentDiskBytes: Int64 = 12 * 1_024 * 1_024 * 1_024

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setStatusMark(.normal)
        statusItem.button?.toolTip = "MacSpaceGuard"

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        rebuildMenu()
        checkNow(showCompletionAlert: false)

        scheduleAutomaticChecks()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func returnToMenuBarIfNoWindows() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.cacheManager?.window?.isVisible != true && self.installerManager?.window?.isVisible != true {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    private func scheduleAutomaticChecks() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalHours * 60 * 60), repeats: true) { [weak self] _ in
            self?.checkNow(showCompletionAlert: false)
        }
        timer?.tolerance = 60
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let title = NSMenuItem(title: "MacSpaceGuard", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        if isChecking {
            let checking = NSMenuItem(title: "正在检查…", action: nil, keyEquivalent: "")
            checking.isEnabled = false
            menu.addItem(checking)
        } else if let snapshot {
            addInfo("系统内存余量：\(snapshot.memoryFreePercentage.map { "\($0)%" } ?? "不可用")", to: menu)
            addInfo("估算内存使用：\(format(UInt64(snapshot.estimatedUsedMemory))) / \(format(snapshot.totalMemory))", to: menu)
            addInfo("交换空间：\(snapshot.swapUsed.map(format) ?? "不可用")", to: menu)
            addInfo("磁盘剩余：\(format(snapshot.availableDisk))", to: menu)
            addInfo("旧缓存统计（只读）：\(format(reclaimableBytes))", to: menu)
            addInfo("上次检查：\(DateFormatter.localizedString(from: snapshot.date, dateStyle: .none, timeStyle: .short))", to: menu)
        } else {
            addInfo("尚未检查", to: menu)
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "立即检查", action: #selector(runManualCheck), keyEquivalent: "r").target = self

        let cleanItem = menu.addItem(withTitle: "资源库缓存查看", action: #selector(openCacheManager), keyEquivalent: "")
        cleanItem.target = self
        menu.addItem(withTitle: "清理下载的安装包", action: #selector(openInstallerManager), keyEquivalent: "").target = self
        let intervalItem = NSMenuItem(title: "自动检查间隔：每 \(intervalHours) 小时", action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()
        for hours in supportedIntervals {
            let option = intervalMenu.addItem(withTitle: "每 \(hours) 小时", action: #selector(changeInterval(_:)), keyEquivalent: "")
            option.target = self
            option.tag = hours
            option.state = hours == intervalHours ? .on : .off
        }
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        let loginItem = menu.addItem(withTitle: "登录时启动", action: #selector(toggleLoginItem(_:)), keyEquivalent: "")
        loginItem.target = self
        if #available(macOS 13.0, *) {
            loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "关于与隐私", action: #selector(showAbout), keyEquivalent: "").target = self
        menu.addItem(withTitle: "退出", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    private var reclaimableBytes: Int64 {
        reports.reduce(0) { $0 + $1.reclaimableBytes }
    }

    private func addInfo(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func format(_ value: UInt64) -> String {
        byteFormatter.string(fromByteCount: Int64(clamping: value))
    }

    private func format(_ value: Int64) -> String {
        byteFormatter.string(fromByteCount: value)
    }

    @objc private func runManualCheck() {
        checkNow(showCompletionAlert: true)
    }

    @objc private func openCacheManager() {
        if cacheManager == nil {
            cacheManager = CacheManagerWindowController(onClose: { [weak self] in
                self?.returnToMenuBarIfNoWindows()
            })
        }
        NSApp.setActivationPolicy(.regular)
        cacheManager?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openInstallerManager() {
        if installerManager == nil {
            installerManager = InstallerManagerWindowController(onClose: { [weak self] in
                self?.returnToMenuBarIfNoWindows()
            })
        }
        NSApp.setActivationPolicy(.regular)
        installerManager?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func changeInterval(_ sender: NSMenuItem) {
        setIntervalHours(sender.tag)
    }

    private func setIntervalHours(_ hours: Int) {
        guard supportedIntervals.contains(hours) else { return }
        UserDefaults.standard.set(hours, forKey: intervalDefaultsKey)
        scheduleAutomaticChecks()
        rebuildMenu()
    }

    private func checkNow(showCompletionAlert: Bool) {
        guard !isChecking else { return }
        isChecking = true
        rebuildMenu()
        let runningBundleIdentifiers = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        )
        let safeRules = CacheScanner.rulesSafeToScan(whileRunning: runningBundleIdentifiers)

        DispatchQueue.global(qos: .utility).async { [weak self, monitor, scanner, safeRules] in
            let currentSnapshot = monitor.snapshot()
            let currentReports = scanner.scan(rules: safeRules)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.snapshot = currentSnapshot
                self.reports = currentReports
                self.isChecking = false
                self.updateStatusIcon()
                self.rebuildMenu()
                self.sendWarningIfNeeded()

                if showCompletionAlert {
                    let alert = NSAlert()
                    alert.messageText = "检查完成"
                    alert.informativeText = "磁盘剩余 \(self.format(currentSnapshot.availableDisk))，旧缓存统计约 \(self.format(self.reclaimableBytes))。\(ReleasePolicy.cacheReadOnlyExplanation)"
                    alert.runModal()
                }
            }
        }
    }

    private func updateStatusIcon() {
        guard let snapshot else { return }
        if snapshot.availableDisk <= urgentDiskBytes || snapshot.pressure == .critical {
            setStatusMark(.critical)
            statusItem.button?.toolTip = "MacSpaceGuard：内存或磁盘空间需要立即关注"
        } else if snapshot.availableDisk <= lowDiskWarningBytes || snapshot.pressure == .warning {
            setStatusMark(.warning)
            statusItem.button?.toolTip = "MacSpaceGuard：内存或磁盘空间偏低"
        } else {
            setStatusMark(.normal)
            statusItem.button?.toolTip = "MacSpaceGuard：状态正常"
        }
    }

    private func setStatusMark(_ level: MenuBarMark.Level) {
        statusItem.button?.title = ""
        statusItem.button?.image = MenuBarMark.image(for: level)
        statusItem.button?.imagePosition = .imageOnly
    }

    private func sendWarningIfNeeded() {
        guard let snapshot else { return }
        var messages: [String] = []
        if snapshot.availableDisk <= lowDiskWarningBytes {
            messages.append("磁盘仅剩 \(format(snapshot.availableDisk))")
        }
        if snapshot.pressure == .warning || snapshot.pressure == .critical {
            messages.append("系统内存余量偏低")
        }
        guard !messages.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "MacSpaceGuard 提醒"
        content.body = messages.joined(separator: "，") + "。"
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "无法修改登录启动设置"
            alert.runModal()
        }
        rebuildMenu()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "MSG \(ReleasePolicy.version)（公开测试版）"
        alert.informativeText = "每 \(intervalHours) 小时在本机检查内存状态、交换空间和磁盘余量，不会上传扫描结果。\n\n\(ReleasePolicy.cacheReadOnlyExplanation)\n下载安装包可逐项选择并确认后移到废纸篓；MSG 不会清空废纸篓，也不会直接释放运行内存。\n\n仅面向 M 系列 Mac；另一台 Mac 及最低系统兼容性尚未验证。此包为临时签名，未经 Apple 公证。"
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
