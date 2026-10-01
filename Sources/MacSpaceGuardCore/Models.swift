import Foundation

public enum PressureLevel: String, Codable, Sendable {
    case normal
    case warning
    case critical
    case unavailable

    public var title: String {
        switch self {
        case .normal: return "正常"
        case .warning: return "偏高"
        case .critical: return "严重"
        case .unavailable: return "未知"
        }
    }
}

public struct SystemSnapshot: Sendable {
    public let date: Date
    public let totalMemory: UInt64
    public let estimatedUsedMemory: UInt64
    public let memoryFreePercentage: Int?
    public let swapUsed: UInt64?
    public let totalDisk: Int64
    public let availableDisk: Int64
    public let pressure: PressureLevel

    public init(
        date: Date,
        totalMemory: UInt64,
        estimatedUsedMemory: UInt64,
        memoryFreePercentage: Int?,
        swapUsed: UInt64?,
        totalDisk: Int64,
        availableDisk: Int64,
        pressure: PressureLevel
    ) {
        self.date = date
        self.totalMemory = totalMemory
        self.estimatedUsedMemory = estimatedUsedMemory
        self.memoryFreePercentage = memoryFreePercentage
        self.swapUsed = swapUsed
        self.totalDisk = totalDisk
        self.availableDisk = availableDisk
        self.pressure = pressure
    }
}

public struct CacheRule: Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let relativePath: String
    public let minimumAgeDays: Int
    public let relatedBundleIdentifiers: Set<String>
    public let riskLevel: CleanupRiskLevel
    public let riskReason: String

    public init(
        id: String,
        displayName: String,
        relativePath: String,
        minimumAgeDays: Int,
        relatedBundleIdentifiers: Set<String> = [],
        riskLevel: CleanupRiskLevel = .caution,
        riskReason: String = "可能仍被应用使用；清理前请核对路径和文件。"
    ) {
        self.id = id
        self.displayName = displayName
        self.relativePath = relativePath
        self.minimumAgeDays = minimumAgeDays
        self.relatedBundleIdentifiers = relatedBundleIdentifiers
        self.riskLevel = riskLevel
        self.riskReason = riskReason
    }

    public func effectiveRisk(whileRunning bundleIdentifiers: Set<String>) -> CleanupRiskLevel {
        relatedBundleIdentifiers.isDisjoint(with: bundleIdentifiers) ? riskLevel : .high
    }
}

public enum CleanupRiskLevel: String, Hashable, Sendable {
    case low
    case caution
    case high

    public var title: String {
        switch self {
        case .low: return "较低风险"
        case .caution: return "需谨慎"
        case .high: return "高风险"
        }
    }
}

public struct CacheCandidate: Sendable {
    public let url: URL
    public let bytes: Int64
    public let modificationDate: Date
    public let ruleID: String
    public let fileIdentity: FileIdentity

    public init(url: URL, bytes: Int64, modificationDate: Date, ruleID: String, fileIdentity: FileIdentity) {
        self.url = url
        self.bytes = bytes
        self.modificationDate = modificationDate
        self.ruleID = ruleID
        self.fileIdentity = fileIdentity
    }
}

public struct CacheAreaReport: Sendable {
    public let rule: CacheRule
    public let rootURL: URL
    public let cutoffDate: Date
    public let reclaimableBytes: Int64
    public let candidates: [CacheCandidate]

    public init(rule: CacheRule, rootURL: URL, cutoffDate: Date, reclaimableBytes: Int64, candidates: [CacheCandidate]) {
        self.rule = rule
        self.rootURL = rootURL
        self.cutoffDate = cutoffDate
        self.reclaimableBytes = reclaimableBytes
        self.candidates = candidates
    }
}

public struct CleanupResult: Sendable {
    public let originalBytes: Int64
    public let movedFiles: Int
    public let failures: [String]

    public init(originalBytes: Int64, movedFiles: Int, failures: [String]) {
        self.originalBytes = originalBytes
        self.movedFiles = movedFiles
        self.failures = failures
    }
}
