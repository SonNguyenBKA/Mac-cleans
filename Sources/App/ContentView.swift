import AppKit
import MacCleanerCore
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case overview, system, dev, largeFiles, processes, fans

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Tổng quan"
        case .system: "Rác hệ thống"
        case .dev: "Rác dev"
        case .largeFiles: "File lớn & cũ"
        case .processes: "Tiến trình"
        case .fans: "Quạt & nhiệt độ"
        }
    }

    var icon: String {
        switch self {
        case .overview: "sparkles"
        case .system: "trash"
        case .dev: "hammer"
        case .largeFiles: "doc.badge.ellipsis"
        case .processes: "cpu"
        case .fans: "fan"
        }
    }
}

struct ContentView: View {
    let model: AppModel
    @State private var selection: SidebarItem = .overview
    @State private var hasFullDiskAccess = Permissions.hasFullDiskAccess

    var body: some View {
        ZStack {
            ThemeBackground(item: selection)
                .animation(.easeInOut(duration: 0.4), value: selection)
            HStack(spacing: 0) {
                Sidebar(selection: $selection)
                    .frame(width: 230)
                    .background(.black.opacity(0.2))
                VStack(spacing: 0) {
                    if !hasFullDiskAccess && selection != .processes && selection != .fans {
                        PermissionBanner().padding(.horizontal, 32).padding(.top, 36)
                    }
                    switch selection {
                    case .overview: OverviewView(model: model, selection: $selection)
                    case .system: JunkSectionView(section: model.system, item: .system)
                    case .dev: JunkSectionView(section: model.dev, item: .dev)
                    case .largeFiles: JunkSectionView(section: model.largeFiles, item: .largeFiles)
                    case .processes: ProcessesView(model: model.processes)
                    case .fans: FanView(model: model.fans)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .task { await model.processes.monitor() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasFullDiskAccess = Permissions.hasFullDiskAccess
        }
    }
}

private struct Sidebar: View {
    @Binding var selection: SidebarItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Mac Cleaner", systemImage: "sparkles")
                .font(.headline)
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
            ForEach(SidebarItem.allCases) { item in
                Button {
                    selection = item
                } label: {
                    HStack(spacing: 10) {
                        IconTile(symbol: item.icon, item: item)
                        Text(item.title)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(selection == item ? .white.opacity(0.16) : .clear,
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            DiskSpaceBar()
        }
        .padding(.horizontal, 12)
        .padding(.top, 46)
        .padding(.bottom, 14)
    }
}
