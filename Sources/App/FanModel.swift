import AppKit
import MacCleanerCore
import Observation
import ServiceManagement

@Observable @MainActor
final class FanModel {
    var fans: [FanInfo] = []
    var sensors: [SensorReading] = []
    var history = TemperatureHistory()
    var presets: [FanPreset]
    var activePresetID: UUID {
        didSet {
            UserDefaults.standard.set(activePresetID.uuidString, forKey: "activeFanPreset")
            applySoon()
        }
    }
    var boostUntil: Date?
    var lastError: String?
    var monitorError: String?
    var otherControllerRunning = false
    let helper = FanHelperClient()

    @ObservationIgnored private var controller = FanController()
    @ObservationIgnored private var lastSent: [Int: Double?] = [:]
    @ObservationIgnored private var paused = false
    @ObservationIgnored private let store = PresetStore.default
    @ObservationIgnored private var started = false

    init() {
        presets = FanPreset.builtIns + PresetStore.default.load()
        activePresetID = UserDefaults.standard.string(forKey: "activeFanPreset").flatMap(UUID.init) ?? FanPreset.auto.id
    }

    var activePreset: FanPreset { presets.first { $0.id == activePresetID } ?? .auto }
    var cpuTemp: Double? { TempSource.group(.cpu).temperature(in: sensors) }
    var gpuTemp: Double? { TempSource.group(.gpu).temperature(in: sensors) }
    var isBoosting: Bool { boostUntil.map { $0 > Date() } ?? false }

    // MARK: Vòng lặp

    func start() {
        guard !started else { return }
        started = true
        observeSleep()
        Task { await run() }
    }

    private func run() async {
        guard let monitor = await Task.detached(operation: { try? HardwareMonitor(smc: SMC()) }).value else {
            monitorError = "Không đọc được SMC của máy này"
            return
        }
        helper.refreshState()
        while !Task.isCancelled {
            let (f, s) = await Task.detached { (monitor.fans(), monitor.sensors()) }.value
            fans = f
            sensors = s
            history.append(HistorySample(date: Date(), cpu: cpuTemp ?? 0, gpu: gpuTemp ?? 0, fanRPM: f.map(\.actual)))
            otherControllerRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.crystalidea.macsfancontrol").isEmpty
            if helper.state != .ready { helper.refreshState() }
            await apply()
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func applySoon() { Task { await apply() } }

    private func apply() async {
        guard helper.state == .ready, !paused, !fans.isEmpty else { return }
        if let until = boostUntil, until <= Date() { boostUntil = nil }
        let targets = controller.targets(fans: fans, sensors: sensors, preset: activePreset, boost: isBoosting)
        var error: String?
        for (index, target) in targets.sorted(by: { $0.key < $1.key }) {
            // Thủ công: gửi lại mỗi lượt để giữ chế độ; Auto: chỉ gửi khi đổi trạng thái.
            if target == nil, let sent = lastSent[index], sent == nil { continue }
            if let e = await helper.setFan(index, rpm: target ?? -1) { error = e } else { lastSent.updateValue(target, forKey: index) }
        }
        lastError = error
        helper.heartbeat()
    }

    private func observeSleep() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.paused = true
                self.lastSent = [:]
                self.helper.resetAllBlocking()
            }
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.paused = false }
        }
    }

    func prepareForQuit() {
        paused = true
        helper.resetAllBlocking()
    }

    // MARK: Mở cùng máy

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                lastError = "Không đổi được Mở cùng máy: \(error.localizedDescription)"
            }
            launchAtLoginChanged.toggle()
        }
    }
    /// SMAppService không observable; đổi biến này để SwiftUI vẽ lại toggle.
    var launchAtLoginChanged = false

    // MARK: Boost

    func boost(minutes: Int) {
        boostUntil = Date().addingTimeInterval(Double(minutes) * 60)
        applySoon()
    }

    func stopBoost() {
        boostUntil = nil
        applySoon()
    }

    // MARK: Preset

    func duplicate(_ preset: FanPreset) {
        var copy = FanPreset(name: "\(preset.name) (tuỳ chỉnh)", rules: preset.rules)
        if copy.rules == [.auto] { copy.rules = FanPreset.balanced.rules }
        presets.append(copy)
        activePresetID = copy.id
        save()
    }

    func update(_ preset: FanPreset) {
        guard !preset.isBuiltIn, let i = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[i] = preset
        save()
        applySoon()
    }

    func delete(_ preset: FanPreset) {
        guard !preset.isBuiltIn else { return }
        presets.removeAll { $0.id == preset.id }
        if activePresetID == preset.id { activePresetID = FanPreset.auto.id }
        save()
    }

    private func save() {
        do {
            try store.save(presets.filter { !$0.isBuiltIn })
        } catch {
            lastError = "Không lưu được preset: \(error.localizedDescription)"
        }
    }
}
