import Foundation
import os

// Helper chạy root (launchd daemon), chỉ làm một việc: ghi tốc độ quạt vào SMC theo lệnh của app.
// Mọi trạng thái bất thường (app thoát/crash, im lặng quá lâu, helper bị tắt) → trả TẤT CẢ quạt về Auto.

let log = Logger(subsystem: FanHelperConstants.machService, category: "helper")

final class FanWriter {
    let queue = DispatchQueue(label: "fan-writer")
    private let smc: SMC
    private var watchdog = FanSafety.Watchdog(timeout: 15)
    private var fanCount: Int { Int(smc.value("FNum") ?? 0) }

    init() throws {
        smc = try SMC()
    }

    // Các hàm dưới đây chỉ được gọi trên `queue`.

    func set(_ index: Int, rpm: Double) throws {
        guard (0..<fanCount).contains(index) else {
            throw NSError(domain: "FanHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Không có quạt \(index)"])
        }
        if rpm < 0 {
            try smc.write("F\(index)Md", value: 0)
            watchdog.manualFans.remove(index)
            if watchdog.manualFans.isEmpty, smc.has("Ftst") { try? smc.write("Ftst", value: 0) }
            return
        }
        guard let min = smc.value("F\(index)Mn"), let max = smc.value("F\(index)Mx") else {
            throw NSError(domain: "FanHelper", code: 2, userInfo: [NSLocalizedDescriptionKey: "Không đọc được giới hạn quạt \(index)"])
        }
        if smc.has("Ftst") { try smc.write("Ftst", value: 1) } // chip M3 trở lên cần mở khoá
        try smc.write("F\(index)Md", value: 1)
        try smc.write("F\(index)Tg", value: FanSafety.clamp(rpm, min: min, max: max))
        watchdog.manualFans.insert(index)
        watchdog.beat()
    }

    func resetAll(_ reason: String) {
        for i in 0..<fanCount { try? smc.write("F\(i)Md", value: 0) }
        if smc.has("Ftst") { try? smc.write("Ftst", value: 0) }
        watchdog.manualFans.removeAll()
        log.notice("Trả quạt về Auto: \(reason, privacy: .public)")
    }

    func beat() { watchdog.beat() }

    func checkWatchdog() {
        if watchdog.shouldReset() { resetAll("quá 15s không có heartbeat") }
    }
}

final class Service: NSObject, FanHelperProtocol {
    let writer: FanWriter

    init(writer: FanWriter) {
        self.writer = writer
    }

    func version(reply: @escaping (String) -> Void) { reply(FanHelperConstants.version) }

    func setFan(_ index: Int, rpm: Double, reply: @escaping (String?) -> Void) {
        writer.queue.async {
            do {
                try self.writer.set(index, rpm: rpm)
                reply(nil)
            } catch {
                reply(error.localizedDescription)
            }
        }
    }

    func resetAll(reply: @escaping () -> Void) {
        writer.queue.async {
            self.writer.resetAll("app yêu cầu")
            reply()
        }
    }

    func heartbeat() { writer.queue.async { self.writer.beat() } }
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    let writer: FanWriter

    init(writer: FanWriter) {
        self.writer = writer
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: FanHelperProtocol.self)
        connection.exportedObject = Service(writer: writer)
        connection.invalidationHandler = { [writer] in writer.queue.async { writer.resetAll("app ngắt kết nối") } }
        connection.resume()
        return true
    }
}

guard let writer = try? FanWriter() else {
    log.error("Không mở được SMC")
    exit(1)
}
writer.queue.sync { writer.resetAll("helper khởi động") }

let delegate = ListenerDelegate(writer: writer)
let listener = NSXPCListener(machServiceName: FanHelperConstants.machService)
listener.setConnectionCodeSigningRequirement(FanHelperConstants.clientRequirement)
listener.delegate = delegate
listener.resume()

let watchdogTimer = DispatchSource.makeTimerSource(queue: writer.queue)
watchdogTimer.schedule(deadline: .now() + 5, repeating: 5)
watchdogTimer.setEventHandler { writer.checkWatchdog() }
watchdogTimer.resume()

var signalSources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT, SIGHUP] {
    signal(sig, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: sig, queue: writer.queue)
    source.setEventHandler {
        writer.resetAll("helper bị tắt (signal \(sig))")
        exit(0)
    }
    source.resume()
    signalSources.append(source)
}

log.notice("FanHelper v\(FanHelperConstants.version, privacy: .public) sẵn sàng")
dispatchMain()
