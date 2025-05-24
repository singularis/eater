import SwiftUI

struct ContentView: View {
    @State private var products: [Product] = []
    @State private var caloriesLeft: Int = 0
    @State private var personWeight: Float = 0
    @State private var date = Date()
    @State private var showCamera = false
    @State private var isLoadingRecommendation = false
    @State private var showLimitsAlert = false
    @State private var tempSoftLimit = ""
    @State private var tempHardLimit = ""
    @State private var softLimit = 1900
    @State private var hardLimit = 2100
    
    // New loading states
    @State private var isLoadingData = false
    @State private var isLoadingWeightPhoto = false
    @State private var isLoadingFoodPhoto = false
    @State private var deletingProductTime: Int64? = nil
    
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
                        ZStack {
                            if isLoadingWeightPhoto {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(String(format: "%.1f", personWeight))
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 6)
                    }
                    .position(x: 30, y: geo.size.height / 2)
                    .sheet(isPresented: $showCamera) {
                        CameraView(
                            photoType: "weight_prompt", 
                            onPhotoSuccess: {
                                fetchDataWithWeightLoading()
                            },
                            onPhotoFailure: {
                                isLoadingWeightPhoto = false
                            },
                            onPhotoStarted: {
                                isLoadingWeightPhoto = true
                            }
                        )
                    }

                    Text("Calories: \(softLimit-caloriesLeft)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(getColor(for: caloriesLeft))
                        .padding()
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 6)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .onTapGesture {
                            tempSoftLimit = String(softLimit)
                            tempHardLimit = String(hardLimit)
                            showLimitsAlert = true
                        }

                    ZStack {
                        if isLoadingRecommendation {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Tend")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.8))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 6)
                    .position(x: geo.size.width - 30, y: geo.size.height / 2)
                    .onTapGesture {
                        isLoadingRecommendation = true
                        GRPCService().getRecommendation(days: 7) { recommendation in
                            DispatchQueue.main.async {
                                AlertHelper.showAlert(title: "Recommendation", message: recommendation)
                                isLoadingRecommendation = false
                            }
                        }
                    }
                }
                .frame(height: 60)

                ProductListView(
                    products: products, 
                    onRefresh: fetchDataWithLoading, 
                    onDelete: deleteProductWithLoading,
                    deletingProductTime: deletingProductTime
                )
                .padding(.top, 3)

                CameraButtonView(
                    isLoadingFoodPhoto: isLoadingFoodPhoto,
                    onPhotoSuccess: {
                        fetchDataAfterFoodPhoto()
                    },
                    onPhotoFailure: {
                        // Photo processing failed, no need to fetch data
                        isLoadingFoodPhoto = false
                        print("Food photo processing failed")
                    },
                    onPhotoStarted: {
                        // Photo processing started
                        isLoadingFoodPhoto = true
                    }
                )
                .buttonStyle(SolidDarkBlueButtonStyle())
                .padding(.top, 10)
            }
            .onAppear {
                loadLimitsFromUserDefaults()
                fetchDataWithLoading()
            }
            .padding()
            .alert("Set Calorie Limits", isPresented: $showLimitsAlert) {
                VStack {
                    TextField("Soft Limit", text: $tempSoftLimit)
                        .keyboardType(.numberPad)
                    TextField("Hard Limit", text: $tempHardLimit)
                        .keyboardType(.numberPad)
                }
                Button("Save") {
                    saveLimits()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Set your daily calorie soft limit (yellow warning) and hard limit (red warning)")
            }
            
            LoadingOverlay(isVisible: isLoadingData, message: "Loading food data...")
        }
    }

    func fetchDataWithLoading() {
        isLoadingData = true
        GRPCService().fetchProducts { fetchedProducts, calories, weight in
            DispatchQueue.main.async {
                products = fetchedProducts
                caloriesLeft = calories
                personWeight = weight
                isLoadingData = false
            }
        }
    }
    
    func fetchDataWithWeightLoading() {
        GRPCService().fetchProducts { fetchedProducts, calories, weight in
            DispatchQueue.main.async {
                products = fetchedProducts
                caloriesLeft = calories
                personWeight = weight
                isLoadingWeightPhoto = false
            }
        }
    }
    
    func fetchData() {
        GRPCService().fetchProducts { fetchedProducts, calories, weight in
            DispatchQueue.main.async {
                products = fetchedProducts
                caloriesLeft = calories
                personWeight = weight
            }
        }
    }

    func deleteProduct(time: Int64) {
        GRPCService().deleteFood(time: Int64(time)) { success in
            DispatchQueue.main.async {
                if success {
                    self.fetchData()
                } else {
                    print("Failed to delete product")
                }
            }
        }
    }
    
    func fetchDataWithCompletion(completion: @escaping () -> Void) {
        GRPCService().fetchProducts { fetchedProducts, calories, weight in
            DispatchQueue.main.async {
                self.products = fetchedProducts
                self.caloriesLeft = calories
                self.personWeight = weight
                completion()
            }
        }
    }

    private func getColor(for value: Int) -> Color {
        if value < softLimit {
            return .green
        } else if value < hardLimit {
            return .yellow
        } else {
            return .red
        }
    }

    private func loadLimitsFromUserDefaults() {
        let userDefaults = UserDefaults.standard
        let savedSoftLimit = userDefaults.integer(forKey: "softLimit")
        let savedHardLimit = userDefaults.integer(forKey: "hardLimit")
        
        // Only use saved values if they exist (not 0)
        if savedSoftLimit > 0 {
            softLimit = savedSoftLimit
        }
        if savedHardLimit > 0 {
            hardLimit = savedHardLimit
        }
    }

    private func saveLimits() {
        guard let newSoftLimit = Int(tempSoftLimit),
              let newHardLimit = Int(tempHardLimit),
              newSoftLimit > 0,
              newHardLimit > 0,
              newSoftLimit <= newHardLimit else {
            // Show error if invalid input
            AlertHelper.showAlert(title: "Invalid Input", message: "Please enter valid positive numbers. Soft limit must be less than or equal to hard limit.")
            return
        }
        
        softLimit = newSoftLimit
        hardLimit = newHardLimit
        
        // Save to UserDefaults
        let userDefaults = UserDefaults.standard
        userDefaults.set(softLimit, forKey: "softLimit")
        userDefaults.set(hardLimit, forKey: "hardLimit")
    }

    func deleteProductWithLoading(time: Int64) {
        deletingProductTime = time
        GRPCService().deleteFood(time: Int64(time)) { success in
            DispatchQueue.main.async {
                if success {
                    self.fetchDataWithCompletion {
                        self.deletingProductTime = nil
                    }
                } else {
                    print("Failed to delete product")
                    self.deletingProductTime = nil
                }
            }
        }
    }

    func fetchDataAfterFoodPhoto() {
        GRPCService().fetchProducts { fetchedProducts, calories, weight in
            DispatchQueue.main.async {
                self.products = fetchedProducts
                self.caloriesLeft = calories
                self.personWeight = weight
                self.isLoadingFoodPhoto = false
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
