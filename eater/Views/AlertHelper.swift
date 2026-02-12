import SwiftUI

class AlertHelper {
  enum HapticKind {
    case success
    case warning
    case error
    case light
    case medium
    case heavy
    case select
  }

  private struct HealthSummaryItem: Codable {
    let ingredients: String?
    let ingredient: String?
    let description: String?
    let risk: String?
    let benefit: String?
    let impact: String?
    let impact_text: String?
  }

  /// Maps API English phrases to localization keys for health/ingredient modal
  private static let healthPhraseToKey: [String: String] = [
    "Wholesome fruit": "health.phrase.wholesome_fruit",
    "Mostly whole fruit with fiber and potassium.": "health.phrase.whole_fruit_fiber_potassium",
    "Nutrient rich": "health.phrase.nutrient_rich",
    "Potassium vitamin B6 fiber": "health.phrase.potassium_b6_fiber",
    "Natural sugar": "health.phrase.natural_sugar",
    "Sugar spike !": "health.phrase.sugar_spike",
    "Sugar spike!": "health.phrase.sugar_spike",
    "Raises blood sugar if overeat": "health.phrase.raises_blood_sugar",
    "Fiber and key nutrients": "health.phrase.fiber_and_nutrients",
    "Moderate natural sugar": "health.phrase.moderate_sugar",
    "High sodium": "health.phrase.high_sodium",
    "Ultra-processed": "health.phrase.ultra_processed",
    "Added sugars": "health.phrase.added_sugars",
    "Healthy fats": "health.phrase.healthy_fats",
    "Good protein source": "health.phrase.protein_source",
  ]

  /// Translates health/ingredient text from API (English) to current app language when we have a key
  private static func translateHealthText(_ text: String) -> String {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !t.isEmpty else { return text }
    if let key = healthPhraseToKey[t] {
      return loc(key, t)
    }
    return text
  }

  static func showAlert(
    title: String,
    message: String? = nil,
    attributedMessage: NSAttributedString? = nil,
    haptic: HapticKind? = nil,
    completion: (() -> Void)? = nil
  ) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first,
      let rootViewController = window.rootViewController
    else {
      completion?()
      return
    }

    // Trigger optional haptic prior to presenting the alert
    if let h = haptic {
      switch h {
      case .success: HapticsService.shared.success()
      case .warning: HapticsService.shared.warning()
      case .error: HapticsService.shared.error()
      case .light: HapticsService.shared.lightImpact()
      case .medium: HapticsService.shared.mediumImpact()
      case .heavy: HapticsService.shared.heavyImpact()
      case .select: HapticsService.shared.select()
      }
    }

    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

    if let attr = attributedMessage {
      alert.setValue(attr, forKey: "attributedMessage")
    } else if let attributedMessage = alert.message {
      let mutableAttributedMessage = NSMutableAttributedString(string: attributedMessage)

      let largerFontSize: CGFloat = 16

      mutableAttributedMessage.addAttribute(
        .font,
        value: UIFont.systemFont(ofSize: largerFontSize),
        range: NSRange(location: 0, length: mutableAttributedMessage.length)
      )

      alert.setValue(mutableAttributedMessage, forKey: "attributedMessage")
    }

    alert.addAction(
      UIAlertAction(title: loc("common.ok", "OK"), style: .default) { _ in
        completion?()
      })

