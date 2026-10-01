import Foundation

public struct InstallerTrashResult: Sendable {
    public let movedFiles: Int
    public let originalBytes: Int64
    public let failures: [String]

    public init(movedFiles: Int, originalBytes: Int64, failures: [String]) {
        self.movedFiles = movedFiles
        self.originalBytes = originalBytes
        self.failures = failures
    }
}

public struct InstallerTrashService {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Moves explicitly selected installer files to Trash. A stale or changed scan
    /// result is skipped; this never runs an installer or deletes it permanently.
    public func moveToTrash(_ findings: [InstallerFinding], from directory: URL) -> InstallerTrashResult {
        let root = directory.standardizedFileURL.resolvingSymlinksInPath()
        var movedFiles = 0
        var originalBytes: Int64 = 0
        var failures: [String] = []

        for finding in findings {
            let file = URL(fileURLWithPath: finding.url.path).standardizedFileURL
            guard file.deletingLastPathComponent() == root,
                  file.resolvingSymlinksInPath() == file,
                  InstallerScanner.supportedExtensions.contains(file.pathExtension.lowercased()) else {
                failures.append("跳过不在所选文件夹内或类型不受支持的文件：\(file.lastPathComponent)")
                continue
            }
            do {
                let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey])
                guard values.isRegularFile == true,
                      values.isSymbolicLink != true,
                      FileIdentity(url: file) == finding.fileIdentity,
                      Int64(values.fileSize ?? -1) == finding.bytes,
                      values.contentModificationDate == finding.modificationDate else {
                    failures.append("文件已变化，请重新扫描：\(file.lastPathComponent)")
                    continue
                }
                var trashedURL: NSURL?
                try fileManager.trashItem(at: file, resultingItemURL: &trashedURL)
                movedFiles += 1
                originalBytes += finding.bytes
            } catch {
                failures.append("\(file.lastPathComponent)：\(error.localizedDescription)")
            }
        }

        return InstallerTrashResult(movedFiles: movedFiles, originalBytes: originalBytes, failures: failures)
    }
}
