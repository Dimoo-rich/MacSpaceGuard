import Darwin
import Foundation

public struct SystemMonitor: Sendable {
    public init() {}

    public func snapshot() -> SystemSnapshot {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let usedMemory = estimatedUsedMemory() ?? 0
        let freePercentage = memoryFreePercentage()
        let swap = swapUsage()
        let disk = diskUsage()
        let pressure = pressureLevel(freePercentage: freePercentage)

        return SystemSnapshot(
            date: Date(),
            totalMemory: totalMemory,
            estimatedUsedMemory: usedMemory,
            memoryFreePercentage: freePercentage,
            swapUsed: swap,
            totalDisk: disk.total,
            availableDisk: disk.available,
            pressure: pressure
        )
    }

    private func estimatedUsedMemory() -> UInt64? {
        var statistics = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let status = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }

        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }

        let usedPages = UInt64(statistics.active_count)
            + UInt64(statistics.wire_count)
            + UInt64(statistics.compressor_page_count)
        return usedPages * UInt64(pageSize)
    }

    private func diskUsage() -> (total: Int64, available: Int64) {
        do {
            let values = try URL(fileURLWithPath: "/").resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = values.volumeAvailableCapacity.map(Int64.init)
                ?? values.volumeAvailableCapacityForImportantUsage
                ?? 0
            return (total, available)
        } catch {
            return (0, 0)
        }
    }

    private func swapUsage() -> UInt64? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
        process.arguments = ["-n", "vm.swapusage"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            return Self.parseSwapUsage(output)
        } catch {
            return nil
        }
    }

    private func memoryFreePercentage() -> Int? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/memory_pressure")
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            return Self.parseMemoryFreePercentage(output)
        } catch {
            return nil
        }
    }

    public static func parseMemoryFreePercentage(_ text: String) -> Int? {
        let pattern = #"System-wide memory free percentage:\s*([0-9]+)%"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              let valueRange = Range(match.range(at: 1), in: text),
              let value = Int(text[valueRange]),
              (0...100).contains(value) else {
            return nil
        }
        return value
    }

    public static func parseSwapUsage(_ text: String) -> UInt64? {
        let pattern = #"used\s*=\s*([0-9.]+)([KMGTP])"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let value = Double(text[valueRange]) else {
            return nil
        }

        let powers: [Character: Double] = [
            "K": 1_024,
            "M": 1_024 * 1_024,
            "G": 1_024 * 1_024 * 1_024,
            "T": 1_024 * 1_024 * 1_024 * 1_024,
            "P": 1_024 * 1_024 * 1_024 * 1_024 * 1_024
        ]
        let unit = Character(String(text[unitRange]).uppercased())
        guard let multiplier = powers[unit] else { return nil }
        return UInt64(value * multiplier)
    }

    private func pressureLevel(freePercentage: Int?) -> PressureLevel {
        guard let freePercentage else { return .unavailable }
        if freePercentage <= 10 { return .critical }
        if freePercentage <= 20 { return .warning }
        return .normal
    }
}
