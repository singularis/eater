import SwiftUI

class AlertHelper {
    static func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController
        else {
            print("Failed to get rootViewController to present the alert.")
            completion?()
            return
        }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        if let attributedMessage = alert.message {
            let mutableAttributedMessage = NSMutableAttributedString(string: attributedMessage)

            let largerFontSize: CGFloat = 16

            mutableAttributedMessage.addAttribute(
                .font,
                value: UIFont.systemFont(ofSize: largerFontSize),
                range: NSRange(location: 0, length: mutableAttributedMessage.length)
            )

            alert.setValue(mutableAttributedMessage, forKey: "attributedMessage")
        }

        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        rootViewController.present(alert, animated: true)
    }
    
    static func showHealthRecommendation(recommendation: String, completion: (() -> Void)? = nil) {
        let disclaimerText = "\n\n⚠️ HEALTH DISCLAIMER:\nThis information is for educational purposes only and should not replace professional medical advice. Consult your healthcare provider before making dietary changes.\n\nSources: USDA FoodData Central, Dietary Guidelines for Americans"
        
        let fullMessage = recommendation + disclaimerText
        
        showAlert(title: "Health Recommendation", message: fullMessage, completion: completion)
    }
    
    static func showPortionSelectionAlert(foodName: String, onPortionSelected: @escaping (Int32) -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController
        else {
            print("Failed to get rootViewController to present the alert.")
            return
        }

        let alert = UIAlertController(
            title: "Modify Portion",
            message: "How much of '\(foodName)' did you actually eat?",
            preferredStyle: .alert
        )

        // Add percentage options
        let portions = [
            (title: "100% - Full portion", percentage: Int32(100)),
            (title: "75% - Three quarters", percentage: Int32(75)),
            (title: "50% - Half portion", percentage: Int32(50)),
            (title: "25% - Quarter portion", percentage: Int32(25))
        ]

        for portion in portions {
            alert.addAction(UIAlertAction(title: portion.title, style: .default) { _ in
                onPortionSelected(portion.percentage)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        rootViewController.present(alert, animated: true)
    }
}
