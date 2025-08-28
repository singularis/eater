import SwiftUI

struct RecommendationView: View {
    @Environment(\.dismiss) private var dismiss
    let recommendationText: String
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(loc("rec.title", "Health Recommendation"))
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Group {
                        Text(loc("rec.subtitle", "Your Personalized Recommendation"))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(recommendationText)
                            .font(.body)
                            .lineSpacing(4)
                    }
                    
                    Group {
                        Text(loc("rec.disclaimer.title", "Important Health Disclaimer"))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Text(loc("rec.disclaimer.text", "⚠️ This information is for educational purposes only and should not replace professional medical advice. Consult your healthcare provider before making dietary changes."))
                            .font(.body)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Group {
                        Text(loc("rec.sources", "Data Sources"))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(loc("rec.src.usda", "• USDA FoodData Central"))
                            Text(loc("rec.src.guidelines", "• Dietary Guidelines for Americans"))
                            Text(loc("rec.src.research", "• Evidence-based nutritional research"))
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                    }
                    
                    Text(loc("rec.generated_on", "Generated on:") + " " + formatLocalizedDate(Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                }
                .padding()
            }
            .navigationTitle(loc("rec.title", "Health Recommendation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(loc("common.done", "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatLocalizedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LanguageService.shared.currentCode)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    RecommendationView(recommendationText: "Based on your recent eating patterns, we recommend incorporating more vegetables and lean proteins into your diet. Consider reducing processed foods and increasing your water intake. Your current calorie intake appears to be within healthy ranges.")
} 