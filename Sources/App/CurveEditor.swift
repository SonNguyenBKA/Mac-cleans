import Charts
import MacCleanerCore
import SwiftUI

/// Đường cong nhiệt độ → % tốc độ quạt, kéo thả từng điểm.
struct CurveEditor: View {
    @Binding var points: [CurvePoint]
    let currentTemp: Double?
    let fan: FanInfo?
    @State private var dragging: Int?

    static let tempRange = 30.0...105.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                    LineMark(x: .value("°C", p.temp), y: .value("%", p.percent))
                        .interpolationMethod(.linear)
                        .foregroundStyle(.cyan)
                    PointMark(x: .value("°C", p.temp), y: .value("%", p.percent))
                        .symbolSize(140)
                        .foregroundStyle(.white)
                }
                if let currentTemp {
                    RuleMark(x: .value("Hiện tại", currentTemp))
                        .foregroundStyle(.orange.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("\(Int(currentTemp))°").font(.caption2.bold()).foregroundStyle(.orange)
                        }
                }
            }
            .chartXScale(domain: Self.tempRange)
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: 10)) { value in
                    AxisGridLine()
                    AxisValueLabel { if let v = value.as(Double.self) { Text("\(Int(v))°") } }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel { if let v = value.as(Double.self) { Text(yLabel(v)) } }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { drag(proxy: proxy, geo: geo, location: $0.location) }
                            .onEnded { _ in
                                dragging = nil
                                points.sort { $0.temp < $1.temp }
                            })
                }
            }
            .frame(height: 220)

            HStack {
                Text("Dưới điểm đầu tiên: để macOS tự điều khiển. Kéo các điểm để chỉnh.")
                    .font(.caption).opacity(0.6)
                Spacer()
                Button {
                    addPoint()
                } label: { Label("Thêm điểm", systemImage: "plus") }
                    .disabled(points.count >= 8)
                Button {
                    points.removeLast()
                } label: { Label("Bớt điểm", systemImage: "minus") }
                    .disabled(points.count <= 2)
            }
            .controlSize(.small)
        }
    }

    private func yLabel(_ percent: Double) -> String {
        guard let fan else { return "\(Int(percent))%" }
        return "\(Int(fan.rpm(percent: percent)))"
    }

    private func drag(proxy: ChartProxy, geo: GeometryProxy, location: CGPoint) {
        guard let frame = proxy.plotFrame.map({ geo[$0] }) else { return }
        let local = CGPoint(x: location.x - frame.minX, y: location.y - frame.minY)
        if dragging == nil {
            // chọn điểm gần nhất trong bán kính 24pt
            dragging = points.indices.min { a, b in distance(proxy, points[a], local) < distance(proxy, points[b], local) }
                .flatMap { distance(proxy, points[$0], local) < 24 ? $0 : nil }
        }
        guard let i = dragging, let temp: Double = proxy.value(atX: local.x), let percent: Double = proxy.value(atY: local.y) else { return }
        points[i] = CurvePoint(temp: min(Self.tempRange.upperBound, max(Self.tempRange.lowerBound, temp.rounded())),
                               percent: min(100, max(0, percent.rounded())))
    }

    private func distance(_ proxy: ChartProxy, _ p: CurvePoint, _ location: CGPoint) -> CGFloat {
        guard let x = proxy.position(forX: p.temp), let y = proxy.position(forY: p.percent) else { return .infinity }
        return hypot(x - location.x, y - location.y)
    }

    private func addPoint() {
        let sorted = points.sorted { $0.temp < $1.temp }
        // chèn vào giữa khoảng rộng nhất
        let gap = zip(sorted, sorted.dropFirst()).max { ($0.1.temp - $0.0.temp) < ($1.1.temp - $1.0.temp) }
        let p = gap.map { CurvePoint(temp: (($0.0.temp + $0.1.temp) / 2).rounded(), percent: (($0.0.percent + $0.1.percent) / 2).rounded()) }
            ?? CurvePoint(temp: 70, percent: 50)
        points = (sorted + [p]).sorted { $0.temp < $1.temp }
    }
}
