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
}
