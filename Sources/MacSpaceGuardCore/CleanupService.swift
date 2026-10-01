import Foundation

public struct CleanupService {
    private let scanner: CacheScanner
    private let trashItem: (URL) throws -> Void

    public init(fileManager: FileManager = .default, trashItem: ((URL) throws -> Void)? = nil) {
        self.scanner = CacheScanner(fileManager: fileManager)
        self.trashItem = trashItem ?? { url in
            var trashedURL: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &trashedURL)
        }
    }

    /// Moves only explicitly reviewed, unchanged regular cache files to Trash.
    /// Nothing here permanently deletes a file or empties Trash.
    public func moveToTrash(
        reports: [CacheAreaReport],
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        runningBundleIdentifiers: Set<String> = [],
        confirmedRunningRuleIDs: Set<String> = []
    ) -> CleanupResult {
        var originalBytes: Int64 = 0
        var movedFiles = 0
        var failures: [String] = []

        for report in reports {
            let isRunning = !report.rule.relatedBundleIdentifiers.isDisjoint(with: runningBundleIdentifiers)
            guard (!isRunning || confirmedRunningRuleIDs.contains(report.rule.id)),
                  let safeRoot = scanner.safeRoot(for: report.rule, homeDirectory: homeDirectory),
                  safeRoot == report.rootURL.standardizedFileURL.resolvingSymlinksInPath() else {
                failures.append("跳过不安全或正在使用的目录：\(report.rule.displayName)")
                continue
            }
            for candidate in report.candidates {
                guard candidate.ruleID == report.rule.id,
                      scanner.isSafeDescendant(candidate.url, of: report.rootURL) else {
                    failures.append("拒绝移动不安全路径：\(candidate.url.path)")
                    continue
                }

                do {
                    // URL resource values can be cached by the enumerator. Read from a new URL
                    // immediately before moving so a changed file is not treated as the scan result.
                    let currentURL = URL(fileURLWithPath: candidate.url.path)
                    let values = try currentURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey])
                    guard values.isRegularFile == true,
                          values.isSymbolicLink != true,
                          FileIdentity(url: currentURL) == candidate.fileIdentity,
                          let modified = values.contentModificationDate,
                          modified == candidate.modificationDate,
                          Int64(values.fileSize ?? -1) == candidate.bytes,
                          modified < report.cutoffDate else {
                        failures.append("跳过已变化或不符合日期的文件：\(candidate.url.lastPathComponent)")
                        continue
                    }
                    try trashItem(currentURL)
                    originalBytes += candidate.bytes
                    movedFiles += 1
                } catch {
                    failures.append("\(candidate.url.lastPathComponent)：\(error.localizedDescription)")
                }
            }
        }

        return CleanupResult(originalBytes: originalBytes, movedFiles: movedFiles, failures: failures)
    }
}
