import SwiftUI

struct BottleChart: View {
    let yearCounts: [String: Int]
    let colorPalette: [String: String]
    @Binding var selectedYear: String?
    var vertical = false

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
        if vertical {
            verticalChart
        } else {
            horizontalChart
        }
    }

    // MARK: - Horizontal (iPhone)

    private var horizontalChart: some View {
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

    // MARK: - Vertical (iPad)

    private var verticalChart: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(sortedYears, id: \.year) { entry in
                    Button {
                        selectedYear = selectedYear == entry.year ? nil : entry.year
                    } label: {
                        HStack(spacing: 8) {
                            Text(entry.year)
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                                .foregroundStyle(selectedYear == entry.year ? .primary : .secondary)
                                .frame(width: 36, alignment: .trailing)

                            GeometryReader { geo in
                                let barWidth = max(6, geo.size.width * CGFloat(entry.count) / CGFloat(maxCount))
                                HStack {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: colorPalette[entry.year] ?? "#888888"))
                                        .frame(width: barWidth)
                                        .opacity(selectedYear == nil || selectedYear == entry.year ? 1 : 0.3)
                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(height: 20)

                            Text("\(entry.count)")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .frame(width: 20, alignment: .leading)
                        }
                    }
                    .opacity(selectedYear == nil || selectedYear == entry.year ? 1 : 0.5)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
