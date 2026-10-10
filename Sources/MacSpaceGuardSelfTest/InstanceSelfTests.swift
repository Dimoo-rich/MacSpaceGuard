import Darwin
import Foundation
import MacSpaceGuardCore

func runInstanceSelfTests() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MSGInstanceSelfTest-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("instance.lock")
    let owner = ProcessInstanceLock()
    try require(try owner.acquire(at: path), "首次获取进程锁失败")
    try require(try owner.acquire(at: path), "同一锁重复调用失败")

    func probe() throws -> Int32 {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        child.arguments = ["--probe-instance-lock", path.path]
        try child.run()
        child.waitUntilExit()
        return child.terminationStatus
    }
    try require(try probe() == 2, "第二个进程未被拒绝")
    owner.release()
    try require(try probe() == 0, "退出后无法再次启动")

    let holder = Process()
    let output = Pipe()
    holder.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    holder.arguments = ["--hold-instance-lock", path.path]
    holder.standardOutput = output
    try holder.run()
    let ready = output.fileHandleForReading.availableData
    try require(String(data: ready, encoding: .utf8)?.contains("locked") == true, "子进程没有持有锁")
    holder.terminate()
    holder.waitUntilExit()
    try require(try probe() == 0, "进程被终止后锁未释放")

    let link = directory.appendingPathComponent("link.lock")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: path)
    do {
        _ = try ProcessInstanceLock().acquire(at: link)
        throw SelfTestError.failed("跟随了锁文件符号链接")
    } catch is POSIXError {}
    do {
        _ = try ProcessInstanceLock().acquire(at: directory.appendingPathComponent("missing/instance.lock"))
        throw SelfTestError.failed("创建锁失败没有报告错误")
    } catch is POSIXError {}
    print("Instance self-test passed: cross-process exclusion, normal/terminated exit recovery, symlink rejection and failure reporting")
}
