import SwiftUI

struct MiniCalendar: View {
    let dateColors: [String: String]
    let filteredDateCounts: [String: Int]
    @Binding var selectedDate: String?
    var showThreeMonths = false

    private let calendar = Calendar.current
    private static let yearMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()
    private static let fullMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f
    }()

    private var scrollableMonths: [Date] {
        var months: Set<String> = []
        for key in dateColors.keys {
            months.insert(String(key.prefix(7)))
        }
        let today = Date()
        for offset in -1...2 {
            if let d = calendar.date(byAdding: .month, value: offset, to: today) {
                months.insert(Self.yearMonthFormatter.string(from: d))
            }
        }
        return months.sorted().compactMap { Self.yearMonthFormatter.date(from: $0) }
    }

    private var currentMonthID: String {
        Self.yearMonthFormatter.string(from: Date())
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    ForEach(scrollableMonths, id: \.timeIntervalSince1970) { month in
                        let isCurrent = calendar.isDate(month, equalTo: Date(), toGranularity: .month)
                        monthSection(for: month, isCurrent: isCurrent)
                            .id(Self.yearMonthFormatter.string(from: month))
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
            .onAppear {
                proxy.scrollTo(currentMonthID, anchor: .center)
            }
        }
    }

    // MARK: - Month Section

    private func monthSection(for month: Date, isCurrent: Bool) -> some View {
        VStack(spacing: 4) {
            Text(Self.fullMonthFormatter.string(from: month))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isCurrent ? Color.white.opacity(0.7) : Color.white.opacity(0.3))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 2)
                .padding(.bottom, 2)

            weekdayHeader
            monthGrid(for: month)
        }
        .opacity(isCurrent ? 1.0 : 0.6)
    }

    // MARK: - Weekday Header

    private static let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                Text(Self.weekdayLabels[index])
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.2))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Grid

    private func monthGrid(for month: Date) -> some View {
        let weeks = weeksForMonth(month)
        return VStack(spacing: 1) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { index in
                        if let date = week[index] {
                            dayCell(for: date)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 22)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let dateStr = DateFormatters.iso.string(from: date)
        let isSelected = dateStr == selectedDate
        let isToday = dateStr == DateFormatters.todayString
        let wineCount = filteredDateCounts[dateStr] ?? 0
        let hasWines = wineCount > 0
        let dayNum = calendar.component(.day, from: date)

        Button {
            selectedDate = selectedDate == dateStr ? nil : dateStr
        } label: {
            Text("\(dayNum)")
                .font(.system(size: 10, weight: isToday ? .bold : .regular))
                .foregroundColor(
                    isSelected ? .white :
                    isToday ? .white :
                    hasWines ? Color.white.opacity(0.85) :
                    Color.white.opacity(0.2)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .background(
                    isSelected ? Color.white.opacity(0.18) :
                    isToday ? Color.white.opacity(0.06) :
                    Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(alignment: .bottom) {
                    if hasWines {
                        Circle()
                            .fill(Color(hex: dateColors[dateStr] ?? "#888888"))
                            .frame(width: 3, height: 3)
                            .offset(y: -1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func weeksForMonth(_ month: Date) -> [[Date?]] {
        let range = calendar.range(of: .day, in: .month, for: month)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let weekday = calendar.component(.weekday, from: firstDay)
        let offset = (weekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: firstDay))
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }
}
