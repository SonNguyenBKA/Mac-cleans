import MacCleanerCore
import SwiftUI

struct MenuBarLabel: View {
    let model: FanModel

    var body: some View {
        let rpm = model.fans.map(\.actual).max().map { " · \(Int($0))" } ?? ""
        Label {
            Text(model.cpuTemp.map { "\(Int($0))°\(rpm)" } ?? "—")
        } icon: {
            Image(systemName: model.isBoosting ? "wind" : "fan.fill")
        }
        .labelStyle(.titleAndIcon)
    }
}

struct MenuBarContent: View {
    @Bindable var model: FanModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("CPU \(temp(model.cpuTemp)) · GPU \(temp(model.gpuTemp))")
        ForEach(model.fans) { fan in
            Text("\(model.fans.count == 2 ? (fan.id == 0 ? "Quạt trái" : "Quạt phải") : "Quạt \(fan.id + 1)"): \(Int(fan.actual)) RPM\(fan.isManual ? "" : " (Auto)")")
        }
        Divider()
        Picker("Preset", selection: $model.activePresetID) {
            ForEach(model.presets) { Text($0.name).tag($0.id) }
        }
        .pickerStyle(.inline)
        .disabled(model.helper.state != .ready)
        Divider()
        if model.isBoosting {
            Button("Dừng Boost") { model.stopBoost() }
        } else {
            Menu("Boost") {
                ForEach([5, 10, 15], id: \.self) { m in Button("\(m) phút") { model.boost(minutes: m) } }
            }
            .disabled(model.helper.state != .ready)
        }
        Divider()
        Button("Mở Mac Cleaner") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Thoát (trả quạt về Auto)") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func temp(_ v: Double?) -> String { v.map { "\(Int($0))°C" } ?? "—" }
}
