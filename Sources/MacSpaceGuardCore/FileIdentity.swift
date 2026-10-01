import Darwin
import Foundation

/// A file's device and inode, captured without following symbolic links.
public struct FileIdentity: Equatable, Sendable {
    public let device: UInt64
    public let inode: UInt64

    public init?(url: URL) {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0,
              metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { return nil }
        device = UInt64(metadata.st_dev)
        inode = UInt64(metadata.st_ino)
    }
}
