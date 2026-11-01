import Foundation
import MacCleanerCore
import Observation
import ServiceManagement

/// Đăng ký helper root (SMAppService) và gửi lệnh qua XPC.
@Observable @MainActor
final class FanHelperClient {
    enum State: Equatable {
        case notInstalled, needsApproval, ready
        case failed(String)
    }

    var state: State = .notInstalled
    private let service = SMAppService.daemon(plistName: FanHelperConstants.plistName)
    @ObservationIgnored private var connection: NSXPCConnection?

    func refreshState() {
        switch service.status {
        case .enabled: state = .ready
        case .requiresApproval: state = .needsApproval
        default: if case .failed = state {} else { state = .notInstalled }
        }
    }

    func install() {
        do {
            try service.register()
            ActionLogger.default.log("HELPER", "register OK, status \(service.status.rawValue)")
        } catch {
            ActionLogger.default.log("HELPER", "register lỗi: \(error) — status \(service.status.rawValue)")
            refreshState()
            if state != .needsApproval { state = .failed(error.localizedDescription) }
        }
        refreshState()
        if state == .needsApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    func uninstall() async {
        await resetAll()
        try? await service.unregister()
        refreshState()
    }

    /// Trả về lỗi (nếu có). `rpm < 0` = Auto.
    func setFan(_ index: Int, rpm: Double) async -> String? {
        await withCheckedContinuation { cont in
            let proxy = makeProxy { cont.resume(returning: $0.localizedDescription) }
            proxy?.setFan(index, rpm: rpm) { cont.resume(returning: $0) }
            if proxy == nil { cont.resume(returning: "Chưa kết nối được helper") }
        }
    }

    func resetAll() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let proxy = makeProxy { _ in cont.resume() }
            proxy?.resetAll { cont.resume() }
            if proxy == nil { cont.resume() }
        }
    }

    /// Dùng khi app sắp thoát: chờ helper trả quạt về Auto (tối đa ~1s).
    func resetAllBlocking() {
        guard state == .ready, let c = connect() else { return }
        let proxy = c.synchronousRemoteObjectProxyWithErrorHandler { _ in } as? FanHelperProtocol
        proxy?.resetAll {}
    }

    func heartbeat() {
        makeProxy { _ in }?.heartbeat()
    }

    private func makeProxy(onError: @escaping (Error) -> Void) -> FanHelperProtocol? {
        connect()?.remoteObjectProxyWithErrorHandler(onError) as? FanHelperProtocol
    }

    private func connect() -> NSXPCConnection? {
        if let connection { return connection }
        let c = NSXPCConnection(machServiceName: FanHelperConstants.machService, options: .privileged)
        c.remoteObjectInterface = NSXPCInterface(with: FanHelperProtocol.self)
        c.setCodeSigningRequirement(FanHelperConstants.helperRequirement)
        let drop: @Sendable () -> Void = { [weak self] in Task { @MainActor in self?.connection = nil } }
        c.invalidationHandler = drop
        c.interruptionHandler = drop
        c.resume()
        connection = c
        return c
    }
}
