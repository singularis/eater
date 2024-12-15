import SwiftUI

struct ContentView: View {
    @State private var products: [Product] = []
    @State private var caloriesLeft: Int = 0
    @State private var persohWeight: Float = 0
    @State private var date = Date()
    @State private var showCamera = false

    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 3) {
                // Date Display
                Text(date, formatter: dateFormatter)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.9), radius: 10, x: 0, y: 8)

                GeometryReader { geo in
                    Button(action: {
                        showCamera = true
                    }) {
                        Text(String(format: "%.1f", persohWeight))
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.gray.opacity(0.8))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 6)
                    }
                    .position(x: 30, y: geo.size.height / 2)
                    .sheet(isPresented: $showCamera) {
                        CameraView(photoType: "weight_prompt", onPhotoSubmitted: fetchData)
                    }

                    Text("Calories: \(caloriesLeft)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 6)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .frame(height: 60)

                ProductListView(products: products, onRefresh: fetchData, onDelete: deleteProduct)
                    .padding(.top, 3)

                CameraButtonView(onPhotoSubmitted: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        fetchData()
                    }
                })
                .buttonStyle(SolidDarkBlueButtonStyle())
                .padding(.top, 10)
            }
            .onAppear {
                fetchData()
            }
            .padding()
        }
    }

    func fetchData() {
        GRPCService().fetchProducts { fetchedProducts, calories, weight in
            products = fetchedProducts
            caloriesLeft = calories
            persohWeight = weight
        }
    }

    func deleteProduct(time: Int64) {
        GRPCService().deleteFood(time: Int64(time)) { success in
            if success {
                fetchData()
            } else {
                print("Failed to delete product")
            }
        }
    }
}

struct SolidDarkBlueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
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

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

#Preview {
    ContentView()
}
