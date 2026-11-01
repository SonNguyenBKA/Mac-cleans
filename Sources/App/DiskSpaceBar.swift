import MacCleanerCore
import SwiftUI

/// Thẻ dung lượng ổ đĩa ở cuối sidebar, cập nhật mỗi 5 giây.
struct DiskSpaceBar: View {
    @State private var space: DiskSpace?

    var body: some View {
        GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "internaldrive.fill")
                    Text("Macintosh HD").fontWeight(.semibold)
                    Spacer()
                    if let space { Text("\(Int((space.usedFraction * 100).rounded()))%").monospacedDigit().opacity(0.7) }
                }
                .font(.caption)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.15))
                        Capsule().fill(tint).frame(width: geo.size.width * (space?.usedFraction ?? 0))
                    }
                }
                .frame(height: 6)
                Text(space.map { "Còn trống \(ByteFormat.string($0.available)) / \(ByteFormat.string($0.total))" } ?? " ")
                    .font(.caption2)
                    .monospacedDigit()
                    .opacity(0.7)
            }
        }
        .task {
            while !Task.isCancelled {
                withAnimation { space = DiskSpace.current() }
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private var tint: LinearGradient {
        let free = 1 - (space?.usedFraction ?? 0)
        let colors: [Color] = free < 0.1 ? [.red, .pink] : free < 0.2 ? [.orange, .red] : [.cyan, .blue]
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
}
