import AppKit
import MacSpaceGuardCore

@MainActor
final class SingleInstanceGuard {
    private let lock = ProcessInstanceLock()

    func allowLaunch() -> Bool {
        let identifier = Bundle.main.bundleIdentifier ?? "io.macspaceguard.app"
        // Older releases have no process lock. Check them as well, without
        // killing a process which might have a file-selection window open.
        let others = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == identifier && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
                && !$0.isTerminated
        }
        if !others.isEmpty { explainAlreadyRunning(); return false }
        do {
            guard try lock.acquire() else { explainAlreadyRunning(); return false }
            return true
        } catch {
            let alert = NSAlert()
            alert.messageText = "暂时无法启动 MSG"
            alert.informativeText = "无法确认是否已有 MSG 正在运行。为避免多份程序同时处理文件，此次启动已取消。请先退出其他 MSG 后重试；仍有问题时请反馈。不会删除或移动任何文件。"
            alert.addButton(withTitle: "知道了")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return false
        }
    }

    private func explainAlreadyRunning() {
        let alert = NSAlert()
        alert.messageText = "MSG 已在运行"
        alert.informativeText = "本次不会再启动第二份。\n\n请使用菜单栏已有的 MSG 图标。若你正在更新或试用新版，先在已有 MSG 菜单中点“退出”，再打开新版。"
        alert.addButton(withTitle: "知道了")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
