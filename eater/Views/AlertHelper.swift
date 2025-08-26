import SwiftUI

class AlertHelper {
    static func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController
        else {
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

        alert.addAction(UIAlertAction(title: loc("common.ok", "OK"), style: .default) { _ in
            completion?()
        })
        
        // Find the topmost view controller that can present
        presentAlert(alert, from: rootViewController)
    }
    
    private static func presentAlert(_ alert: UIAlertController, from viewController: UIViewController, retryCount: Int = 0) {
        // Find a suitable view controller for presentation
        var presentingViewController = viewController
        
        // If the root view controller is presenting something, check if it's dismissing
        if let presentedVC = presentingViewController.presentedViewController {
            let presentedVCType = String(describing: type(of: presentedVC))
            
            // If it's a PresentationHostingController (SwiftUI sheet), dismiss it first then present alert
            if presentedVCType.contains("PresentationHostingController") {
                // Dismiss the sheet and then present the alert
                presentedVC.dismiss(animated: true) {
                    DispatchQueue.main.async {
                        viewController.present(alert, animated: true)
                    }
                }
                return
            } else {
                // For other presentations, traverse to the top
                presentingViewController = presentedVC
            }
        }
        
        // Check if we can present
        if presentingViewController.presentedViewController == nil {
            presentingViewController.present(alert, animated: true)
        } else {
            // If we've tried too many times, just present anyway on root
            if retryCount >= 4 {
                viewController.present(alert, animated: true)
                return
            }
            
            // Wait a bit and try again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                presentAlert(alert, from: viewController, retryCount: retryCount + 1)
            }
        }
    }
    
    private static func presentShareFriendsController(foodName: String, time: Int64, onShareSuccess: (() -> Void)?) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else { return }
        let vc = ShareFoodViewController(foodName: foodName, time: time)
        vc.onShareSuccess = onShareSuccess
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        rootViewController.present(nav, animated: true)
    }

    // Public helper to show the "Share food with friend" sheet directly
    static func showShareFriends(foodName: String, time: Int64, onShareSuccess: (() -> Void)? = nil) {
        presentShareFriendsController(foodName: foodName, time: time, onShareSuccess: onShareSuccess)
    }
    
    static func showHealthRecommendation(recommendation: String, completion: (() -> Void)? = nil) {
        let disclaimerText = "\n\n⚠️ HEALTH DISCLAIMER:\nThis information is for educational purposes only and should not replace professional medical advice. Consult your healthcare provider before making dietary changes.\n\nSources: USDA FoodData Central, Dietary Guidelines for Americans"
        
        let fullMessage = recommendation + disclaimerText
        
        showAlert(title: "Health Recommendation", message: fullMessage, completion: completion)
    }
    
    static func showPortionSelectionAlert(foodName: String, originalWeight: Int, time: Int64, onPortionSelected: @escaping (Int32) -> Void, onShareSuccess: (() -> Void)? = nil) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController
        else {
            print("Failed to get rootViewController to present the alert.")
            return
        }

        let alert = UIAlertController(
            title: loc("portion.modify.title", "Modify Portion"),
            message: String(format: loc("portion.modify.msg", "How much of '%@' did you actually eat?\nOriginal weight: %dg"), foodName, originalWeight),
            preferredStyle: .alert
        )

        // Add percentage options with calculated weights
        let portions = [
            (title: String(format: loc("portion.200", "200%% (%dg) - Double portion"), originalWeight * 2), percentage: Int32(200)),
            (title: String(format: loc("portion.150", "150%% (%dg) - One and a half portion"), originalWeight * 3 / 2), percentage: Int32(150)),
            (title: String(format: loc("portion.125", "125%% (%dg) - One and a quarter portion"), originalWeight * 5 / 4), percentage: Int32(125)),
            (title: String(format: loc("portion.75", "75%% (%dg) - Three quarters"), originalWeight * 3 / 4), percentage: Int32(75)),
            (title: String(format: loc("portion.50", "50%% (%dg) - Half portion"), originalWeight / 2), percentage: Int32(50)),
            (title: String(format: loc("portion.25", "25%% (%dg) - Quarter portion"), originalWeight / 4), percentage: Int32(25))
        ]

        for portion in portions {
            alert.addAction(UIAlertAction(title: portion.title, style: .default) { _ in
                onPortionSelected(portion.percentage)
            })
        }

        // Share food with friend action (visually highlighted)
        let shareTitle = loc("portion.share", "Share food with friend")
        let shareAction = UIAlertAction(title: shareTitle, style: .default) { _ in
            presentShareFriendsController(foodName: foodName, time: time, onShareSuccess: onShareSuccess)
        }
        // Make action title green (private API key path, commonly works in UIKit alerts)
        shareAction.setValue(UIColor.systemGreen, forKey: "titleTextColor")
        alert.addAction(shareAction)

        // Add custom option
        alert.addAction(UIAlertAction(title: loc("portion.custom", "Custom..."), style: .default) { _ in
            showCustomPortionAlert(foodName: foodName, originalWeight: originalWeight, onPortionSelected: onPortionSelected)
        })

        alert.addAction(UIAlertAction(title: loc("common.cancel", "Cancel"), style: .cancel))
        
        rootViewController.present(alert, animated: true)
    }
    
    static func showCustomPortionAlert(foodName: String, originalWeight: Int, onPortionSelected: @escaping (Int32) -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController
        else {
            print("Failed to get rootViewController to present the alert.")
            return
        }

        let customPortionVC = CustomPortionViewController(foodName: foodName, originalWeight: originalWeight, onPortionSelected: onPortionSelected)
        let navController = UINavigationController(rootViewController: customPortionVC)
        navController.modalPresentationStyle = .pageSheet
        
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        
        rootViewController.present(navController, animated: true)
    }
}

