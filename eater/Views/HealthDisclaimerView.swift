import SwiftUI

struct HealthDisclaimerView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(loc("disc.title", "Health Information Disclaimer"))
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Group {
                        Text(loc("disc.section.notice", "Important Notice"))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(loc("disc.notice.text", "This app provides general nutritional information and dietary suggestions for educational purposes only. The information is not intended to replace professional medical advice, diagnosis, or treatment."))
                            .font(.body)
                    }
                    
                    Group {
                        Text(loc("disc.section.medical", "Medical Disclaimer"))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(loc("disc.medical.text", "Always consult with a qualified healthcare provider before making any changes to your diet or nutrition plan, especially if you have medical conditions, allergies, or dietary restrictions."))
                            .font(.body)
                    }
                    
                    Group {
                        Text(loc("disc.section.sources", "Data Sources & Citations"))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            CitationView(
                                title: "Nutritional Data",
                                source: "USDA FoodData Central",
                                url: "https://fdc.nal.usda.gov/",
                                description: "Comprehensive nutrient database for food composition analysis"
                            )
                            
                            CitationView(
                                title: "Dietary Guidelines",
                                source: "U.S. Department of Health and Human Services",
                                url: "https://www.dietaryguidelines.gov/",
                                description: "Evidence-based nutritional guidance for Americans"
                            )
                            
                            CitationView(
                                title: "Caloric Requirements",
                                source: "Institute of Medicine (IOM)",
                                url: "https://www.nationalacademies.org/",
                                description: "Dietary Reference Intakes for energy and macronutrients"
                            )
                            
                            CitationView(
                                title: "Food Safety Information",
                                source: "FDA - U.S. Food and Drug Administration",
                                url: "https://www.fda.gov/food",
                                description: "Food safety and nutrition labeling guidelines"
                            )
                            
                            CitationView(
                                title: "Nutritional Science Research",
                                source: "American Journal of Clinical Nutrition",
                                url: "https://academic.oup.com/ajcn",
                                description: "Peer-reviewed research on nutrition and health"
                            )
                            
                            CitationView(
                                title: "Food Composition Database",
                                source: "USDA National Nutrient Database",
                                url: "https://www.ars.usda.gov/northeast-area/beltsville-md-bhnrc/beltsville-human-nutrition-research-center/methods-and-application-of-food-composition-laboratory/",
                                description: "Standard reference for nutrient content of foods"
                            )
                        }
                    }
                    
                    Group {
                        Text(loc("disc.section.accuracy", "Accuracy Disclaimer"))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(loc("disc.accuracy.text", "Nutritional estimates are based on visual analysis and may not be completely accurate. Actual nutritional content may vary based on preparation methods, portion sizes, and ingredient variations."))
                            .font(.body)
                    }
                    
                    Group {
                        Text(loc("disc.section.features", "App Features & Limitations"))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                                                VStack(alignment: .leading, spacing: 8) {
                            Text(loc("disc.feature.calories", "• Calorie Tracking: Estimates based on visual food analysis"))
                            Text(loc("disc.feature.macros", "• Nutritional Analysis: Macronutrient breakdown using AI image recognition"))
                            Text(loc("disc.feature.recommendations", "• Dietary Recommendations: General suggestions based on nutritional guidelines"))  
                            Text(loc("disc.feature.weight", "• Weight Tracking: User-input data for personal monitoring"))
                            Text(loc("disc.feature.limits", "• Calorie Limits: Default values or personalized calculations based on health data"))
                            Text(loc("disc.feature.plans", "• Personalized Plans: Optional BMR-based calorie recommendations using user health data"))
                        }
                        .font(.body)
                    }
                    
                    Text(loc("disc.updated", "Last Updated:") + " " + Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                }
                .padding()
            }
            .navigationTitle("Health Information")
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

struct CitationView: View {
    let title: String
    let source: String
    let url: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(source)
                .font(.caption)
                .foregroundColor(.blue)
                .onTapGesture {
                    if let url = URL(string: url) {
                        UIApplication.shared.open(url)
                    }
                }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HealthDisclaimerView()
} 