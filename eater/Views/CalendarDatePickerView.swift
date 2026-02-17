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
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = "dd-MM-yyyy"
        let dateString = dateFormatter.string(from: newDate)
        
        // Immediately trigger callback when date changes
        onDateSelected(dateString)
      }

      HStack {
        Spacer(minLength: 0)
        Button(action: {
          isPresented = false
        }) {
          Text(loc("common.done", "Done"))
        }
        .buttonStyle(SecondaryButtonStyle())
      }
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

