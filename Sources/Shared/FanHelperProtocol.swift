import Foundation

public enum FanHelperConstants {
    public static let machService = "com.local.MacCleaner.FanHelper"
    public static let plistName = "com.local.MacCleaner.FanHelper.plist"
    public static let version = "1"
    public static let teamID = "B3855LQTCZ"
    /// Helper chỉ nhận lệnh từ đúng app Mac Cleaner ký bằng chứng chỉ của team này.
    public static let clientRequirement =
        #"anchor apple generic and identifier "com.local.MacCleaner" and certificate leaf[subject.OU] = "\#(teamID)""#
    public static let helperRequirement =
        #"anchor apple generic and identifier "com.local.MacCleaner.FanHelper" and certificate leaf[subject.OU] = "\#(teamID)""#
}

/// Giao tiếp XPC app ↔ helper root. `rpm < 0` nghĩa là trả quạt về Auto.
@objc public protocol FanHelperProtocol {
    func version(reply: @escaping (String) -> Void)
    func setFan(_ index: Int, rpm: Double, reply: @escaping (String?) -> Void)
    func resetAll(reply: @escaping () -> Void)
    func heartbeat()
}

public enum FanSafety {
    public static func clamp(_ rpm: Double, min: Double, max: Double) -> Double {
        guard rpm.isFinite else { return min }
        return Swift.min(max, Swift.max(min, rpm))
    }

    /// App phải gửi heartbeat đều; im lặng quá `timeout` giây khi còn quạt thủ công → trả về Auto.
    public struct Watchdog {
        public let timeout: TimeInterval
        public var manualFans: Set<Int> = []
        private var lastBeat = Date.distantPast

        public init(timeout: TimeInterval) {
            self.timeout = timeout
        }

        public mutating func beat(now: Date = Date()) { lastBeat = now }

        public func shouldReset(now: Date = Date()) -> Bool {
            !manualFans.isEmpty && now.timeIntervalSince(lastBeat) > timeout
        }
    }
}
