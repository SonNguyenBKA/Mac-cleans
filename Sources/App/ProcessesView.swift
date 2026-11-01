import AppKit
import MacCleanerCore
import SwiftUI

struct ProcessesView: View {
    @Bindable var model: ProcessesModel
    @State private var pendingKill: (row: ProcessRow, force: Bool)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                IconTile(symbol: SidebarItem.processes.icon, item: .processes, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tiến trình").font(.system(size: 28, weight: .bold))
                    Text("Cảnh báo khi \(model.thresholdText)").opacity(0.7)
                }
                Spacer()
            }

            Text("Đang chạy nặng").font(.headline)
                + Text("  CPU ≥ 25% hoặc RAM ≥ 1 GB").font(.caption).foregroundColor(.white.opacity(0.6))
            GlassCard(padding: 6) {
                if model.heavyRows.isEmpty {
                    Label("Không có tiến trình nào đang chạy nặng", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(model.heavyRows) { row in
                            HeavyRow(row: row, hotSince: model.hotSince(row)) { pendingKill = (row, $0) }
                            if row.id != model.heavyRows.last?.id { Divider().overlay(.white.opacity(0.08)) }
                        }
                    }
                }
            }

            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }

            HStack {
                Text("Tất cả tiến trình").font(.headline)
                Spacer()
                Picker("", selection: $model.sortKey) {
                    ForEach(ProcessesModel.SortKey.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 140)
            }
            GlassCard(padding: 0) {
                Table(model.sortedRows) {
                    TableColumn("Tiến trình") { row in Text(row.name).help(row.path) }
                    TableColumn("PID") { Text(String($0.pid)).monospacedDigit() }.width(60)
                    TableColumn("CPU %") { Text(String(format: "%.1f", $0.cpu)).monospacedDigit() }.width(60)
                    TableColumn("RAM") { Text(ByteFormat.string($0.memoryBytes)).monospacedDigit() }.width(80)
                    TableColumn("") { row in
                        if row.canKill {
                            HStack {
                                Button("Kết thúc") { pendingKill = (row, false) }
                                Button("Buộc dừng") { pendingKill = (row, true) }
                            }
                            .controlSize(.small)
                        }
                    }
                    .width(170)
                }
                .scrollContentBackground(.hidden)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 40)
        .padding(.bottom, 24)
        .confirmationDialog(pendingKill.map { "\($0.force ? "Buộc dừng" : "Kết thúc") \($0.row.name) (PID \($0.row.pid))?" } ?? "",
                            isPresented: Binding(get: { pendingKill != nil }, set: { if !$0 { pendingKill = nil } })) {
            Button(pendingKill?.force == true ? "Buộc dừng" : "Kết thúc", role: .destructive) {
                if let p = pendingKill { model.terminate(p.row, force: p.force) }
            }
        } message: {
            Text(pendingKill?.force == true
                 ? "Dừng ngay lập tức, dữ liệu chưa lưu sẽ mất. Chỉ dùng khi Kết thúc không có tác dụng."
                 : "Gửi yêu cầu thoát cho tiến trình. Dữ liệu chưa lưu có thể bị mất.")
        }
    }
}

private struct HeavyRow: View {
    let row: ProcessRow
    let hotSince: Date?
    let onKill: (_ force: Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: row.appBundlePath ?? row.path))
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name).fontWeight(.semibold).lineLimit(1)
                HStack(spacing: 6) {
                    if let app = row.appName, app != row.name { Text("thuộc \(app) ·") }
                    if let explanation = row.explanation { Text("\(explanation) ·") }
                    Text("PID \(row.pid)")
                    if let hotSince {
                        Label("liên tục \(ProcessesModel.duration(Date().timeIntervalSince(hotSince)))", systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
            }
            .help(row.path)
            Spacer()
            Chip(text: "CPU \(Int(row.cpu.rounded()))%",
                 color: row.cpu >= 80 ? .red : row.cpu >= 25 ? .orange : .white.opacity(0.15))
            Chip(text: ByteFormat.string(row.memoryBytes),
                 color: row.memoryBytes >= 1_000_000_000 ? .orange : .white.opacity(0.15))
            if row.canKill {
                Button("Kết thúc") { onKill(false) }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                Button("Buộc dừng") { onKill(true) }
            } else {
                Text("Tiến trình hệ thống")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 170, alignment: .trailing)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}

private struct Chip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.85), in: Capsule())
    }
}
