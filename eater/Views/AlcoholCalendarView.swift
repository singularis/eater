import SwiftUI

struct AlcoholCalendarView: View {
  @Binding var isPresented: Bool
  @State private var monthAnchorDate: Date = .init()
  @State private var eventsByDateString: [String: Int] = [:]  // yyyy-MM-dd -> count of drinks
  @State private var dayEvents: [String: [Eater_AlcoholEvent]] = [:]  // yyyy-MM-dd -> events
  @State private var isLoading: Bool = false
  @State private var showDetailsAlert: Bool = false
  @State private var detailsAlertTitle: String = ""
  @State private var detailsAlertMessage: String = ""
  private var locale: Locale { Locale(identifier: LanguageService.shared.currentCode) }
  private var calendar: Calendar {
    var cal = Calendar.current
    cal.locale = locale
    return cal
  }

  private var weekdaySymbols: [String] {
    let df = DateFormatter()
    df.locale = locale
    let base =
      df.veryShortStandaloneWeekdaySymbols
      ?? df.veryShortWeekdaySymbols
      ?? df.shortStandaloneWeekdaySymbols
      ?? df.shortWeekdaySymbols
      ?? ["S", "M", "T", "W", "T", "F", "S"]
    // Reorder according to firstWeekday (DateFormatter symbols are Sunday-first)
    let first = max(1, min(7, calendar.firstWeekday))
    if first == 1 { return base }
    let head = Array(base[(first - 1)...])
    let tail = Array(base[..<(first - 1)])
    return head + tail
  }

  var body: some View {
    VStack(spacing: 12) {
      addictionModeExplanation
      header
      weekdayHeader
      monthGrid
      Spacer(minLength: 0)
      Button(action: { isPresented = false }) {
        Text(loc("common.close", "Close"))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(PrimaryButtonStyle())
      .padding(.horizontal)
      .padding(.bottom, 12)
    }
    .padding(.top, 16)
    .background(AppTheme.backgroundGradient)
    .onAppear {
      fetchMonth()
    }
    .onChange(of: monthAnchorDate) { _, _ in
      fetchMonth()
    }
    .overlay(
      LoadingOverlay(
        isVisible: isLoading, message: loc("overlay.loading_alcohol", "Loading alcohol..."))
    )
    .alert(detailsAlertTitle, isPresented: $showDetailsAlert) {
      Button(loc("common.ok", "OK"), role: .cancel) {}
    } message: {
      Text(detailsAlertMessage)
    }
    .gesture(
      DragGesture(minimumDistance: 20, coordinateSpace: .local)
        .onEnded { value in
          let horizontal = value.translation.width
          let vertical = abs(value.translation.height)
          guard abs(horizontal) > 40, vertical < 60 else { return }
          if horizontal < 0 {
            withAnimation { changeMonth(by: 1) }  // swipe left → next month
          } else {
            withAnimation { changeMonth(by: -1) }  // swipe right → previous month
          }
        }
    )
  }

  private var addictionModeExplanation: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(loc("alcohol.addiction_mode.title", "🍷 Addiction Mode"))
        .font(.system(size: 17, weight: .bold, design: .rounded))
        .foregroundColor(AppTheme.textPrimary)
      Text(loc("alcohol.addiction_mode.subtitle", "Track alcohol intake and stay mindful."))
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .foregroundColor(AppTheme.textSecondary)
      Text(loc("alcohol.addiction_mode.desc", "Alcohol entries are automatically logged in your calendar, and the alcohol icon turns red to highlight the day."))
        .font(.system(size: 14, weight: .regular, design: .rounded))
        .foregroundColor(AppTheme.textSecondary)
        .lineSpacing(3)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(AppTheme.surface.opacity(0.8))
    .cornerRadius(12)
    .padding(.horizontal, 16)
  }

  private var header: some View {
    HStack {
      Button(action: { changeMonth(by: -1) }) {
        Image(systemName: "chevron.left")
          .foregroundColor(AppTheme.textPrimary)
      }
      Spacer()
      Text(monthTitle(for: monthAnchorDate))
        .font(.system(size: 18, weight: .bold, design: .rounded))
        .foregroundColor(AppTheme.textPrimary)
      Spacer()
      Button(action: { changeMonth(by: 1) }) {
        Image(systemName: "chevron.right")
          .foregroundColor(AppTheme.textPrimary)
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
          .foregroundColor(AppTheme.textSecondary)
          .frame(maxWidth: .infinity)
      }
    }
    .padding(.horizontal)
  }