    // Find the topmost view controller that can present
    presentAlert(alert, from: rootViewController)
  }

  static func showConfirmation(
    title: String,
    message: String? = nil,
    actions: [UIAlertAction],
    haptic: HapticKind? = nil
  ) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first,
      let rootViewController = window.rootViewController
    else {
      return
    }

    if let h = haptic {
      switch h {
      case .success: HapticsService.shared.success()
      case .warning: HapticsService.shared.warning()
      case .error: HapticsService.shared.error()
      case .light: HapticsService.shared.lightImpact()
      case .medium: HapticsService.shared.mediumImpact()
      case .heavy: HapticsService.shared.heavyImpact()
      case .select: HapticsService.shared.select()
      }
    }

    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    for action in actions {
      alert.addAction(action)
    }

    presentAlert(alert, from: rootViewController)
  }

  private static func presentAlert(
    _ alert: UIAlertController, from viewController: UIViewController, retryCount: Int = 0
  ) {
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

  private static func presentShareFriendsController(
    foodName: String, time: Int64, imageId: String = "", onShareSuccess: (() -> Void)?
  ) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first,
      let rootViewController = window.rootViewController
    else { return }
    let vc = ShareFoodViewController(foodName: foodName, time: time, imageId: imageId)
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
  static func showShareFriends(
    foodName: String, time: Int64, imageId: String = "", onShareSuccess: (() -> Void)? = nil
  ) {
    presentShareFriendsController(
      foodName: foodName, time: time, imageId: imageId, onShareSuccess: onShareSuccess)
  }

  static func showHealthRecommendation(recommendation: String, completion: (() -> Void)? = nil) {
    let header = loc("rec.disclaimer.title", "Important Health Disclaimer")
    let body = loc(
      "rec.disclaimer.text",
      "⚠️ This information is for educational purposes only and should not replace professional medical advice. Consult your healthcare provider before making dietary changes."
    )
    let sourcesLabel = loc("alert.health.sources.label", "Sources:")
    let sourceUSDA = loc("alert.health.sources.usda", "USDA FoodData Central")
    let sourceGuidelines = loc(
      "alert.health.sources.guidelines", "Dietary Guidelines for Americans")
    let disclaimerText =
      "\n\n" + header + "\n" + body + "\n\n" + sourcesLabel + " " + sourceUSDA + ", "
      + sourceGuidelines
    let fullMessage = recommendation + disclaimerText
    let title = loc("health.recommendation.title", "Health Recommendation")
    showAlert(title: title, message: fullMessage, completion: completion)
  }

  static func showHealthLevelInfo(title: String, description: String, healthSummary: String) {
    let header = loc("rec.disclaimer.title", "Important Health Disclaimer")
    let body = loc(
      "rec.disclaimer.text",
      "⚠️ This information is for educational purposes only and should not replace professional medical advice. Consult your healthcare provider before making dietary changes."
    )
    let displayTitle = translateHealthText(title)
    let displayDescription = translateHealthText(description)

    // Attempt to parse JSON healthSummary
    if let data = healthSummary.data(using: .utf8),
       let items = try? JSONDecoder().decode([HealthSummaryItem].self, from: data) {
      
      let fullStr = NSMutableAttributedString()
      
      fullStr.append(NSAttributedString(string: displayDescription + "\n\n", attributes: [
        .font: UIFont.systemFont(ofSize: 17),
        .foregroundColor: UIColor.secondaryLabel
      ]))
      
      for (index, item) in items.enumerated() {
        if index > 0 {
          fullStr.append(NSAttributedString(string: "\n"))
        }

        let name = item.ingredient ?? item.ingredients ?? ""
        if !name.isEmpty {
          fullStr.append(NSAttributedString(string: translateHealthText(name) + "\n", attributes: [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.label
          ]))
        }
        
        let impactText = item.impact_text ?? item.risk ?? item.benefit ?? ""
        if !impactText.isEmpty {
          let isRisk = (item.impact?.lowercased().contains("risk") ?? true) || item.risk != nil
          let color = isRisk ? UIColor.systemOrange : UIColor.systemGreen
          fullStr.append(NSAttributedString(string: translateHealthText(impactText) + "\n", attributes: [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: color
          ]))
        } else if let risk = item.risk, !risk.isEmpty {
          fullStr.append(NSAttributedString(string: translateHealthText(risk) + "\n", attributes: [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor.systemOrange
          ]))
        } else if let benefit = item.benefit, !benefit.isEmpty {
          fullStr.append(NSAttributedString(string: translateHealthText(benefit) + "\n", attributes: [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor.systemGreen
          ]))
        }
        
        if let desc = item.description, !desc.isEmpty {
          fullStr.append(NSAttributedString(string: translateHealthText(desc) + "\n", attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label
          ]))
        }
      }
      
      let disclaimer = "\n" + header + "\n" + body
      fullStr.append(NSAttributedString(string: disclaimer, attributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.secondaryLabel]))
      
      showAlert(title: displayTitle, attributedMessage: fullStr)
      return
    }
    
    let message = displayDescription + "\n\n" + healthSummary + "\n\n" + header + "\n" + body
    showAlert(title: displayTitle, message: message)
  }

  static func showPortionSelectionAlert(
    foodName: String,
    originalWeight: Int,
    time: Int64,
    imageId: String = "",
    isDrink: Bool,
    isFruitOrVegetable: Bool = false,
    onPortionSelected: @escaping (Int32) -> Void,
    onTryAgain: (() -> Void)? = nil,
    onAddSugar: (() -> Void)? = nil,
    onAddDrinkExtra: ((String) -> Void)? = nil,
    onAddFoodExtra: ((String) -> Void)? = nil,
    onShareSuccess: (() -> Void)? = nil
  ) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first,
      let rootViewController = window.rootViewController
    else {
      print("Failed to get rootViewController to present the alert.")
      return
    }

    let alert = UIAlertController(
      title: loc("portion.modify.title", "Modify Portion"),
      message: String(
        format: loc(
          "portion.modify.msg", "How much of '%@' did you actually eat?\nOriginal weight: %dg"),
        foodName, originalWeight),
      preferredStyle: .alert
    )

    // Add percentage options with calculated weights
    let portions = [
      (
        title: String(
          format: loc("portion.200", "200%% (%dg) - Double portion"), originalWeight * 2),
        percentage: Int32(200)
      ),
      (
        title: String(
          format: loc("portion.150", "150%% (%dg) - One and a half portion"), originalWeight * 3 / 2
        ), percentage: Int32(150)
      ),
      (
        title: String(
          format: loc("portion.125", "125%% (%dg) - One and a quarter portion"),
          originalWeight * 5 / 4), percentage: Int32(125)
        ),
      (
        title: String(
          format: loc("portion.75", "75%% (%dg) - Three quarters"), originalWeight * 3 / 4),
        percentage: Int32(75)
      ),
      (
        title: String(format: loc("portion.50", "50%% (%dg) - Half portion"), originalWeight / 2),
        percentage: Int32(50)
      ),
    ]

    for portion in portions {
      alert.addAction(
        UIAlertAction(title: portion.title, style: .default) { _ in
          onPortionSelected(portion.percentage)
        })
    }

    // Share food with friend action (visually highlighted)
    let shareTitle = loc("portion.share", "Share food with friend")
    let shareAction = UIAlertAction(title: shareTitle, style: .default) { _ in
      presentShareFriendsController(
        foodName: foodName, time: time, imageId: imageId, onShareSuccess: onShareSuccess)
    }
    // Make action title green (private API key path, commonly works in UIKit alerts)
    shareAction.setValue(UIColor.systemGreen, forKey: "titleTextColor")
    alert.addAction(shareAction)

    // Additional extras: not for fruit/vegetable; tap "Additional" to open submenu
    if !isFruitOrVegetable {
      let additionalTitle = loc("portion.additional", "Additional")
      let additionalAction = UIAlertAction(title: additionalTitle, style: .default) { _ in
          // Present a second alert (submenu) with extra options
          let additionalAlert = UIAlertController(
            title: additionalTitle,
            message: nil,
            preferredStyle: .alert
          )

          if isDrink {
            additionalAlert.addAction(
              UIAlertAction(title: loc("portion.extra.lemon", "Lemon 5g"), style: .default) { _ in
                onAddDrinkExtra?("lemon_5g")
              })
            additionalAlert.addAction(
              UIAlertAction(title: loc("portion.extra.honey", "Honey 10g"), style: .default) { _ in
                onAddDrinkExtra?("honey_10g")
              })
            let addSugarTitle = loc("portion.add_extra", "Add 1 tsp sugar ☕")
            additionalAlert.addAction(
              UIAlertAction(title: addSugarTitle, style: .default) { _ in
                onAddSugar?()
              })
          } else {
            additionalAlert.addAction(
              UIAlertAction(title: loc("portion.extra.soy", "Soy sauce 15g"), style: .default) { _ in
                onAddFoodExtra?("soy_sauce_15g")
              })
            additionalAlert.addAction(
              UIAlertAction(title: loc("portion.extra.wasabi", "Wasabi 3g"), style: .default) { _ in
                onAddFoodExtra?("wasabi_3g")
              })
            additionalAlert.addAction(
              UIAlertAction(title: loc("portion.extra.pepper", "Spicy pepper 5g"), style: .default) { _ in
                onAddFoodExtra?("spicy_pepper_5g")
              })
          }

          additionalAlert.addAction(
            UIAlertAction(title: loc("common.cancel", "Cancel"), style: .cancel, handler: nil))

          // Present after the first alert dismisses
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            rootViewController.present(additionalAlert, animated: true)
          }
        }
      // Yellow text for "Additional" (darker in Light Mode for readability)
      let additionalTitleColor = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
          return UIColor.systemYellow
        }
        // Amber-ish yellow that stays readable on white backgrounds
        return UIColor(red: 0.72, green: 0.52, blue: 0.00, alpha: 1.0)
      }
      additionalAction.setValue(additionalTitleColor, forKey: "titleTextColor")
      alert.addAction(additionalAction)
    }

    // Try manually – visible button between Share and Custom
    let tryManualTitle = loc("common.try_manual", "Try manually")
    let tryManualAction = UIAlertAction(title: tryManualTitle, style: .default) { _ in
      // Callback to allow user to manually fix dish name
      onTryAgain?()
    }
    // Orange for "Try manually"
    tryManualAction.setValue(UIColor.systemOrange, forKey: "titleTextColor")
    alert.addAction(tryManualAction)

    // Add custom option (purple)
    let customTitle = loc("portion.custom", "Custom grams...")
    let customAction = UIAlertAction(title: customTitle, style: .default) { _ in
      showCustomPortionAlert(
        foodName: foodName, originalWeight: originalWeight, onPortionSelected: onPortionSelected)
    }
    customAction.setValue(UIColor.systemPurple, forKey: "titleTextColor")
    alert.addAction(customAction)

    alert.addAction(UIAlertAction(title: loc("common.cancel", "Cancel"), style: .cancel))

    rootViewController.present(alert, animated: true)
  }

  static func showCustomPortionAlert(
    foodName: String, originalWeight: Int, onPortionSelected: @escaping (Int32) -> Void
  ) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first,
      let rootViewController = window.rootViewController
    else {
      print("Failed to get rootViewController to present the alert.")
      return
    }

    let customPortionVC = CustomPortionViewController(
      foodName: foodName, originalWeight: originalWeight, onPortionSelected: onPortionSelected)
    let navController = UINavigationController(rootViewController: customPortionVC)
    navController.modalPresentationStyle = .pageSheet

    if let sheet = navController.sheetPresentationController {
      sheet.detents = [.medium()]
      sheet.prefersGrabberVisible = true
    }

    rootViewController.present(navController, animated: true)
  }

  /// Generic text input alert helper (single text field)
  static func showTextInputAlert(
    title: String,
    message: String? = nil,
    placeholder: String,
    initialText: String = "",
    confirmTitle: String = "OK",
    keyboardType: UIKeyboardType = .default,
    onSubmit: @escaping (String) -> Void
  ) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first,
      let rootViewController = window.rootViewController
    else {
      return
    }

    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addTextField { textField in
      textField.placeholder = placeholder
      textField.text = initialText
      textField.keyboardType = keyboardType
    }

    let submitAction = UIAlertAction(title: confirmTitle, style: .default) { _ in
      let text =
        alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      guard !text.isEmpty else { return }
      onSubmit(text)
    }

    let cancelAction = UIAlertAction(
      title: loc("common.cancel", "Cancel"), style: .cancel, handler: nil)

    alert.addAction(submitAction)
    alert.addAction(cancelAction)

    presentAlert(alert, from: rootViewController)
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

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
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
      title: loc("common.cancel", "Cancel"),
      style: .plain,
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
    titleLabel.text = String(
      format: loc("portion.custom.msg", "Select the amount of '%@' you ate:\nOriginal weight: %dg"),
      foodName, originalWeight)
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
      let optionTitle = String(
        format: loc("portion.custom.option", "%d%% (%dg)"), percentage, calculatedWeight)
      button.setTitle(optionTitle, for: .normal)
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
      stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
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
