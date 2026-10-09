import Foundation

/// Public beta scope is fixed in the build, not enabled by preferences or environment variables.
public enum ReleasePolicy {
    public static let version = "1.0.0-beta.1"
    public static let cacheMovingEnabled = false
    public static let cacheReadOnlyExplanation = "公开测试版仅查看缓存，暂不支持移到废纸篓；各应用缓存仍需使用验证。"
}
