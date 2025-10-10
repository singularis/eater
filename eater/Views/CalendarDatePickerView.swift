import SwiftUI

struct CalendarDatePickerView: View {
  @Binding var selectedDate: Date
  @Binding var isPresented: Bool
  let onDateSelected: (String) -> Void

  var body: some View {
    VStack(spacing: 20) {
      Text(loc("calendar.selectdate", "Select Date"))
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(AppTheme.textPrimary)
        .padding(.top)

      DatePicker(
        loc("calendar.selectdate", "Select Date"),
        selection: $selectedDate,
        in: ...Date(),
        displayedComponents: [.date]
      )
      .datePickerStyle(GraphicalDatePickerStyle())
      .frame(height: 400)  // Fixed height to prevent UICalendarView warnings
      .background(AppTheme.surface)
      .cornerRadius(AppTheme.cornerRadius)
      .padding()
      .environment(\.locale, Locale(identifier: LanguageService.shared.currentCode))
      .environment(
        \.calendar,
        {
          var cal = Calendar.current
          cal.locale = Locale(identifier: LanguageService.shared.currentCode)
          return cal
        }())
      .onChange(of: selectedDate) { oldDate, newDate in
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        let dateString = dateFormatter.string(from: newDate)
        
        // Immediately trigger callback when date changes
        onDateSelected(dateString)
      }

      Button(action: {
        isPresented = false
      }) {
        Text(loc("common.cancel", "Cancel"))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(SecondaryButtonStyle())
      .padding(.horizontal)
      .padding(.bottom, 20)
    }
    .background(AppTheme.backgroundGradient)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview {
  CalendarDatePickerView(
    selectedDate: .constant(Date()),
    isPresented: .constant(true),
    onDateSelected: { _ in }
  )
}

