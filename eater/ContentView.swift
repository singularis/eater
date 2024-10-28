import SwiftUI

struct ContentView: View {
    @State private var products: [Product] = []
    @State private var caloriesLeft: Int = 0
    @State private var date = Date()
    @State private var showCamera = false // State to control camera view

    var body: some View {
        ZStack {
            // Dark Mode Background
            Color.black
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 25) {
                // Date Display
                Text("Today: \(date, formatter: dateFormatter)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.9), radius: 10, x: 0, y: 8)

                // Calories Left Display
                Text("Total calories left: \(caloriesLeft)")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.gray.opacity(0.8))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 6)

                // Product List
                ProductListView(products: products)
                    .padding(.top, 10)

                // Camera Button
                Button(action: {
                    showCamera = true
                }) {
                    Image(systemName: "camera.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .padding()
                }
                .buttonStyle(SolidDarkBlueButtonStyle()) // Apply custom button style
                .padding(.top, 20)
            }
            .onAppear {
                fetchData()
            }
            .padding()
        }
        .sheet(isPresented: $showCamera) {
            CameraView()
        }
    }

    func fetchData() {
        GRPCService().fetchProducts { fetchedProducts, calories in
            products = fetchedProducts
            caloriesLeft = calories
        }
    }
}

// Custom Button Style for Solid Dark Blue Button
struct SolidDarkBlueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity) // Make it a full-width button
            .background(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(Color.blue.opacity(0.9))
                    .shadow(color: .black.opacity(configuration.isPressed ? 0.3 : 0.7), radius: 10, x: 5, y: 5)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
    }
}

// Global Date Formatter
private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()



#Preview {
    ContentView()
}
