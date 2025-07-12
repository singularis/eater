import SwiftUI

struct RecommendationView: View {
    @Environment(\.dismiss) private var dismiss
    let recommendationText: String
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Health Recommendation")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Group {
                        Text("Your Personalized Recommendation")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(recommendationText)
                            .font(.body)
                            .lineSpacing(4)
                    }
                    
                    Group {
                        Text("Important Health Disclaimer")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Text("⚠️ This information is for educational purposes only and should not replace professional medical advice. Consult your healthcare provider before making dietary changes.")
                            .font(.body)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Group {
                        Text("Data Sources")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• USDA FoodData Central")
                            Text("• Dietary Guidelines for Americans")
                            Text("• Evidence-based nutritional research")
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                    }
                    
                    Text("Generated on: \(Date().formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                }
                .padding()
            }
            .navigationTitle("Health Recommendation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RecommendationView(recommendationText: "Based on your recent eating patterns, we recommend incorporating more vegetables and lean proteins into your diet. Consider reducing processed foods and increasing your water intake. Your current calorie intake appears to be within healthy ranges.")
} 