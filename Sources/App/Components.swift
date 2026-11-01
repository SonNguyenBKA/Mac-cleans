import SwiftUI

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.12)))
    }
}

/// Ô icon bo góc tô gradient.
struct IconTile: View {
    let symbol: String
    let item: SidebarItem
    var size: CGFloat = 26

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(item.gradient, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

/// Nút tròn lớn ở giữa dưới màn hình. `busy`: vòng sáng quay quanh nút.
struct RoundActionButton: View {
    let title: String
    let item: SidebarItem
    var busy = false
    var disabled = false
    let action: () -> Void

    @State private var spin = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(.white.opacity(0.18), lineWidth: 5).frame(width: 112, height: 112)
                if busy {
                    Circle()
                        .trim(from: 0, to: 0.28)
                        .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 112, height: 112)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .onAppear {
                            spin = false
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { spin = true }
                        }
                }
                Circle()
                    .fill(item.gradient)
                    .frame(width: 92, height: 92)
                    .shadow(color: item.colors[0].opacity(0.7), radius: 18)
                Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
            }
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Icon lớn + tiêu đề + mô tả + danh sách tính năng, dùng cho màn hình chưa quét.
struct HeroView: View {
    let item: SidebarItem
    var showFeatures = true

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: item.icon)
                .font(.system(size: 96, weight: .light))
                .foregroundStyle(item.gradient)
                .shadow(color: item.colors[0].opacity(0.6), radius: 30)
                .padding(.bottom, 6)
            Text(item.title).font(.system(size: 34, weight: .bold))
            Text(item.subtitle).font(.title3).foregroundStyle(.white.opacity(0.7))
            if showFeatures {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(item.features, id: \.self) { f in
                        Label {
                            Text(f)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(item.gradient)
                        }
                    }
                }
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 8)
            }
        }
        .multilineTextAlignment(.center)
    }
}

/// Nút dạng "chip" kính mờ (chọn thư mục, quét lại…).
struct ChipButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
