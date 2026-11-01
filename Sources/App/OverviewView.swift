import MacCleanerCore
import SwiftUI

struct OverviewView: View {
    let model: AppModel
    @Binding var selection: SidebarItem
    @State private var confirming = false

    private var scanning: Bool { model.junkSections.contains(where: \.isScanning) }
    private var cleaning: Bool { model.junkSections.contains(where: \.isCleaning) }
    private var hasScanned: Bool { model.junkSections.contains(where: \.hasScanned) }
    private var total: Int64 { model.junkSections.reduce(0) { $0 + $1.totalSize } }
    private var selectedSize: Int64 { model.junkSections.reduce(0) { $0 + $1.selectedSize } }
    private var tiles: [(JunkSection, SidebarItem)] {
        [(model.system, .system), (model.dev, .dev), (model.largeFiles, .largeFiles)]
    }

    var body: some View {
        VStack(spacing: 0) {
            if hasScanned && !scanning && !cleaning { results } else { intro }
            bottomButton.padding(.vertical, 24)
        }
        .padding(.horizontal, 32)
        .confirmationDialog("Dọn \(ByteFormat.string(selectedSize)) đã chọn?", isPresented: $confirming) {
            Button("Chuyển vào Thùng rác") { cleanAll(permanently: false) }
            Button("Xoá vĩnh viễn", role: .destructive) { cleanAll(permanently: true) }
        } message: {
            Text(CleanConfirmText.message(includesTrash: model.junkSections.contains(where: \.selectsPermanentDelete)))
        }
    }

    private var intro: some View {
        VStack(spacing: 0) {
            Spacer()
            HeroView(item: .overview, showFeatures: !scanning && !cleaning)
            if scanning || cleaning {
                tileRow.padding(.top, 28)
            }
            Spacer()
        }
    }

    private var results: some View {
        VStack(spacing: 18) {
            Spacer()
            Text(ByteFormat.string(total)).font(.system(size: 64, weight: .bold, design: .rounded))
            Text("rác tìm thấy · đã chọn \(ByteFormat.string(selectedSize)) để dọn").font(.title3).opacity(0.7)
            tileRow.padding(.top, 10)
            if let hot = model.processes.hot.first {
                Button {
                    selection = .processes
                } label: {
                    Label("\(hot.row.name) đang ăn \(Int(hot.row.cpu))% CPU — xem", systemImage: "flame.fill")
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.red.opacity(0.35), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            ChipButton(title: "Quét lại", symbol: "arrow.clockwise") { Task { await model.smartScan() } }
            Spacer()
        }
    }

    private var tileRow: some View {
        HStack(spacing: 16) {
            ForEach(tiles, id: \.1) { section, item in
                Button {
                    selection = item
                } label: {
                    GlassCard {
                        VStack(spacing: 10) {
                            IconTile(symbol: item.icon, item: item, size: 44)
                            Text(item.title).font(.headline)
                            if section.isScanning || section.isCleaning {
                                ProgressView().controlSize(.small)
                            } else {
                                Text(section.hasScanned ? ByteFormat.string(section.totalSize) : "—")
                                    .font(.title2.weight(.semibold))
                                    .monospacedDigit()
                            }
                            Text(section.hasScanned ? "đã chọn \(ByteFormat.string(section.selectedSize))" : " ")
                                .font(.caption)
                                .opacity(0.6)
                        }
                        .frame(width: 170, height: 150)
                    }
                }
                .buttonStyle(PressScaleStyle())
            }
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        if scanning {
            RoundActionButton(title: "Dừng", item: .overview, busy: true) { model.cancelAll() }
        } else if cleaning {
            RoundActionButton(title: "Đang dọn", item: .overview, busy: true) {}
        } else if hasScanned {
            RoundActionButton(title: "Dọn", item: .overview, disabled: selectedSize == 0) { confirming = true }
        } else {
            RoundActionButton(title: "Quét", item: .overview) { Task { await model.smartScan() } }
        }
    }

    private func cleanAll(permanently: Bool) {
        Task {
            for section in model.junkSections where section.selectedCount > 0 {
                await section.clean(permanently: permanently)
            }
        }
    }
}
