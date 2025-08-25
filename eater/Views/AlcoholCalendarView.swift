import SwiftUI

struct AlcoholCalendarView: View {
    @Binding var isPresented: Bool
    @State private var monthAnchorDate: Date = Date()
    @State private var eventsByDateString: [String: Int] = [:] // yyyy-MM-dd -> count of drinks
    @State private var dayEvents: [String: [Eater_AlcoholEvent]] = [:] // yyyy-MM-dd -> events
    @State private var isLoading: Bool = false
    @State private var showDetailsAlert: Bool = false
    @State private var detailsAlertTitle: String = ""
    @State private var detailsAlertMessage: String = ""
    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayHeader
            monthGrid
            Spacer(minLength: 0)
            Button(action: { isPresented = false }) {
                Text("Close")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .padding(.top, 16)
        .background(Color.black)
        .onAppear {
            fetchMonth()
        }
        .onChange(of: monthAnchorDate) { _ in
            fetchMonth()
        }
        .overlay(
            LoadingOverlay(isVisible: isLoading, message: "Loading alcohol...")
        )
        .alert(detailsAlertTitle, isPresented: $showDetailsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(detailsAlertMessage)
        }
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    guard abs(horizontal) > 40 && vertical < 60 else { return }
                    if horizontal < 0 {
                        withAnimation { changeMonth(by: 1) } // swipe left → next month
                    } else {
                        withAnimation { changeMonth(by: -1) } // swipe right → previous month
                    }
                }
        )
    }
    
    private var header: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
            }
            Spacer()
            Text(monthTitle(for: monthAnchorDate))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
    }
    
    private var weekdayHeader: some View {
        HStack {
            ForEach(0..<weekdaySymbols.count, id: \.self) { idx in
                let sym = weekdaySymbols[idx]
                Text(sym)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }
    
    private var monthGrid: some View {
        let days = daysForMonthGrid(date: monthAnchorDate)
        return VStack(spacing: 8) {
            ForEach(0..<days.count/7 + (days.count % 7 == 0 ? 0 : 1), id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { col in
                        let idx = row * 7 + col
                        if idx < days.count {
                            let day = days[idx]
                            dayCell(day: day)
                        } else {
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func dayCell(day: DayCell) -> some View {
        let isCurrentMonth = day.isCurrentMonth
        let amount = eventsByDateString[day.dateString] ?? 0
        return VStack(spacing: 6) {
            Text("\(day.dayNumber)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(isCurrentMonth ? .white : .white.opacity(0.3))
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
        )
        .overlay(alignment: .center) {
            if amount > 0 {
                Circle()
                    .fill(Color.red)
                    .frame(width: dotSize(for: amount), height: dotSize(for: amount))
                    .shadow(color: .red.opacity(0.4), radius: 3, x: 0, y: 1)
                    .offset(y: 14)
                    .zIndex(10)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard let events = dayEvents[day.dateString], !events.isEmpty else { return }
            detailsAlertTitle = prettyDate(fromYYYYMMDD: day.dateString)
            detailsAlertMessage = formattedEventsList(events)
            showDetailsAlert = true
        }
    }
    
    private func dotSize(for amount: Int) -> CGFloat {
        let base: CGFloat = 16
        let maxSize: CGFloat = 56
        guard amount > 0 else { return base }
        return min(base * CGFloat(amount), maxSize)
    }
    
    private func changeMonth(by delta: Int) {
        if let newDate = calendar.date(byAdding: .month, value: delta, to: monthAnchorDate) {
            monthAnchorDate = newDate
        }
    }
    
    private func monthTitle(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "LLLL yyyy"
        return fmt.string(from: date)
    }
    
    private func daysForMonthGrid(date: Date) -> [DayCell] {
        let range = calendar.range(of: .day, in: .month, for: date) ?? 1..<31
        let components = calendar.dateComponents([.year, .month], from: date)
        let firstDay = calendar.date(from: components) ?? date
        let firstWeekday = calendar.component(.weekday, from: firstDay) // 1..7, Sunday=1
        var days: [DayCell] = []
        // Previous month padding
        if let prevMonth = calendar.date(byAdding: .month, value: -1, to: firstDay) {
            let prevRange = calendar.range(of: .day, in: .month, for: prevMonth) ?? 1..<31
            let padding = (firstWeekday + 6) % 7 // make Monday=0 alignment if needed; here keep Sunday first
            let prevMonthComponents = calendar.dateComponents([.year, .month], from: prevMonth)
            for i in 0..<padding {
                let dayNum = prevRange.count - padding + 1 + i
                if let d = dateFrom(year: prevMonthComponents.year!, month: prevMonthComponents.month!, day: dayNum) {
                    days.append(makeDayCell(for: d, isCurrentMonth: false))
                }
            }
        }
        // Current month
        for day in range {
            if let d = dateFrom(year: components.year!, month: components.month!, day: day) {
                days.append(makeDayCell(for: d, isCurrentMonth: true))
            }
        }
        // Next month padding to complete weeks
        while days.count % 7 != 0 {
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay) {
                let nextCount = days.count - ((firstWeekday + 6) % 7) - (range.count)
                let dayNum = nextCount + 1
                let comps = calendar.dateComponents([.year, .month], from: nextMonth)
                if let d = dateFrom(year: comps.year!, month: comps.month!, day: dayNum) {
                    days.append(makeDayCell(for: d, isCurrentMonth: false))
                } else {
                    break
                }
            } else {
                break
            }
        }
        return days
    }
    
    private func dateFrom(year: Int, month: Int, day: Int) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.date(from: comps)
    }
    
    private func makeDayCell(for date: Date, isCurrentMonth: Bool) -> DayCell {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateString = df.string(from: date)
        let dayNumber = calendar.component(.day, from: date)
        return DayCell(date: date, dateString: dateString, dayNumber: dayNumber, isCurrentMonth: isCurrentMonth)
    }
    
    private func fetchMonth() {
        let startEnd = monthStartEnd(for: monthAnchorDate)
        isLoading = true
        GRPCService().fetchAlcoholRange(startDateDDMMYYYY: startEnd.startDDMMYYYY, endDateDDMMYYYY: startEnd.endDDMMYYYY) { resp in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let resp = resp else {
                    self.eventsByDateString = [:]
                    self.dayEvents = [:]
                    return
                }
                var countMap: [String: Int] = [:]
                var eventsMap: [String: [Eater_AlcoholEvent]] = [:]
                for e in resp.events {
                    let key = e.date
                    countMap[key, default: 0] += 1
                    eventsMap[key, default: []].append(e)
                }
                self.eventsByDateString = countMap
                self.dayEvents = eventsMap
            }
        }
    }
    
    private func monthStartEnd(for date: Date) -> (startDDMMYYYY: String, endDDMMYYYY: String) {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let first = calendar.date(from: comps) ?? date
        let range = calendar.range(of: .day, in: .month, for: first) ?? 1..<31
        let lastDay = range.count
        let last = calendar.date(byAdding: DateComponents(day: lastDay - 1), to: first) ?? first
        let out = DateFormatter()
        out.dateFormat = "dd-MM-yyyy"
        return (out.string(from: first), out.string(from: last))
    }

    private func prettyDate(fromYYYYMMDD s: String) -> String {
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM-dd"
        let outFmt = DateFormatter()
        outFmt.dateStyle = .medium
        outFmt.timeStyle = .none
        if let d = inFmt.date(from: s) {
            return outFmt.string(from: d)
        }
        return s
    }

    private func formattedEventsList(_ events: [Eater_AlcoholEvent]) -> String {
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        var lines: [String] = []
        for e in events.sorted(by: { $0.time < $1.time }) {
            let date = Date(timeIntervalSince1970: TimeInterval(e.time))
            let t = timeFmt.string(from: date)
            let name = e.drinkName
            let qty = e.quantity
            let cal = e.calories
            lines.append("\(t) • \(name) • \(qty)ml • \(cal) kcal")
        }
        return lines.joined(separator: "\n")
    }
}

private struct DayCell: Identifiable {
    let id = UUID()
    let date: Date
    let dateString: String // yyyy-MM-dd
    let dayNumber: Int
    let isCurrentMonth: Bool
}


