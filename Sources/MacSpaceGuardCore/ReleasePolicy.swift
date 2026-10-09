import Foundation

/// Release identity and user-facing explanation of the explicit Trash-only workflow.
public enum ReleasePolicy {
    public static let version = "1.0.0-beta.2"
    public static let cacheSafetyExplanation = "白名单缓存可逐文件选择并二次确认后移到废纸篓；运行中的应用需额外确认。风险等级不是安全保证，建议先退出相关应用。"
}
