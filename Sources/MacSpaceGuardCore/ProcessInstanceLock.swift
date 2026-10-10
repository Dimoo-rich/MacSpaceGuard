import Darwin
import Foundation

/// A per-user, process-held POSIX lock. Never unlink a live lock file: doing so
/// could let two processes lock different inodes under the same pathname.
public final class ProcessInstanceLock {
    private var descriptor: Int32 = -1

    public init() {}

    public static var defaultURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("io.macspaceguard.app.instance.lock")
    }

    /// Returns false only when another process owns the lock. Other failures
    /// must not silently allow a second app to start.
    public func acquire(at url: URL = ProcessInstanceLock.defaultURL) throws -> Bool {
        guard descriptor == -1 else { return true }
        let fd = open(url.path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        var metadata = stat()
        guard fstat(fd, &metadata) == 0,
              metadata.st_uid == geteuid(), metadata.st_mode & S_IFMT == S_IFREG else {
            close(fd)
            throw POSIXError(.EPERM)
        }
        var record = flock()
        record.l_type = Int16(F_WRLCK)
        record.l_whence = Int16(SEEK_SET)
        record.l_start = 0
        record.l_len = 0
        if fcntl(fd, F_SETLK, &record) == -1 {
            let code = errno
            close(fd)
            if code == EACCES || code == EAGAIN { return false }
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        descriptor = fd
        return true
    }

    public func release() {
        if descriptor >= 0 { close(descriptor); descriptor = -1 }
    }

    deinit { release() }
}
