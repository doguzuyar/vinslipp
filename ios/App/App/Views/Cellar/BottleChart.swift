import SwiftUI

struct BottleChart: View {
    let yearCounts: [String: Int]
    let colorPalette: [String: String]
    @Binding var selectedYear: String?

    private var sortedYears: [(year: String, count: Int)] {
        yearCounts
            .filter { $0.key.range(of: #"^\d{4}$"#, options: .regularExpression) != nil }
            .sorted { $0.key < $1.key }
            .map { (year: $0.key, count: $0.value) }
    }

    private var maxCount: Int {
        sortedYears.map(\.count).max() ?? 1
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(sortedYears, id: \.year) { entry in
                    Button {
                        selectedYear = selectedYear == entry.year ? nil : entry.year
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(entry.count)")
                                .font(.system(size: 9, weight: .medium).monospacedDigit())
                                .foregroundStyle(.tertiary)

                            GeometryReader { geo in
                                let barHeight = max(6, geo.size.height * CGFloat(entry.count) / CGFloat(maxCount))
                                VStack {
                                    Spacer(minLength: 0)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: colorPalette[entry.year] ?? "#888888"))
                                        .frame(height: barHeight)
                                        .opacity(selectedYear == nil || selectedYear == entry.year ? 1 : 0.3)
                                }
                            }
                            .frame(height: 100)

                            Text(entry.year.suffix(2))
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 32)
                    }
                    .opacity(selectedYear == nil || selectedYear == entry.year ? 1 : 0.5)
                }
            }
        }
        .contentMargins(.horizontal, 8)
    }
}
