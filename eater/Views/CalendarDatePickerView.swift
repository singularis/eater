import SwiftUI

struct CalendarDatePickerView: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    let onDateSelected: (String) -> Void
    
    var body: some View {
        NavigationView {
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
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
                .padding()
                
                HStack(spacing: 20) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Select") {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "dd-MM-yyyy"
                        let dateString = dateFormatter.string(from: selectedDate)
                        
                        // Just call the callback - let parent handle dismissal
                        onDateSelected(dateString)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
                
                Spacer()
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    CalendarDatePickerView(
        selectedDate: .constant(Date()),
        isPresented: .constant(true),
        onDateSelected: { _ in }
    )
} 