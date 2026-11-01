import SwiftUI

struct HealthComponentLine: Identifiable {
  let id: Int
  let name: String
  let note: String
  let isRisk: Bool
}

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
    // Ingredients (so modal uses app language)
    "Broccoli": "health.phrase.broccoli",
    "Carrot": "health.phrase.carrot",
    "Green bean": "health.phrase.green_bean",
    "Potato": "health.phrase.potato",
    "Vegetable oil": "health.phrase.vegetable_oil",
    "Salt": "health.phrase.salt",
    "Vegetables in general": "health.phrase.vegetables_general",
    "Lots of fiber and vitamins, but there is oil and salt.": "health.phrase.fiber_vitamins_oil_salt",
    "Antioxidants": "health.phrase.antioxidants",
    "Vision and skin": "health.phrase.vision_skin",
    "Vitamin A beta carotene": "health.phrase.vitamin_a_beta_carotene",
    "Vitamins C K folate": "health.phrase.vitamins_c_k_folate",
    "Satiety": "health.phrase.satiety",
    "Fiber folate vitamin C": "health.phrase.fiber_folate_vitamin_c",
    "Energy": "health.phrase.energy",
    "Potassium carbohydrates for energy": "health.phrase.potassium_carbs_energy",
    "Excess calories": "health.phrase.excess_calories",
    "High calorie content": "health.phrase.high_calorie",
    "Excess salt": "health.phrase.excess_salt",
    "May increase sodium": "health.phrase.may_increase_sodium",
    // Lowercase variants from API
    "broccoli": "health.phrase.broccoli",
    "carrot": "health.phrase.carrot",
    "green bean": "health.phrase.green_bean",
    "potato": "health.phrase.potato",
    "vegetable oil": "health.phrase.vegetable_oil",
    "salt": "health.phrase.salt",
  ]

  /// Strip candy emoji so we show a sugar concept without the candy symbol
  private static func stripCandyEmoji(_ s: String) -> String {
    s.replacingOccurrences(of: " 🍬", with: "").replacingOccurrences(of: "🍬", with: "")
  }

  /// Translates health/ingredient text from API (English) to current app language when we have a key
  private static func translateHealthText(_ text: String) -> String {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !t.isEmpty else { return text }
    let normalized = stripCandyEmoji(t)
    if let key = healthPhraseToKey[normalized] ?? healthPhraseToKey[t] {
      return stripCandyEmoji(loc(key, normalized))
    }
    return stripCandyEmoji(text)
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

    let notice = ScaledHost.notice(
      title: title,
      message: attributedMessage?.string ?? message ?? "",
      actions: [
        ScaledNoticeAction(title: loc("common.ok", "OK")) { completion?() },
      ]
    )
    presentController(notice, from: rootViewController)
  }

  static func showDailyLimitReached(isGuest: Bool, limit: Int) {
    let title = isGuest
      ? loc("quota.guest.title", "Daily limit reached")
      : loc("quota.user.title", "Daily limit reached")
    let message = String(
      format: isGuest
        ? loc("quota.guest.msg", "You've used your %d free scans today. Sign in to keep going.")
        : loc("quota.user.msg", "You've used your %d scans for today. Come back tomorrow."),
      limit
    )
    var actions: [ScaledNoticeAction] = []
    if isGuest {
      actions.append(
        ScaledNoticeAction(title: loc("quota.sign_in", "Sign in")) {
          DispatchQueue.main.async {
            AppNavigation.shared.showInPlaceLogin = true
          }
        }
      )
    }
    actions.append(
      ScaledNoticeAction(title: loc("common.ok", "OK"), kind: isGuest ? .secondary : .primary)
    )
    showConfirmation(title: title, message: message, actions: actions, haptic: .warning)
  }

  static func showConfirmation(
    title: String,
    message: String? = nil,
    actions: [ScaledNoticeAction],
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

    let notice = ScaledHost.notice(title: title, message: message ?? "", actions: actions)
    presentController(notice, from: rootViewController)
  }

  /// Full-screen celebration with simple confetti.
  static func showCelebration(
    title: String,
    message: String,
    primaryTitle: String,
    primaryAction: @escaping () -> Void,
    secondaryTitle: String = "",
    secondaryAction: (() -> Void)? = nil
  ) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first,
      let rootViewController = window.rootViewController
    else {
      return
    }

    HapticsService.shared.success()
    let vc = CelebrationViewController(
      titleText: title,
      messageText: message,
      primaryTitle: primaryTitle,
      primaryAction: primaryAction,
      secondaryTitle: secondaryTitle,
      secondaryAction: secondaryAction
    )
    presentController(vc, from: rootViewController)
  }

  private static func presentController(
    _ controller: UIViewController, from viewController: UIViewController, retryCount: Int = 0
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
            viewController.present(controller, animated: true)
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
      presentingViewController.present(controller, animated: true)
    } else {
      // If we've tried too many times, just present anyway on root
      if retryCount >= 4 {
        viewController.present(controller, animated: true)
        return
      }

      // Wait a bit and try again
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        presentController(controller, from: viewController, retryCount: retryCount + 1)
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
    nav.traitOverrides.preferredContentSizeCategory = ScaledHost.contentSizeCategory
    nav.modalPresentationStyle = .pageSheet
    if let sheet = nav.sheetPresentationController {
      sheet.detents = [.medium(), .large()]
      sheet.prefersGrabberVisible = true
    }
    rootViewController.present(nav, animated: true)
  }

  private static func presentLoginRequiredAlert(on rootViewController: UIViewController, message: String) {
    let loginNotice = ScaledHost.notice(
      title: loc("share.login_required.title", "Login Required"),
      message: message,
      actions: [
        ScaledNoticeAction(title: loc("login.prompt.confirm", "Login Now")) {
          AppNavigation.shared.showInPlaceLogin = true
        },
        ScaledNoticeAction(title: loc("common.not_yet", "Not Yet"), kind: .secondary),
      ]
    )
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      rootViewController.present(loginNotice, animated: true)
    }
  }

  // Public helper to show the "Share food with friend" sheet directly
  static func showShareFriends(
    foodName: String, time: Int64, imageId: String = "", onShareSuccess: (() -> Void)? = nil
  ) {
    presentShareFriendsController(
      foodName: foodName, time: time, imageId: imageId, onShareSuccess: onShareSuccess)
  }

  static func localizedHealthText(_ text: String) -> String {
    translateHealthText(text)
  }

  static func componentLines(healthSummary: String) -> [HealthComponentLine] {
    guard let data = healthSummary.data(using: .utf8),
      let items = try? JSONDecoder().decode([HealthSummaryItem].self, from: data)
    else {
      return []
    }
    return items.enumerated().compactMap { index, item in
      let name = translateHealthText(item.ingredient ?? item.ingredients ?? "")
      let impactText = item.impact_text ?? item.risk ?? item.benefit ?? ""
      let detail = translateHealthText(item.description ?? "")
      let note = [translateHealthText(impactText), detail]
        .filter { !$0.isEmpty }
        .joined(separator: " ")
      if name.isEmpty && note.isEmpty { return nil }
      let impact = item.impact?.lowercased() ?? ""
      let isRisk = impact.contains("risk") || ((item.risk?.isEmpty == false) && impact.isEmpty)
      return HealthComponentLine(id: index, name: name, note: note, isRisk: isRisk)
    }
  }

  static func showPortionSelectionAlert(
    foodName: String,
    originalWeight: Int,
    time: Int64,
    imageId: String = "",
    isDrink: Bool,
    isFruitOrVegetable: Bool = false,
    onPortionSelected: @escaping (Int32, Double?) -> Void,
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

    let isAnonymousUser = UserDefaults.standard.bool(forKey: "is_anonymous")
    let portions: [(title: String, percentage: Int32)] = [
      (String(format: loc("portion.200", "200%% (%dg) - Double portion"), originalWeight * 2), 200),
      (String(format: loc("portion.150", "150%% (%dg) - One and a half portion"), originalWeight * 3 / 2), 150),
      (String(format: loc("portion.125", "125%% (%dg) - One and a quarter portion"), originalWeight * 5 / 4), 125),
      (String(format: loc("portion.75", "75%% (%dg) - Three quarters"), originalWeight * 3 / 4), 75),
      (String(format: loc("portion.50", "50%% (%dg) - Half portion"), originalWeight / 2), 50),
    ]

    var actions: [ScaledNoticeAction] = portions.map { portion in
      ScaledNoticeAction(title: portion.title, kind: .secondary) {
        onPortionSelected(portion.percentage, nil)
      }
    }

    actions.append(
      ScaledNoticeAction(
        title: loc("portion.share", "Share food with friend"),
        kind: .secondary,
        tint: isAnonymousUser ? AppTheme.textSecondary : AppTheme.success
      ) {
        if isAnonymousUser {
          presentLoginRequiredAlert(
            on: rootViewController,
            message: loc(
              "share.login_required.message",
              "Create an account or log in to share food with friends."))
        } else {
          presentShareFriendsController(
            foodName: foodName, time: time, imageId: imageId, onShareSuccess: onShareSuccess)
        }
      })

    if !isFruitOrVegetable {
      let additionalTitle = loc("portion.additional", "Additives")
      let additionalTint = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor.systemYellow
          : UIColor(red: 0.72, green: 0.52, blue: 0.00, alpha: 1.0)
      })
      actions.append(
        ScaledNoticeAction(title: additionalTitle, kind: .secondary, tint: additionalTint) {
          let extras: [ScaledNoticeAction]
          if isDrink {
            extras = [
              ScaledNoticeAction(title: loc("portion.extra.lemon", "Lemon 5g"), kind: .secondary) {
                onAddDrinkExtra?("lemon_5g")
              },
              ScaledNoticeAction(title: loc("portion.extra.honey", "Honey 10g"), kind: .secondary) {
                onAddDrinkExtra?("honey_10g")
              },
              ScaledNoticeAction(title: loc("portion.extra.milk", "Milk 50g"), kind: .secondary) {
                onAddDrinkExtra?("milk_50g")
              },
              ScaledNoticeAction(title: loc("portion.add_extra", "Add 1 tsp sugar"), kind: .secondary) {
                onAddSugar?()
              },
            ]
          } else {
            extras = [
              ScaledNoticeAction(title: loc("portion.extra.soy", "Soy sauce 15g"), kind: .secondary) {
                onAddFoodExtra?("soy_sauce_15g")
              },
              ScaledNoticeAction(title: loc("portion.extra.wasabi", "Wasabi 3g"), kind: .secondary) {
                onAddFoodExtra?("wasabi_3g")
              },
              ScaledNoticeAction(title: loc("portion.extra.pepper", "Spicy pepper 5g"), kind: .secondary) {
                onAddFoodExtra?("spicy_pepper_5g")
              },
            ]
          }
          let submenu = ScaledHost.notice(
            title: additionalTitle,
            message: "",
            actions: extras + [ScaledNoticeAction(title: loc("common.cancel", "Cancel"), kind: .secondary)]
          )
          rootViewController.present(submenu, animated: true)
        })
    }

    actions.append(
      ScaledNoticeAction(
        title: imageId.isEmpty
          ? loc("manual_food.title", "Fix food name")
          : loc("common.try_manual", "Try manually"),
        kind: .secondary,
        tint: isAnonymousUser ? AppTheme.textSecondary : .orange
      ) {
        if isAnonymousUser {
          presentLoginRequiredAlert(
            on: rootViewController,
            message: loc(
              "manual_food.login_required.message",
              "Create an account or log in to manually fix or suggest food names."))
        } else {
          onTryAgain?()
        }
      })

    actions.append(
      ScaledNoticeAction(title: loc("portion.custom", "Custom grams"), kind: .secondary, tint: .purple) {
        showCustomPortionAlert(
          foodName: foodName, originalWeight: originalWeight, onPortionSelected: onPortionSelected)
      })

    actions.append(ScaledNoticeAction(title: loc("common.cancel", "Cancel"), kind: .secondary))

    let menu = ScaledHost.notice(
      title: loc("portion.modify.title", "Modify Portion"),
      message: String(
        format: loc(
          "portion.modify.msg", "How much of '%@' did you actually eat?\nOriginal weight: %dg"),
        foodName, originalWeight),
      actions: actions
    )
    rootViewController.present(menu, animated: true)
  }

  static func showCustomPortionAlert(
    foodName: String, originalWeight: Int, onPortionSelected: @escaping (Int32, Double?) -> Void
  ) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first,
      let rootViewController = window.rootViewController
    else {
      print("Failed to get rootViewController to present the alert.")
      return
    }

    let controller = ScaledHost.makeController(swipeToDismiss: true) { close in
      CustomPortionSheet(
        foodName: foodName,
        originalWeight: originalWeight,
        onCancel: { close {} },
        onSelect: { percentage, grams in
          close { onPortionSelected(percentage, grams) }
        }
      )
    }
    rootViewController.present(controller, animated: true)
  }

}