// Custom view controller for portion selection
private class CustomPortionViewController: UIViewController {
    private let foodName: String
    private let originalWeight: Int
    private let onPortionSelected: (Int32) -> Void
    private var scrollView: UIScrollView!
    private var stackView: UIStackView!
    
    init(foodName: String, originalWeight: Int, onPortionSelected: @escaping (Int32) -> Void) {
        self.foodName = foodName
        self.originalWeight = originalWeight
        self.onPortionSelected = onPortionSelected
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        title = loc("portion.custom.title", "Custom Portion")
        view.backgroundColor = .systemBackground
        
        // Add cancel button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        // Create scroll view and stack view
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        
        stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill
        stackView.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stackView.isLayoutMarginsRelativeArrangement = true
        
        // Add title label
        let titleLabel = UILabel()
        titleLabel.text = String(format: loc("portion.custom.msg", "Select the amount of '%@' you ate:\nOriginal weight: %dg"), foodName, originalWeight)
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        stackView.addArrangedSubview(titleLabel)
        
        // Add separator
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stackView.addArrangedSubview(separator)
        
        // Create percentage options from 10% to 300% in 10% increments
        let percentageOptions = stride(from: 10, through: 300, by: 10).map { Int32($0) }
        
        // Add percentage buttons with calculated weights
        for percentage in percentageOptions {
            let calculatedWeight = Int(Double(originalWeight) * Double(percentage) / 100.0)
            let button = UIButton(type: .system)
            button.setTitle("\(percentage)% (\(calculatedWeight)g)", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            button.layer.cornerRadius = 12
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
            button.heightAnchor.constraint(equalToConstant: 50).isActive = true
            
            button.tag = Int(percentage)
            button.addTarget(self, action: #selector(percentageButtonTapped(_:)), for: .touchUpInside)
            
            stackView.addArrangedSubview(button)
        }
        
        // Add views to hierarchy
        scrollView.addSubview(stackView)
        view.addSubview(scrollView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func percentageButtonTapped(_ sender: UIButton) {
        let percentage = Int32(sender.tag)
        dismiss(animated: true) { [weak self] in
            self?.onPortionSelected(percentage)
        }
    }
}
