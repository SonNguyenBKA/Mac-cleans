import Charts
import MacCleanerCore
import SwiftUI

struct FanView: View {
    @Bindable var model: FanModel
    @State private var renaming: FanPreset?
    @State private var newName = ""
    @State private var showAllSensors = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                banners
                fanCards
                presetBar
                ruleEditor
                charts
                sensorList
            }
            .padding(.horizontal, 32)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.never)
        .alert("Đổi tên preset", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Tên", text: $newName)
            Button("Lưu") {
                if var p = renaming, !newName.isEmpty { p.name = newName; model.update(p) }
            }
            Button("Huỷ", role: .cancel) {}
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            IconTile(symbol: SidebarItem.fans.icon, item: .fans, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text("Quạt & nhiệt độ").font(.system(size: 28, weight: .bold))
                Text("CPU \(temp(model.cpuTemp)) · GPU \(temp(model.gpuTemp)) · preset \(model.activePreset.name)")
                    .opacity(0.7)
            }
            Spacer()
            Toggle("Mở cùng máy", isOn: Binding(get: { _ = model.launchAtLoginChanged; return model.launchAtLogin },
                                                 set: { model.launchAtLogin = $0 }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("Tự mở Mac Cleaner khi đăng nhập để áp preset quạt")
            if let until = model.boostUntil, model.isBoosting {
                Button {
                    model.stopBoost()
                } label: {
                    Label { Text(timerInterval: Date()...until, countsDown: true).monospacedDigit() } icon: { Image(systemName: "wind") }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .help("Đang Boost — bấm để dừng")
            } else {
                Menu {
                    ForEach([5, 10, 15], id: \.self) { m in Button("\(m) phút") { model.boost(minutes: m) } }
                } label: {
                    Label("Boost", systemImage: "wind")
                }
                .fixedSize()
                .disabled(model.helper.state != .ready)
            }
        }
    }

    // MARK: Cảnh báo

    @ViewBuilder
    private var banners: some View {
        switch model.helper.state {
        case .ready: EmptyView()
        case .notInstalled:
            banner("Cần cài helper để điều khiển quạt",
                   "Ghi tốc độ quạt cần quyền root. Helper chỉ nhận lệnh từ Mac Cleaner và tự trả quạt về Auto khi app thoát.",
                   "Cài helper") { model.helper.install() }
        case .needsApproval:
            banner("Bật helper trong Login Items",
                   "Mở System Settings › General › Login Items và bật Mac Cleaner ở mục Allow in the Background.",
                   "Mở cài đặt") { model.helper.install() }
        case .failed(let error):
            banner("Không cài được helper", error, "Thử lại") { model.helper.install() }
        }
        if model.otherControllerRunning {
            Label("Macs Fan Control đang chạy — hai app sẽ giành quyền điều khiển quạt. Hãy thoát Macs Fan Control.",
                  systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        if let error = model.lastError ?? model.monitorError {
            Label(error, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }

    private func banner(_ title: String, _ detail: String, _ action: String, _ run: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield.fill").font(.system(size: 28)).foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.semibold)
                Text(detail).font(.caption).opacity(0.75)
            }
            Spacer()
            Button(action, action: run).buttonStyle(.borderedProminent).tint(.cyan)
        }
        .padding(14)
        .background(.cyan.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Quạt

    private var fanCards: some View {
        HStack(spacing: 14) {
            ForEach(model.fans) { fan in
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "fan.fill")
                                .rotationEffect(.degrees(fan.actual > 0 ? 360 : 0))
                                .animation(fan.actual > 0 ? .linear(duration: max(0.3, 3000 / fan.actual)).repeatForever(autoreverses: false) : .default,
                                           value: fan.actual > 0)
                            Text(model.fans.count == 2 ? (fan.id == 0 ? "Quạt trái" : "Quạt phải") : "Quạt \(fan.id + 1)")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(fan.isManual ? "Thủ công" : "Auto")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background((fan.isManual ? Color.cyan : .white).opacity(0.2), in: Capsule())
                        }
                        Text("\(Int(fan.actual)) RPM").font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
                        GeometryReader { geo in
                            let fraction = (fan.actual - fan.min) / max(1, fan.max - fan.min)
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.15))
                                Capsule().fill(SidebarItem.fans.gradient).frame(width: geo.size.width * min(1, max(0.02, fraction)))
                            }
                        }
                        .frame(height: 6)
                        Text("\(Int(fan.min)) – \(Int(fan.max)) RPM").font(.caption).opacity(0.6)
                    }
                }
            }
        }
    }

    // MARK: Preset

    private var presetBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(model.presets) { preset in
                    Button {
                        model.activePresetID = preset.id
                    } label: {
                        Text(preset.name)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(preset.id == model.activePresetID ? AnyShapeStyle(SidebarItem.fans.gradient)
                                                                           : AnyShapeStyle(.white.opacity(0.12)),
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Nhân bản") { model.duplicate(preset) }
                        if !preset.isBuiltIn {
                            Button("Đổi tên…") { newName = preset.name; renaming = preset }
                            Button("Xoá", role: .destructive) { model.delete(preset) }
                        }
                    }
                }
                Button {
                    model.duplicate(model.activePreset)
                } label: {
                    Image(systemName: "plus").padding(8).background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Tạo preset mới từ preset đang chọn")
            }
        }
        .scrollIndicators(.never)
    }

    // MARK: Rule

    @ViewBuilder
    private var ruleEditor: some View {
        let preset = model.activePreset
        GlassCard {
            if preset.isBuiltIn {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preset.name).font(.headline)
                        Text(describe(preset)).font(.callout).opacity(0.75)
                    }
                    Spacer()
                    Button("Nhân bản để tuỳ chỉnh") { model.duplicate(preset) }
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(model.fans) { fan in
                        RuleRow(fan: fan, fanCount: model.fans.count, sensors: model.sensors,
                                rule: Binding(get: { model.activePreset.rule(for: fan.id) },
                                              set: { setRule($0, fan: fan.id) }))
                        if fan.id != model.fans.last?.id { Divider().overlay(.white.opacity(0.1)) }
                    }
                }
            }
        }
    }

    private func setRule(_ rule: FanRule, fan: Int) {
        var p = model.activePreset
        while p.rules.count < model.fans.count { p.rules.append(p.rules.last ?? .auto) }
        p.rules[fan] = rule
        model.update(p)
    }

    private func describe(_ p: FanPreset) -> String {
        switch p.id {
        case FanPreset.auto.id: "macOS tự điều khiển quạt như bình thường."
        case FanPreset.quiet.id: "Để macOS tự quyết tới 70°C, sau đó tăng dần: 85°C → 40%, 95°C → tối đa."
        case FanPreset.balanced.id: "Từ 55°C tăng dần: 70°C → 40%, 85°C → tối đa. Máy mát hơn khi build/chạy nặng."
        case FanPreset.maxCooling.id: "Mọi quạt chạy tối đa liên tục."
        default: ""
        }
    }

    // MARK: Biểu đồ

    private var charts: some View {
        HStack(spacing: 14) {
            GlassCard {
                VStack(alignment: .leading) {
                    Text("Nhiệt độ 10 phút").font(.headline)
                    Chart(model.history.samples) { s in
                        LineMark(x: .value("t", s.date), y: .value("°C", s.cpu), series: .value("", "CPU"))
                            .foregroundStyle(by: .value("", "CPU"))
                        LineMark(x: .value("t", s.date), y: .value("°C", s.gpu), series: .value("", "GPU"))
                            .foregroundStyle(by: .value("", "GPU"))
                    }
                    .chartForegroundStyleScale(["CPU": Color.orange, "GPU": Color.pink])
                    .chartXAxis(.hidden)
                    .frame(height: 140)
                }
            }
            GlassCard {
                VStack(alignment: .leading) {
                    Text("Tốc độ quạt").font(.headline)
                    Chart(model.history.samples) { s in
                        ForEach(Array(s.fanRPM.enumerated()), id: \.offset) { i, rpm in
                            LineMark(x: .value("t", s.date), y: .value("RPM", rpm), series: .value("", "Quạt \(i + 1)"))
                                .foregroundStyle(by: .value("", "Quạt \(i + 1)"))
                        }
                    }
                    .chartForegroundStyleScale(["Quạt 1": Color.cyan, "Quạt 2": Color.blue])
                    .chartXAxis(.hidden)
                    .frame(height: 140)
                }
            }
        }
    }

    // MARK: Cảm biến

    private var sensorList: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Cảm biến (\(model.sensors.count))").font(.headline)
                    Spacer()
                    Toggle("Hiện tất cả", isOn: $showAllSensors).toggleStyle(.switch).controlSize(.small)
                }
                ForEach(SensorGroup.allCases, id: \.self) { group in
                    let items = model.sensors.filter { $0.group == group }
                    if !items.isEmpty && (showAllSensors || group != .other) {
                        DisclosureGroup {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 6) {
                                ForEach(items) { s in
                                    HStack {
                                        Text(s.name).lineLimit(1)
                                        Text(s.key).font(.caption2.monospaced()).opacity(0.45)
                                        Spacer()
                                        Text(temp(s.value)).monospacedDigit().foregroundStyle(color(s.value))
                                    }
                                    .font(.callout)
                                }
                            }
                            .padding(.top, 6)
                        } label: {
                            HStack {
                                Text(group.title).fontWeight(.semibold)
                                Text("\(items.count) cảm biến").font(.caption).opacity(0.55)
                                Spacer()
                                let maxT = items.map(\.value).max() ?? 0
                                Text("cao nhất \(temp(maxT))").monospacedDigit().foregroundStyle(color(maxT))
                            }
                        }
                    }
                }
            }
        }
    }

    private func temp(_ v: Double?) -> String { v.map { String(format: "%.0f°C", $0) } ?? "—" }
    private func color(_ v: Double) -> Color { v >= 90 ? .red : v >= 75 ? .orange : .white }
}

