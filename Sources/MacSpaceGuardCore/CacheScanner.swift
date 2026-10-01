import Foundation

public struct CacheScanner {
    public static let defaultRules: [CacheRule] = [
        CacheRule(id: "chatcut-updater", displayName: "ChatCut 更新缓存", relativePath: "Library/Caches/chatcut-desktop-updater", minimumAgeDays: 7, relatedBundleIdentifiers: ["io.chatcut.desktop"], riskLevel: .low, riskReason: "旧版更新下载文件；删除后可能需要重新下载更新。"),
        CacheRule(id: "chatcut-shipit", displayName: "ChatCut 安装残留", relativePath: "Library/Caches/io.chatcut.desktop.ShipIt", minimumAgeDays: 7, relatedBundleIdentifiers: ["io.chatcut.desktop"], riskLevel: .caution, riskReason: "安装过程残留；先确认 ChatCut 已完成安装且没有正在更新。"),
        CacheRule(id: "coze-updater", displayName: "Coze 更新缓存", relativePath: "Library/Caches/coze-updater", minimumAgeDays: 7, relatedBundleIdentifiers: ["cn.coze.desktop"], riskLevel: .low, riskReason: "旧版更新下载文件；删除后可能需要重新下载更新。"),
        CacheRule(id: "google-update", displayName: "Google 更新缓存", relativePath: "Library/Caches/com.google.SoftwareUpdate", minimumAgeDays: 14, relatedBundleIdentifiers: ["com.google.Chrome"], riskLevel: .caution, riskReason: "可能包含尚未完成的更新；建议先确认 Chrome 已更新完毕。"),
        CacheRule(id: "homebrew", displayName: "Homebrew 下载缓存", relativePath: "Library/Caches/Homebrew", minimumAgeDays: 14, riskLevel: .caution, riskReason: "可能包含离线重装所需下载包；删除后需要重新下载。"),
        CacheRule(id: "node-gyp", displayName: "Node 编译缓存", relativePath: "Library/Caches/node-gyp", minimumAgeDays: 30, riskLevel: .caution, riskReason: "开发工具缓存；删除后可能重新下载或编译，离线时可能受影响。"),
        CacheRule(id: "pip", displayName: "Python 下载缓存", relativePath: "Library/Caches/pip", minimumAgeDays: 30, riskLevel: .caution, riskReason: "Python 包下载缓存；删除后可能重新下载，离线时可能受影响。"),
        CacheRule(id: "chrome-web-cache", displayName: "Chrome 网页缓存", relativePath: "Library/Caches/Google/Chrome/Default/Cache/Cache_Data", minimumAgeDays: 30, relatedBundleIdentifiers: ["com.google.Chrome"], riskLevel: .caution, riskReason: "网页缓存可能仍被索引引用；删除后网站可能重新下载内容。"),
        CacheRule(id: "wechat-network-cache", displayName: "微信 WebKit 网络缓存", relativePath: "Library/Caches/com.tencent.xinwechat2/WebKit/NetworkCache", minimumAgeDays: 30, relatedBundleIdentifiers: ["com.tencent.xinwechat2"], riskLevel: .caution, riskReason: "网络缓存可能仍被微信使用；删除后可能重新下载内容。"),
        CacheRule(id: "wechat-update-cache", displayName: "微信安装更新缓存", relativePath: "Library/Caches/com.tencent.xinWeChat/org.sparkle-project.Sparkle/Installation", minimumAgeDays: 30, relatedBundleIdentifiers: ["com.tencent.xinWeChat"], riskLevel: .caution, riskReason: "可能是尚未完成的更新文件；请先确认微信已经完成更新。")
    ]

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func scan(
        rules: [CacheRule] = Self.defaultRules,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        now: Date = Date(),
        cutoffDate: Date? = nil
    ) -> [CacheAreaReport] {
        rules.compactMap { scan(rule: $0, homeDirectory: homeDirectory, now: now, cutoffDate: cutoffDate) }
    }

    public static func rulesSafeToScan(whileRunning bundleIdentifiers: Set<String>) -> [CacheRule] {
        defaultRules.filter { $0.relatedBundleIdentifiers.isDisjoint(with: bundleIdentifiers) }
    }

    private func scan(rule: CacheRule, homeDirectory: URL, now: Date, cutoffDate: Date?) -> CacheAreaReport? {
        guard let root = safeRoot(for: rule, homeDirectory: homeDirectory) else { return nil }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }

        let cutoff = cutoffDate ?? (Calendar.current.date(byAdding: .day, value: -rule.minimumAgeDays, to: now) ?? now)
        guard cutoff <= now else { return nil }
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return nil
        }

        var candidates: [CacheCandidate] = []
        for case let fileURL as URL in enumerator {
            guard isSafeDescendant(fileURL, of: root),
                  let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isSymbolicLink != true,
                  values.isRegularFile == true,
                  let fileIdentity = FileIdentity(url: fileURL),
                  ![".DS_Store", "salt", "index", "the-real-index"].contains(fileURL.lastPathComponent),
                  let modified = values.contentModificationDate,
                  modified < cutoff else {
                continue
            }
            let bytes = Int64(values.fileSize ?? 0)
            candidates.append(CacheCandidate(url: fileURL, bytes: bytes, modificationDate: modified, ruleID: rule.id, fileIdentity: fileIdentity))
        }

        let total = candidates.reduce(Int64(0)) { $0 + $1.bytes }
        return CacheAreaReport(rule: rule, rootURL: root, cutoffDate: cutoff, reclaimableBytes: total, candidates: candidates)
    }

    public func safeRoot(for rule: CacheRule, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL? {
        let home = homeDirectory.standardizedFileURL.resolvingSymlinksInPath()
        let requested = home.appendingPathComponent(rule.relativePath, isDirectory: true).standardizedFileURL
        let root = requested.resolvingSymlinksInPath()
        let caches = home.appendingPathComponent("Library/Caches", isDirectory: true).path
        guard root.path == requested.path,
              root.path.hasPrefix(caches + "/") else { return nil }
        return root
    }

    public func isSafeDescendant(_ candidate: URL, of root: URL) -> Bool {
        let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath().path
        let resolvedCandidate = candidate.standardizedFileURL.resolvingSymlinksInPath().path
        return resolvedCandidate.hasPrefix(resolvedRoot + "/")
    }
}
