import Foundation

/// Compatibility boundary for previous callers. Cache moving is deliberately unavailable
/// in this public beta, including direct calls and explicit running-app confirmation.
/// Reintroducing it requires application-specific evidence and a new safety review.
public struct CleanupService {
    public init(fileManager: FileManager = .default, trashItem: ((URL) throws -> Void)? = nil) {}

    public func moveToTrash(
        reports: [CacheAreaReport],
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        runningBundleIdentifiers: Set<String> = [],
        confirmedRunningRuleIDs: Set<String> = []
    ) -> CleanupResult {
        CleanupResult(
            originalBytes: 0,
            movedFiles: 0,
            failures: reports.flatMap { report in
                report.candidates.map { "\($0.url.lastPathComponent)：\(ReleasePolicy.cacheReadOnlyExplanation)" }
            }
        )
    }
}
