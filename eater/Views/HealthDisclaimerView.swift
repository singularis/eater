import SwiftUI

struct HealthDisclaimerView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var appLocale: Locale { Locale(identifier: LanguageService.shared.currentCode) }
    private var lastUpdatedText: String {
        let df = DateFormatter()
        df.locale = appLocale
        df.dateStyle = .medium
        df.timeStyle = .none
        return loc("disc.updated", "Last Updated:") + " " + df.string(from: Date())
    }
    
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
                                titleKey: "disc.src.nutrition.title",
                                titleFallback: "Nutritional Data",
                                sourceKey: "disc.src.nutrition.source",
                                sourceFallback: "USDA FoodData Central",
                                urlString: "https://fdc.nal.usda.gov/",
                                descKey: "disc.src.nutrition.desc",
                                descFallback: "Comprehensive nutrient database for food composition analysis"
                            )
                            
                            CitationView(
                                titleKey: "disc.src.guidelines.title",
                                titleFallback: "Dietary Guidelines",
                                sourceKey: "disc.src.guidelines.source",
                                sourceFallback: "U.S. Department of Health and Human Services",
                                urlString: "https://www.dietaryguidelines.gov/",
                                descKey: "disc.src.guidelines.desc",
                                descFallback: "Evidence-based nutritional guidance for Americans"
                            )
                            
                            CitationView(
                                titleKey: "disc.src.caloric.title",
                                titleFallback: "Caloric Requirements",
                                sourceKey: "disc.src.caloric.source",
                                sourceFallback: "Institute of Medicine (IOM)",
                                urlString: "https://www.nationalacademies.org/",
                                descKey: "disc.src.caloric.desc",
                                descFallback: "Dietary Reference Intakes for energy and macronutrients"
                            )
                            
                            CitationView(
                                titleKey: "disc.src.foodsafety.title",
                                titleFallback: "Food Safety Information",
                                sourceKey: "disc.src.foodsafety.source",
                                sourceFallback: "FDA - U.S. Food and Drug Administration",
                                urlString: "https://www.fda.gov/food",
                                descKey: "disc.src.foodsafety.desc",
                                descFallback: "Food safety and nutrition labeling guidelines"
                            )
                            
                            CitationView(
                                titleKey: "disc.src.research.title",
                                titleFallback: "Nutritional Science Research",
                                sourceKey: "disc.src.research.source",
                                sourceFallback: "American Journal of Clinical Nutrition",
                                urlString: "https://academic.oup.com/ajcn",
                                descKey: "disc.src.research.desc",
                                descFallback: "Peer-reviewed research on nutrition and health"
                            )
                            
                            CitationView(
                                titleKey: "disc.src.composition.title",
                                titleFallback: "Food Composition Database",
                                sourceKey: "disc.src.composition.source",
                                sourceFallback: "USDA National Nutrient Database",
                                urlString: "https://www.ars.usda.gov/northeast-area/beltsville-md-bhnrc/beltsville-human-nutrition-research-center/methods-and-application-of-food-composition-laboratory/",
                                descKey: "disc.src.composition.desc",
                                descFallback: "Standard reference for nutrient content of foods"
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
                    
                    Text(lastUpdatedText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                }
                .padding()
            }
            .navigationTitle(loc("disc.nav", "Health Information"))
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
}

struct CitationView: View {
    let titleKey: String
    let titleFallback: String
    let sourceKey: String
    let sourceFallback: String
    let urlString: String
    let descKey: String
    let descFallback: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(loc(titleKey, titleFallback))
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(loc(sourceKey, sourceFallback))
                .font(.caption)
                .foregroundColor(.blue)
                .onTapGesture {
                    if let link = URL(string: urlString) {
                        UIApplication.shared.open(link)
                    }
                }
            
            Text(loc(descKey, descFallback))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HealthDisclaimerView()
} 