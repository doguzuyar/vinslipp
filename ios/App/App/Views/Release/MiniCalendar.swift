import SwiftUI

struct MiniCalendar: View {
    let dateColors: [String: String]
    let filteredDateCounts: [String: Int]
    @Binding var selectedDate: String?
    var showThreeMonths = false
    @State private var displayMonth = Date()

    private let calendar = Calendar.current
    private static let yearMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    var body: some View {
        if showThreeMonths {
            threeMonthView
        } else {
            singleMonthView
        }
    }

    // MARK: - Single Month (iPhone)

    private var singleMonthView: some View {
        VStack(spacing: 4) {
            HStack {
                Text(monthLabel(for: displayMonth))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                monthNavButton(offset: -1, icon: "chevron.left")
                    .padding(.trailing, 12)
                monthNavButton(offset: 1, icon: "chevron.right")
            }
            .padding(.horizontal, 24)
            .offset(y: -20)

            weekdayHeader
            monthGrid(for: displayMonth)
        }
    }

    // MARK: - Scrollable Months (iPad)

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

    private var threeMonthView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(scrollableMonths, id: \.timeIntervalSince1970) { month in
                        let isCurrent = calendar.isDate(month, equalTo: Date(), toGranularity: .month)
                        monthSection(for: month, opacity: isCurrent ? 1.0 : 0.6)
                            .id(Self.yearMonthFormatter.string(from: month))
                    }
                }
                .padding(.vertical, 8)
            }
            .onAppear {
                proxy.scrollTo(currentMonthID, anchor: .center)
            }
        }
    }

    private func monthSection(for month: Date, opacity: Double) -> some View {
        VStack(spacing: 4) {
            Text(monthLabel(for: month))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)

            weekdayHeader
            monthGrid(for: month)
        }
        .opacity(opacity)
    }

    // MARK: - Shared Components

    private static let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                Text(Self.weekdayLabels[index])
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func monthGrid(for month: Date) -> some View {
        let weeks = weeksForMonth(month)
        return ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
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

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let dateStr = DateFormatters.iso.string(from: date)
        let isSelected = dateStr == selectedDate
        let isToday = dateStr == DateFormatters.todayString
        let color = dateColors[dateStr]
        let dayNum = calendar.component(.day, from: date)
        let wineCount = filteredDateCounts[dateStr] ?? 0

        Button {
            selectedDate = selectedDate == dateStr ? nil : dateStr
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
                        let size: CGFloat = dotSize(for: wineCount)
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: size, height: size)
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

    // MARK: - Helpers

    private func monthLabel(for date: Date) -> String {
        DateFormatters.monthAbbrev.string(from: date)
    }

    private func monthNavButton(offset: Int, icon: String) -> some View {
        Button {
            withAnimation { displayMonth = calendar.date(byAdding: .month, value: offset, to: displayMonth)! }
        } label: {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

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

    private func dotSize(for count: Int) -> CGFloat {
        if count > 10 { return 5 }
        if count > 5 { return 4 }
        return 3
    }
}
