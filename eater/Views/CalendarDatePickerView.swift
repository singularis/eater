import SwiftUI

struct CalendarDatePickerView: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    let onDateSelected: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
                Text("Select Date")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top)
                
                DatePicker(
                    "Select a date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .frame(height: 400) // Fixed height to prevent UICalendarView warnings
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
                .padding()
                
                HStack(spacing: 20) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle()) // Prevent default button behavior
                    
                    Button(action: {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "dd-MM-yyyy"
                        let dateString = dateFormatter.string(from: selectedDate)
                        
                        // Just call the callback - let parent handle dismissal
                        onDateSelected(dateString)
                    }) {
                        Text("Select")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle()) // Prevent default button behavior
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
        }
        .background(Color.black)
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