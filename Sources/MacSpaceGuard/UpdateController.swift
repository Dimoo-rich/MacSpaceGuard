import AppKit
import MacSpaceGuardCore
import UserNotifications

/// UI state is accessed on the main thread; network work only returns a value to it.
@MainActor
final class UpdateController: NSObject, UNUserNotificationCenterDelegate {
    var onMenuChange: (() -> Void)?
    private let preferences = UpdatePreferences()
    private let checker = UpdateChecker()
    private var timer: Timer?
    private var task: Task<Void, Never>?
    private var requestID = UUID()
    private var isChecking = false
    private var isManualRequest = false
    private var availableUpdate: AvailableUpdate?
    private var lastFailure = false

    func start() {
        UNUserNotificationCenter.current().delegate = self
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIfDue() }
        }
        timer?.tolerance = 60
        checkIfDue()
    }

    func stop() {
        timer?.invalidate()
        cancelRequest()
    }

    func appendMenuItems(to menu: NSMenu) {
        let title = isChecking ? "正在检查更新…" : "检查更新"
        let check = menu.addItem(withTitle: title, action: #selector(checkManually), keyEquivalent: "")
        check.target = self
        check.isEnabled = !isChecking
        check.toolTip = "连接 GitHub 查询新版信息，不上传文件或扫描结果，不自动安装。"
        if let update = availableUpdate {
            let item = menu.addItem(withTitle: "发现新版 \(update.version) · 查看更新", action: #selector(showAvailableUpdate), keyEquivalent: "")
            item.target = self
        } else if lastFailure {
            let item = menu.addItem(withTitle: "更新检查失败 · 点击重试", action: #selector(checkManually), keyEquivalent: "")
            item.target = self
            item.isEnabled = !isChecking
        }
        let settings = NSMenuItem(title: "更新设置", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let daily = submenu.addItem(withTitle: "每日检查更新", action: #selector(toggleDailyChecks), keyEquivalent: "")
        daily.target = self
        daily.state = preferences.dailyChecksEnabled ? .on : .off
        submenu.addItem(.separator())
        for (index, channel) in UpdateChannel.allCases.enumerated() {
            let item = submenu.addItem(withTitle: channel.displayName, action: #selector(changeChannel(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = preferences.channel == channel ? .on : .off
        }
        settings.submenu = submenu
        menu.addItem(settings)
    }

    @objc private func checkManually() { check(manual: true) }

    @objc private func toggleDailyChecks() {
        if preferences.dailyChecksEnabled {
            preferences.dailyChecksEnabled = false
            if !isManualRequest { cancelRequest() }
        } else {
            let alert = NSAlert()
            alert.messageText = "启用每日检查更新？"
            alert.informativeText = "应用运行时，每 24 小时连接一次 GitHub 查询公开版本信息。GitHub 会收到普通网络请求（包括 IP 地址），但 MSG 不上传文件、文件名或扫描结果。\n\n发现新版只提醒你去官方发布页下载，不会自动下载或安装。可随时在“更新设置”关闭。"
            alert.addButton(withTitle: "启用")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            preferences.dailyChecksEnabled = true
            check(manual: false)
        }
        onMenuChange?()
    }

    @objc private func changeChannel(_ sender: NSMenuItem) {
        guard UpdateChannel.allCases.indices.contains(sender.tag) else { return }
        preferences.channel = UpdateChannel.allCases[sender.tag]
        cancelRequest()
        availableUpdate = nil
        lastFailure = false
        // Changing a local preference does not silently start a network request.
        onMenuChange?()
    }

    private func checkIfDue() {
        if preferences.isDailyCheckDue() { check(manual: false) }
    }

    private func cancelRequest() {
        requestID = UUID()
        task?.cancel()
        task = nil
        isChecking = false
        isManualRequest = false
    }

    private func check(manual: Bool) {
        guard !isChecking else { return }
        isChecking = true
        isManualRequest = manual
        lastFailure = false
        preferences.lastAttempt = Date()
        let id = UUID()
        requestID = id
        let channel = preferences.channel
        onMenuChange?()
        task = Task { [weak self, checker] in
            let result: Result<AvailableUpdate?, Error>
            do { result = .success(try await checker.check(currentVersion: ReleasePolicy.version, channel: channel)) }
            catch { result = .failure(error) }
            guard !Task.isCancelled else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.requestID == id else { return }
                self.isChecking = false
                self.isManualRequest = false
                self.task = nil
                switch result {
                case .success(let update):
                    self.availableUpdate = update
                    self.lastFailure = false
                    self.onMenuChange?()
                    if let update {
                        if manual { self.present(update) }
                        else { self.notifyOnce(update) }
                    } else if manual {
                        let alert = NSAlert()
                        alert.messageText = "未发现可下载的新版本"
                        alert.informativeText = "当前版本：\(ReleasePolicy.version)\n检查范围：\(channel.displayName)\n\n只提示已公开发布、提供 M 系列 Mac 安装包且版本号更高的版本。网络检查成功不代表新版本已经通过兼容性或安全验收。"
                        alert.addButton(withTitle: "知道了")
                        alert.runModal()
                    }
                case .failure(let error):
                    self.lastFailure = true
                    self.onMenuChange?()
                    if manual {
                        let alert = NSAlert()
                        alert.messageText = "暂时无法检查更新"
                        let reason = (error as? UpdateCheckError)?.errorDescription ?? "网络不可用或请求超时，请检查网络后重试。"
                        alert.informativeText = "\(reason)\n\n无法查询不代表已经是最新版，也不影响本地扫描和移到废纸篓。"
                        alert.addButton(withTitle: "知道了")
                        alert.addButton(withTitle: "前往官方发布页")
                        if alert.runModal() == .alertSecondButtonReturn {
                            self.open(UpdateChecker.releasesURL)
                        }
                    }
                }
            }
        }
    }

    private func notifyOnce(_ update: AvailableUpdate) {
        guard preferences.lastNotifiedVersion != update.version else { return }
        preferences.lastNotifiedVersion = update.version
        let content = UNMutableNotificationContent()
        content.title = "MacSpaceGuard 有新版本"
        content.body = "\(update.version)（\(update.isPrerelease ? "测试版" : "正式版")），在菜单栏点“查看更新”了解详情。不会自动安装。"
        content.userInfo = ["MSGUpdateVersion": update.version]
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "MSG-version-update", content: content, trigger: nil)
        )
        // The menu entry remains available even when system notifications are disabled.
    }

    @objc private func showAvailableUpdate() {
        if let update = availableUpdate { present(update) }
    }

    private func present(_ update: AvailableUpdate) {
        let alert = NSAlert()
        alert.messageText = "发现新版 \(update.version)"
        alert.informativeText = "当前版本：\(ReleasePolicy.version) → 新版本：\(update.version)（\(update.isPrerelease ? "测试版，非稳定版" : "正式版")）\n\n点击“前往下载”会打开官方发布页。先阅读系统要求和安装说明；下载后退出旧版，再拖入“应用程序”替换。MSG 不会自动安装，也不会关闭系统安全保护。"
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460, height: 200))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 440, height: 200))
        text.isEditable = false
        text.isSelectable = true
        text.isRichText = false
        text.font = .systemFont(ofSize: 13)
        text.textContainerInset = NSSize(width: 8, height: 8)
        text.isVerticallyResizable = true
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.string = update.notes
        scroll.documentView = text
        alert.accessoryView = scroll
        alert.addButton(withTitle: "前往下载")
        alert.addButton(withTitle: "稍后")
        if alert.runModal() == .alertFirstButtonReturn { open(update.releaseURL) }
    }

    private func open(_ url: URL) {
        if !NSWorkspace.shared.open(url) {
            let alert = NSAlert()
            alert.messageText = "无法打开浏览器"
            alert.informativeText = "请手动打开官方发布页：\n\(url.absoluteString)"
            alert.runModal()
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let version = response.notification.request.content.userInfo["MSGUpdateVersion"] as? String {
            DispatchQueue.main.async { [weak self] in
                guard let self, let update = self.availableUpdate, update.version == version else { return }
                self.present(update)
            }
        }
        completionHandler()
    }
}