private final class CelebrationViewController: UIViewController {
  private let titleText: String
  private let messageText: String
  private let primaryTitle: String
  private let primaryAction: () -> Void
  private let secondaryTitle: String
  private let secondaryAction: (() -> Void)?

  private var emitter: CAEmitterLayer?

  init(
    titleText: String,
    messageText: String,
    primaryTitle: String,
    primaryAction: @escaping () -> Void,
    secondaryTitle: String,
    secondaryAction: (() -> Void)?
  ) {
    self.titleText = titleText
    self.messageText = messageText
    self.primaryTitle = primaryTitle
    self.primaryAction = primaryAction
    self.secondaryTitle = secondaryTitle
    self.secondaryAction = secondaryAction
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .overFullScreen
    modalTransitionStyle = .crossDissolve
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.black.withAlphaComponent(0.55)

    let card = UIView()
    card.backgroundColor = UIColor.systemBackground
    card.layer.cornerRadius = 18
    card.translatesAutoresizingMaskIntoConstraints = false

    let titleLabel = UILabel()
    titleLabel.text = titleText
    titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
    titleLabel.textAlignment = .center
    titleLabel.numberOfLines = 0
    titleLabel.translatesAutoresizingMaskIntoConstraints = false

    let messageLabel = UILabel()
    messageLabel.text = messageText
    messageLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
    messageLabel.textAlignment = .center
    messageLabel.numberOfLines = 0
    messageLabel.textColor = UIColor.secondaryLabel
    messageLabel.translatesAutoresizingMaskIntoConstraints = false

    let primary = UIButton(type: .system)
    primary.setTitle(primaryTitle, for: .normal)
    primary.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
    primary.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
    primary.layer.cornerRadius = 12
    primary.translatesAutoresizingMaskIntoConstraints = false
    primary.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)

