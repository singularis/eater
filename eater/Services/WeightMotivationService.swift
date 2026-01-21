import Foundation

/// Service that provides motivational messages when users lose weight
class WeightMotivationService {
    
    static let shared = WeightMotivationService()
    private init() {}
    
    /// Key for storing the last recorded weight
    private let lastRecordedWeightKey = "lastRecordedWeight"
    
    /// Get the last recorded weight, or nil if not available
    var lastRecordedWeight: Float? {
        get {
            let weight = UserDefaults.standard.float(forKey: lastRecordedWeightKey)
            return weight > 0 ? weight : nil
        }
        set {
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: lastRecordedWeightKey)
            }
        }
    }
    
    /// Calculate weight loss rounded up to nearest 50g
    /// Returns the weight loss in grams if positive (user lost weight), nil otherwise
    func calculateWeightLoss(previousWeight: Float, newWeight: Float) -> Int? {
        let lossInGrams = (previousWeight - newWeight) * 1000
        guard lossInGrams > 0 else { return nil }
        
        // Round up to nearest 50g
        let roundedUp = Int(ceil(lossInGrams / 50.0)) * 50
        return roundedUp > 0 ? roundedUp : nil
    }
    
    /// Get a motivational message for the given weight loss in grams
    /// Returns a tuple of (title, message) for the alert
    func getMotivationalMessage(weightLossGrams: Int, languageCode: String) -> (title: String, message: String) {
        // Title showing the weight loss
        let title = getWeightLossTitle(grams: weightLossGrams, languageCode: languageCode)
        
        // Get a fun comparison based on the weight loss
        let comparison = getWeightComparison(grams: weightLossGrams, languageCode: languageCode)
        
        let message = comparison
        
        return (title, message)
    }
    
    private func getWeightLossTitle(grams: Int, languageCode: String) -> String {
        let localized = loc("weight.loss.title", "🎉 You Lost %dg!")
        return String(format: localized, grams)
    }
    
    /// Get a fun comparison for the weight loss amount
    private func getWeightComparison(grams: Int, languageCode: String) -> String {
        // Define comparisons for different weight ranges (in grams) - every 50g
        // Each comparison has a weight threshold and localization key with emojis
        let comparisons: [(minGrams: Int, maxGrams: Int, key: String, defaultText: String)] = [
            // 50g
            (50, 99, "weight.compare.50g", "🥚 That's the weight of a large egg! Great start!"),
            // 100g
            (100, 149, "weight.compare.100g", "🍎 That's the weight of a medium apple! Keep going!"),
            // 150g
            (150, 199, "weight.compare.150g", "🥝 That's the weight of a kiwi fruit! Nice progress!"),
            // 200g
            (200, 249, "weight.compare.200g", "🍌 That's the weight of a banana! You're doing great!"),
            // 250g
            (250, 299, "weight.compare.250g", "🍐 That's the weight of a pear! Awesome work!"),
            // 300g
            (300, 349, "weight.compare.300g", "🥤 That's the weight of a can of soda! Amazing!"),
            // 350g
            (350, 399, "weight.compare.350g", "🍊 That's the weight of a large orange! Fantastic!"),
            // 400g
            (400, 449, "weight.compare.400g", "🥭 That's the weight of a mango! Incredible!"),
            // 450g
            (450, 499, "weight.compare.450g", "🥔 That's the weight of a potato! Superb!"),
            // 500g
            (500, 549, "weight.compare.500g", "🧈 That's half a kilogram - like a butter pack! Wow!"),
            // 550g
            (550, 599, "weight.compare.550g", "🥥 That's the weight of a coconut! Outstanding!"),
            // 600g
            (600, 649, "weight.compare.600g", "🏀 That's the weight of a basketball! Brilliant!"),
            // 650g
            (650, 699, "weight.compare.650g", "🍇 That's the weight of a bunch of grapes! Excellent!"),
            // 700g
            (700, 749, "weight.compare.700g", "🍈 That's the weight of a small melon! Wonderful!"),
            // 750g
            (750, 799, "weight.compare.750g", "🍷 That's a bottle of wine! Cheers to your progress!"),
            // 800g
            (800, 849, "weight.compare.800g", "🍚 That's almost a kilogram of rice! Phenomenal!"),
            // 850g
            (850, 899, "weight.compare.850g", "📖 That's the weight of a thick book! Keep reading your success story!"),
            // 900g
            (900, 949, "weight.compare.900g", "💧 That's almost a liter of water! Refreshing progress!"),
            // 950g
            (950, 999, "weight.compare.950g", "🎾 That's about 15 tennis balls! You're a champion!"),
            // 1000g (1kg)
            (1000, 1249, "weight.compare.1kg", "🎂 That's a whole kilogram - like a bag of flour! Celebration time!"),
            // 1.25kg
            (1250, 1499, "weight.compare.1_25kg", "🍉 That's the weight of a small watermelon! Juicy progress!"),
            // 1.5kg
            (1500, 1749, "weight.compare.1_5kg", "💻 That's like carrying a laptop less! Lightening your load!"),
            // 1.75kg
            (1750, 1999, "weight.compare.1_75kg", "👟 That's like 3 pairs of running shoes! Sprint to success!"),
            // 2kg
            (2000, 2499, "weight.compare.2kg", "🏋️ That's like losing a small dumbbell! Strength in progress!"),
            // 2.5kg
            (2500, 2999, "weight.compare.2_5kg", "🐱 That's the weight of a cat! Feline good about this!"),
            // 3kg
            (3000, 3999, "weight.compare.3kg", "🥔 That's like a bag of potatoes - amazing progress! 🌟"),
            // 4kg
            (4000, 4999, "weight.compare.4kg", "👶 That's almost a newborn baby's weight! Incredible journey!"),
            // 5kg+
            (5000, Int.max, "weight.compare.5kg", "🎳 Incredible progress! That's like losing a bowling ball! 🏆"),
        ]
        
        // Find the matching comparison
        for comparison in comparisons {
            if grams >= comparison.minGrams && grams <= comparison.maxGrams {
                return loc(comparison.key, comparison.defaultText)
            }
        }
        
        // Fallback for very small amounts
        return loc("weight.compare.default", "💪 Every gram counts! Keep up the great work! 🌟")
    }
    
    /// Update the stored weight after a successful weight recording
    func updateLastRecordedWeight(_ weight: Float) {
        lastRecordedWeight = weight
    }
    
    /// Check if we should show a motivational message and return the weight loss in grams
    /// Returns nil if no motivation message should be shown (no previous weight or no loss)
    func checkAndUpdateForMotivation(newWeight: Float) -> Int? {
        guard let previousWeight = lastRecordedWeight else {
            // First time recording - just save the weight
            updateLastRecordedWeight(newWeight)
            return nil
        }
        
        // Calculate weight loss
        let weightLoss = calculateWeightLoss(previousWeight: previousWeight, newWeight: newWeight)
        
        // Always update the last recorded weight
        updateLastRecordedWeight(newWeight)
        
        return weightLoss
    }
}