private struct RuleRow: View {
    enum Mode: String, CaseIterable { case auto = "Auto", constant = "Cố định", sensor = "Theo cảm biến", curve = "Đường cong" }

    let fan: FanInfo
    let fanCount: Int
    let sensors: [SensorReading]
    @Binding var rule: FanRule

    private var mode: Mode {
        switch rule {
        case .auto: .auto
        case .constant: .constant
        case .sensor: .sensor
        case .curve: .curve
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(fanCount == 2 ? (fan.id == 0 ? "Quạt trái" : "Quạt phải") : "Quạt \(fan.id + 1)").fontWeight(.semibold)
                Spacer()
                Picker("", selection: Binding(get: { mode }, set: { rule = defaultRule($0) })) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 380)
            }
            switch rule {
            case .auto:
                Text("macOS tự điều khiển quạt này.").font(.callout).opacity(0.7)
            case .constant(let percent):
                HStack {
                    Slider(value: Binding(get: { percent }, set: { rule = .constant(percent: $0.rounded()) }), in: 0...100)
                    Text("\(Int(fan.rpm(percent: percent))) RPM").monospacedDigit().frame(width: 90, alignment: .trailing)
                }
            case .sensor(let source, let start, let max):
                VStack(alignment: .leading, spacing: 6) {
                    sourcePicker(source) { rule = .sensor(source: $0, start: start, max: max) }
                    HStack {
                        Text("Bắt đầu tăng từ").frame(width: 120, alignment: .leading)
                        Slider(value: Binding(get: { start }, set: { rule = .sensor(source: source, start: $0.rounded(), max: Swift.max(max, $0.rounded() + 5)) }), in: 30...100)
                        Text("\(Int(start))°C").monospacedDigit().frame(width: 50)
                    }
                    HStack {
                        Text("Tối đa ở").frame(width: 120, alignment: .leading)
                        Slider(value: Binding(get: { max }, set: { rule = .sensor(source: source, start: start, max: Swift.max(start + 5, $0.rounded())) }), in: 35...105)
                        Text("\(Int(max))°C").monospacedDigit().frame(width: 50)
                    }
                }
            case .curve(let source, let points):
                VStack(alignment: .leading, spacing: 6) {
                    sourcePicker(source) { rule = .curve(source: $0, points: points) }
                    CurveEditor(points: Binding(get: { points }, set: { rule = .curve(source: source, points: $0) }),
                                currentTemp: source.temperature(in: sensors), fan: fan)
                }
            }
        }
    }

    private func sourcePicker(_ source: TempSource, set: @escaping (TempSource) -> Void) -> some View {
        Picker("Theo nhiệt độ", selection: Binding(get: { source }, set: set)) {
            Text("CPU/GPU nóng nhất").tag(TempSource.hottest)
            ForEach([SensorGroup.cpu, .gpu, .memory, .ssd, .battery], id: \.self) { g in
                Text("\(g.title) nóng nhất").tag(TempSource.group(g))
            }
            Divider()
            ForEach(sensors.filter { $0.group == .cpu || $0.group == .gpu }) { s in
                Text("\(s.name) (\(s.key))").tag(TempSource.sensor(s.key))
            }
        }
        .frame(maxWidth: 360)
    }

    private func defaultRule(_ mode: Mode) -> FanRule {
        switch mode {
        case .auto: .auto
        case .constant: .constant(percent: 50)
        case .sensor: .sensor(source: .hottest, start: 55, max: 85)
        case .curve: FanPreset.balanced.rules[0]
        }
    }
}