    let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, primary])
    stack.axis = .vertical
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false

    if !secondaryTitle.isEmpty, let _ = secondaryAction {
      let secondary = UIButton(type: .system)
      secondary.setTitle(secondaryTitle, for: .normal)
      secondary.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
      secondary.translatesAutoresizingMaskIntoConstraints = false
      secondary.addTarget(self, action: #selector(secondaryTapped), for: .touchUpInside)
      stack.addArrangedSubview(secondary)
    }

    card.addSubview(stack)
    view.addSubview(card)

    NSLayoutConstraint.activate([
      card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      card.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
      card.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
      card.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),

      stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
      stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
      stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),

      primary.heightAnchor.constraint(equalToConstant: 44),
    ])

    let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(swipedDown))
    swipeDown.direction = .down
    view.addGestureRecognizer(swipeDown)

    startConfetti()
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      self?.stopConfetti()
    }
  }

  @objc private func swipedDown() {
    dismiss(animated: true)
  }

  private func startConfetti() {
    let emitter = CAEmitterLayer()
    emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: -10)
    emitter.emitterShape = .line
    emitter.emitterSize = CGSize(width: view.bounds.size.width, height: 2)

    func cell(color: UIColor) -> CAEmitterCell {
      let c = CAEmitterCell()
      c.birthRate = 10
      c.lifetime = 6.0
      c.velocity = 180
      c.velocityRange = 60
      c.emissionLongitude = .pi
      c.emissionRange = .pi / 8
      c.spin = 3
      c.spinRange = 2
      c.scale = 0.04
      c.scaleRange = 0.02
      c.color = color.cgColor
      c.contents = UIImage(systemName: "circle.fill")?.withTintColor(color, renderingMode: .alwaysOriginal).cgImage
      return c
    }

    emitter.emitterCells = [
      cell(color: .systemPink),
      cell(color: .systemYellow),
      cell(color: .systemTeal),
      cell(color: .systemPurple),
      cell(color: .systemOrange),
    ]

    view.layer.insertSublayer(emitter, at: 0)
    self.emitter = emitter
  }

  private func stopConfetti() {
    emitter?.birthRate = 0
  }

  @objc private func primaryTapped() {
    dismiss(animated: true) { [primaryAction] in primaryAction() }
  }

  @objc private func secondaryTapped() {
    dismiss(animated: true) { [secondaryAction] in secondaryAction?() }
  }
}

// Custom view controller for portion selection
