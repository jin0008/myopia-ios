import SwiftUI
import Charts

struct AxialLengthChartView: View {
    let samples: [AxialLengthSample]

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let eye: String      // "OD" or "OS"
        let hospital: String
    }

    private var points: [Point] {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        var out: [Point] = []
        for s in samples {
            guard let d = fmt.date(from: s.date) else { continue }
            if let od = s.od { out.append(.init(date: d, value: od, eye: "OD", hospital: s.hospitalName)) }
            if let os = s.os { out.append(.init(date: d, value: os, eye: "OS", hospital: s.hospitalName)) }
        }
        return out.sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Axial Length (mm)").font(.headline)
            if points.isEmpty {
                Text("측정 데이터가 없습니다.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart(points) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("mm", p.value)
                    )
                    .foregroundStyle(by: .value("Eye", p.eye))
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("mm", p.value)
                    )
                    .foregroundStyle(by: .value("Eye", p.eye))
                    .symbol(by: .value("Eye", p.eye))
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartLegend(position: .top, alignment: .trailing)
            }
        }
    }
}
