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

  private var todayDateString: String {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    return df.string(from: Date())
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          addictionModeExplanation
          calendarCard
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24)
      }
      .background(Color(.systemGroupedBackground).ignoresSafeArea())
      .navigationTitle(loc("alcohol.addiction_mode.title", "🍷 Addiction Mode"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(loc("common.done", "Done")) {
            isPresented = false
          }
          .fontWeight(.semibold)
          .foregroundColor(AppTheme.primaryButtonFill)
        }
      }
    }
    .tint(AppTheme.primaryButtonFill)
    .onAppear { fetchMonth() }
    .onChange(of: monthAnchorDate) { _, _ in fetchMonth() }
    .overlay(
      LoadingOverlay(
        isVisible: isLoading, message: loc("overlay.loading_alcohol", "Loading alcohol..."))
    )
    .alert(detailsAlertTitle, isPresented: $showDetailsAlert) {
      Button(loc("common.ok", "OK"), role: .cancel) {}
    } message: {
      Text(detailsAlertMessage)
    }
  }

  private var addictionModeExplanation: some View {
    Text(
      loc(
        "alcohol.addiction_mode.desc",
        "Alcohol entries are automatically logged in your calendar, and the alcohol icon turns red to highlight the day."
      )
    )
    .font(.subheadline)
    .foregroundColor(AppTheme.textSecondary)
    .fixedSize(horizontal: false, vertical: true)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
        .fill(Color(.secondarySystemGroupedBackground))
    )
  }

  private var calendarCard: some View {
    VStack(spacing: 12) {
      header
      weekdayHeader
      monthGrid
      legend
    }
    .padding(14)
    .background(
      RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
        .fill(Color(.secondarySystemGroupedBackground))
    )
    .gesture(
      DragGesture(minimumDistance: 24, coordinateSpace: .local)
        .onEnded { value in
          let horizontal = value.translation.width
          let vertical = abs(value.translation.height)
          guard abs(horizontal) > 40, vertical < 60 else { return }
          if horizontal < 0 {
            withAnimation { changeMonth(by: 1) }
          } else {
            withAnimation { changeMonth(by: -1) }
          }
        }
    )
  }

  private var header: some View {
    HStack {
      Button(action: { changeMonth(by: -1) }) {
        Image(systemName: "chevron.left")
          .font(.body.weight(.semibold))
          .foregroundColor(AppTheme.textPrimary)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel(loc("common.previous", "Previous"))
      Spacer()
      Text(monthTitle(for: monthAnchorDate))
        .font(.headline)
        .foregroundColor(AppTheme.textPrimary)
      Spacer()
      Button(action: { changeMonth(by: 1) }) {
        Image(systemName: "chevron.right")
          .font(.body.weight(.semibold))
          .foregroundColor(AppTheme.textPrimary)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel(loc("common.next", "Next"))
    }
  }

  private var weekdayHeader: some View {
    HStack(spacing: 0) {
      ForEach(0..<weekdaySymbols.count, id: \.self) { idx in
        Text(weekdaySymbols[idx])
          .font(.caption.weight(.semibold))
          .foregroundColor(AppTheme.textSecondary)
          .frame(maxWidth: .infinity)
      }
    }
  }

  private var monthGrid: some View {
    let days = daysForMonthGrid(date: monthAnchorDate)
    return VStack(spacing: 6) {
      ForEach(0..<days.count / 7 + (days.count % 7 == 0 ? 0 : 1), id: \.self) { row in
        HStack(spacing: 6) {
          ForEach(0..<7, id: \.self) { col in
            let idx = row * 7 + col
            if idx < days.count {
              dayCell(day: days[idx])
            } else {
              Color.clear.frame(maxWidth: .infinity, minHeight: 48)
            }
          }
        }
      }
    }
  }

  private var legend: some View {
    HStack(spacing: 16) {
      legendItem(fill: AppTheme.primaryButtonFill.opacity(0.16), ring: true, text: loc("date.today", "Today"))
      legendItem(fill: AppTheme.danger.opacity(0.18), ring: false, text: loc("alcohol.legend.logged", "Logged"))
      Spacer(minLength: 0)
    }
  }

  private func legendItem(fill: Color, ring: Bool, text: String) -> some View {
    HStack(spacing: 6) {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(fill)
        .overlay(
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(ring ? AppTheme.primaryButtonFill : Color.clear, lineWidth: 1.5)
        )
        .frame(width: 16, height: 16)
      Text(text)
        .font(.caption)
        .foregroundColor(AppTheme.textSecondary)
        .lineLimit(1)
    }
  }

  private func dayCell(day: DayCell) -> some View {
    let isCurrentMonth = day.isCurrentMonth
    let amount = eventsByDateString[day.dateString] ?? 0
    let isToday = day.dateString == todayDateString
    let hasDrinks = amount > 0

    return Button(action: {
      guard let events = dayEvents[day.dateString], !events.isEmpty else { return }
      detailsAlertTitle = prettyDate(fromYYYYMMDD: day.dateString)
      detailsAlertMessage = formattedEventsList(events)
      showDetailsAlert = true
    }) {
      VStack(spacing: 2) {
        Text("\(day.dayNumber)")
          .font(.system(size: 15, weight: isToday ? .semibold : .medium, design: .rounded))
          .foregroundColor(dayNumberColor(isCurrentMonth: isCurrentMonth, hasDrinks: hasDrinks))
        if hasDrinks {
          Text(amount > 9 ? "9+" : "\(amount)")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.danger)
        } else {
          Text(" ")
            .font(.system(size: 10, weight: .bold, design: .rounded))
        }
      }
      .frame(maxWidth: .infinity)
      .frame(minHeight: 48)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(dayFill(isToday: isToday, hasDrinks: hasDrinks, isCurrentMonth: isCurrentMonth))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(isToday ? AppTheme.primaryButtonFill : Color.clear, lineWidth: 2)
      )
      .opacity(isCurrentMonth ? 1 : 0.45)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!hasDrinks)
    .accessibilityLabel(dayAccessibility(day: day, amount: amount, isToday: isToday))
  }

  private func dayFill(isToday: Bool, hasDrinks: Bool, isCurrentMonth: Bool) -> Color {
    if hasDrinks {
      return AppTheme.danger.opacity(isCurrentMonth ? 0.16 : 0.08)
    }
    if isToday {
      return AppTheme.primaryButtonFill.opacity(0.10)
    }
    return Color.clear
  }

  private func dayNumberColor(isCurrentMonth: Bool, hasDrinks: Bool) -> Color {
    if hasDrinks { return AppTheme.textPrimary }
    return isCurrentMonth ? AppTheme.textPrimary : AppTheme.textSecondary
  }

  private func dayAccessibility(day: DayCell, amount: Int, isToday: Bool) -> String {
    let date = prettyDate(fromYYYYMMDD: day.dateString)
    if amount > 0 {
      return "\(date), \(amount)"
    }
    return isToday ? "\(date), \(loc("date.today", "Today"))" : date
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
