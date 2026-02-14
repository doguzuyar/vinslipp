import SwiftUI

struct MiniCalendar: View {
    let dateColors: [String: String]
    let filteredDateCounts: [String: Int]
    @Binding var selectedDate: String?
    @State private var displayMonth = Date()

    private let calendar = Calendar.current
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: displayMonth)
    }

    private var weeks: [[Date?]] {
        let range = calendar.range(of: .day, in: .month, for: displayMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth))!
        let weekday = calendar.component(.weekday, from: firstDay)
        // Adjust for Monday start (weekday 1 = Sunday → offset 6, Monday → offset 0)
        let offset = (weekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: firstDay))
        }
        // Pad to complete final week
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Month navigation
            HStack {
                Text(monthLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    withAnimation {
                        displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth)!
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.trailing, 12)

                Button {
                    withAnimation {
                        displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth)!
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .offset(y: -20)

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { index in
                        if let date = week[index] {
                            dayCell(for: date)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 28)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 0)
    }

    private var todayString: String {
        dayFormatter.string(from: Date())
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let dateStr = dayFormatter.string(from: date)
        let isSelected = dateStr == selectedDate
        let isToday = dateStr == todayString
        let color = dateColors[dateStr]
        let dayNum = calendar.component(.day, from: date)
        let wineCount = filteredDateCounts[dateStr] ?? 0

        Button {
            if selectedDate == dateStr {
                selectedDate = nil
            } else {
                selectedDate = dateStr
            }
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: color ?? "#ffffff").opacity(0.3))
                }

                VStack(spacing: 1) {
                    Text("\(dayNum)")
                        .font(.system(size: isToday ? 12 : 10, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? .primary : .secondary)

                    if wineCount > 0, let hex = color {
                        let dotSize: CGFloat = wineCount > 10 ? 5 : wineCount > 5 ? 4 : 3
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: dotSize, height: dotSize)
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 3, height: 3)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 28)
    }
}
