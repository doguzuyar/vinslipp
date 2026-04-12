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
        verticalChart
    }

    private var verticalChart: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 1) {
                ForEach(sortedYears, id: \.year) { entry in
                    let isSelected = selectedYear == entry.year
                    Button {
                        selectedYear = isSelected ? nil : entry.year
                    } label: {
                        HStack(spacing: 6) {
                            Text(entry.year)
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundColor(isSelected ? .white : Color.white.opacity(0.4))
                                .frame(width: 34, alignment: .trailing)

                            GeometryReader { geo in
                                let barWidth = max(4, geo.size.width * CGFloat(entry.count) / CGFloat(maxCount))
                                HStack {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: colorPalette[entry.year] ?? "#888888"))
                                        .frame(width: barWidth)
                                        .opacity(selectedYear == nil || isSelected ? 0.8 : 0.25)
                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(height: 20)

                            Text("\(entry.count)")
                                .font(.system(size: 9, weight: .medium).monospacedDigit())
                                .foregroundColor(Color.white.opacity(0.3))
                                .frame(width: 16, alignment: .trailing)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 4)
                        .background(isSelected ? Color.white.opacity(0.06) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .opacity(selectedYear == nil || isSelected ? 1 : 0.5)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
