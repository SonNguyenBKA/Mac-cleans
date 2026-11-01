import AppKit
import MacCleanerCore
import SwiftUI

struct JunkSectionView: View {
    @Bindable var section: JunkSection
    let item: SidebarItem
    @State private var confirming = false
    @State private var expanded: Set<String> = []

    private var busy: Bool { section.isScanning || section.isCleaning }

    var body: some View {
        VStack(spacing: 0) {
            if section.hasScanned && !busy { results } else { intro }
            bottomButton.padding(.vertical, 24)
        }
        .padding(.horizontal, 32)
        .confirmationDialog("Dọn \(section.selectedCount) mục (\(ByteFormat.string(section.selectedSize)))?",
                            isPresented: $confirming) {
            Button("Chuyển vào Thùng rác") { Task { await section.clean() } }
            Button("Xoá vĩnh viễn", role: .destructive) { Task { await section.clean(permanently: true) } }
        } message: {
            Text(CleanConfirmText.message(includesTrash: section.selectsPermanentDelete))
        }
    }

    private var intro: some View {
        VStack(spacing: 0) {
            Spacer()
            HeroView(item: item, showFeatures: !busy)
            if busy {
                Text(section.isCleaning ? "Đang dọn…"
                     : section.scannedFiles > 0 ? "Đã quét \(section.scannedFiles) file…" : "Đang quét…")
                    .font(.title3)
                    .monospacedDigit()
                    .opacity(0.8)
                    .padding(.top, 16)
            }
            if section.rootKey != nil {
                ChipButton(title: section.root?.path ?? "Chọn thư mục", symbol: "folder") { section.chooseRoot() }
                    .frame(maxWidth: 360)
                    .disabled(busy)
                    .padding(.top, 20)
            }
            Spacer()
        }
    }

    private var results: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(ByteFormat.string(section.totalSize))
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                Text("tìm thấy · đã chọn \(ByteFormat.string(section.selectedSize))").opacity(0.7)
                if let message = section.message {
                    Label(message, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .lineLimit(2)
                        .padding(.top, 4)
                }
            }
            .padding(.top, 40)
            HStack {
                if section.rootKey != nil {
                    ChipButton(title: section.root?.path ?? "Chọn thư mục", symbol: "folder") { section.chooseRoot() }
                        .frame(maxWidth: 360, alignment: .leading)
                }
                Spacer()
                ChipButton(title: "Quét lại", symbol: "arrow.clockwise") { Task { await section.scan() } }
            }
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(section.groups) { group in
                        GroupCard(section: section, group: group, item: item,
                                  expanded: Binding(get: { expanded.contains(group.id) },
                                                    set: { if $0 { expanded.insert(group.id) } else { expanded.remove(group.id) } }))
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.never)
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        if section.isScanning {
            RoundActionButton(title: "Dừng", item: item, busy: true) { section.cancelScan() }
        } else if section.isCleaning {
            RoundActionButton(title: "Đang dọn", item: item, busy: true) {}
        } else if section.hasScanned {
            RoundActionButton(title: "Dọn", item: item, disabled: section.selectedCount == 0) { confirming = true }
        } else {
            RoundActionButton(title: "Quét", item: item) { Task { await section.scan() } }
        }
    }
}

private struct GroupCard: View {
    @Bindable var section: JunkSection
    let group: JunkGroup
    let item: SidebarItem
    @Binding var expanded: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Toggle("", isOn: Binding(get: { section.isSelected(group) }, set: { section.setSelected(group, $0) }))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .disabled(group.items.isEmpty)
                    IconTile(symbol: group.icon, item: item, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(group.title).fontWeight(.semibold)
                            if group.mode == .deletePermanently {
                                Text("xoá vĩnh viễn")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.red.opacity(0.35), in: Capsule())
                            }
                        }
                        Text("\(group.items.count) mục").font(.caption).opacity(0.6)
                    }
                    Spacer()
                    Text(ByteFormat.string(group.totalSize)).font(.title3.weight(.semibold)).monospacedDigit()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(group.items.isEmpty && group.note == nil)
                }
                if let note = group.note {
                    HStack {
                        Label(note, systemImage: "lock.trianglebadge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Button("Mở cài đặt") {
                            NSWorkspace.shared.open(Permissions.fullDiskAccessSettingsURL)
                        }
                        .controlSize(.small)
                    }
                }
                if expanded {
                    Divider().overlay(.white.opacity(0.1))
                    ForEach(group.items) { item in
                        ItemRow(section: section, item: item)
                    }
                }
            }
        }
    }
}

private struct ItemRow: View {
    @Bindable var section: JunkSection
    let item: CleanItem

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(get: { section.selected.contains(item.url) },
                                     set: { if $0 { section.selected.insert(item.url) } else { section.selected.remove(item.url) } }))
                .toggleStyle(.checkbox)
                .labelsHidden()
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).lineLimit(1)
                if let detail = item.detail {
                    Text(detail).font(.caption).opacity(0.55).lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer()
            Text(ByteFormat.string(item.size)).monospacedDigit().opacity(0.75)
        }
        .padding(.leading, 28)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Hiện trong Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
        }
    }
}