  private var monthGrid: some View {
    let days = daysForMonthGrid(date: monthAnchorDate)
    return VStack(spacing: 8) {
      ForEach(0..<days.count / 7 + (days.count % 7 == 0 ? 0 : 1), id: \.self) { row in
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
    return Button(action: {
      guard let events = dayEvents[day.dateString], !events.isEmpty else { return }
      detailsAlertTitle = prettyDate(fromYYYYMMDD: day.dateString)
      detailsAlertMessage = formattedEventsList(events)
      showDetailsAlert = true
    }) {
      VStack(spacing: 6) {
        Text("\(day.dayNumber)")
          .font(.system(size: 14, weight: .medium, design: .rounded))
          .foregroundColor(isCurrentMonth ? AppTheme.textPrimary : AppTheme.textSecondary.opacity(0.4))
          .frame(maxWidth: .infinity)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 44)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(AppTheme.surface)
      )
      .overlay(alignment: .center) {
        if amount > 0 {
          let shadow = AppTheme.cardShadow
          Circle()
            .fill(AppTheme.danger)
            .frame(width: dotSize(for: amount), height: dotSize(for: amount))
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
            .offset(y: 14)
            .zIndex(10)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScaleButtonStyle())
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
    fmt.locale = locale
    fmt.setLocalizedDateFormatFromTemplate("LLLL yyyy")
    return fmt.string(from: date)
  }

  private func daysForMonthGrid(date: Date) -> [DayCell] {
    let currentRange = calendar.range(of: .day, in: .month, for: date) ?? 1..<31
    let currentMonthComponents = calendar.dateComponents([.year, .month], from: date)
    let firstDayOfMonth = calendar.date(from: currentMonthComponents) ?? date
    let firstWeekdayOfMonth = calendar.component(.weekday, from: firstDayOfMonth)  // 1..7, Sunday=1
    let weekStart = calendar.firstWeekday  // 1..7

    // Number of leading cells to align with locale's first weekday
    let leading = (firstWeekdayOfMonth - weekStart + 7) % 7

    var days: [DayCell] = []

    // Previous month padding (aligned to locale's first weekday)
    if leading > 0, let prevMonth = calendar.date(byAdding: .month, value: -1, to: firstDayOfMonth)
    {
      let prevRange = calendar.range(of: .day, in: .month, for: prevMonth) ?? 1..<31
      let prevMonthComponents = calendar.dateComponents([.year, .month], from: prevMonth)
      let startDay = prevRange.count - leading + 1
      for dayNum in startDay...prevRange.count {
        if let d = dateFrom(
          year: prevMonthComponents.year!, month: prevMonthComponents.month!, day: dayNum)
        {
          days.append(makeDayCell(for: d, isCurrentMonth: false))
        }
      }
    }

    // Current month
    for day in currentRange {
      if let d = dateFrom(
        year: currentMonthComponents.year!, month: currentMonthComponents.month!, day: day)
      {
        days.append(makeDayCell(for: d, isCurrentMonth: true))
      }
    }

    // Next month padding to complete weeks
    let remainder = days.count % 7
    if remainder != 0,
      let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDayOfMonth)
    {
      let trailing = 7 - remainder
      let nextComps = calendar.dateComponents([.year, .month], from: nextMonth)
      for i in 1...trailing {
        if let d = dateFrom(year: nextComps.year!, month: nextComps.month!, day: i) {
          days.append(makeDayCell(for: d, isCurrentMonth: false))
        }
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
    return DayCell(
      date: date, dateString: dateString, dayNumber: dayNumber, isCurrentMonth: isCurrentMonth)
  }

  private func fetchMonth() {
    let startEnd = monthStartEnd(for: monthAnchorDate)
    isLoading = true
    GRPCService().fetchAlcoholRange(
      startDateDDMMYYYY: startEnd.startDDMMYYYY, endDateDDMMYYYY: startEnd.endDDMMYYYY
    ) { resp in
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
    outFmt.locale = locale
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
  let dateString: String  // yyyy-MM-dd
  let dayNumber: Int
  let isCurrentMonth: Bool
}
