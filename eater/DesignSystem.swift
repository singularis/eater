import SwiftUI
import UIKit

enum AppTheme {
  /// Solid primary fill. Blue reads as the one action, and holds white text contrast.
  static var primaryButtonFill: Color {
    colorScheme() == .light
      ? Color(red: 0.0, green: 0.42, blue: 0.82)
      : Color(red: 0.1, green: 0.58, blue: 1.0)
  }

  /// Interactive tint for buttons, fields, and alerts. Same as the action blue so
  /// light-theme controls stay readable on white (old cyan-on-white failed contrast).
  static var accent: Color { primaryButtonFill }
  static let success: Color = Color(red: 0.2, green: 0.78, blue: 0.35)
  static let warning: Color = Color(red: 1.0, green: 0.6, blue: 0.0)
  static let danger: Color = Color(red: 0.96, green: 0.26, blue: 0.21)

  // Nutrition palette - improved contrast
  static let macroProtein: Color = Color(red: 0.96, green: 0.26, blue: 0.21)
  static let macroFat: Color = Color(red: 1.0, green: 0.8, blue: 0.0)
  static let macroCarb: Color = Color(red: 0.2, green: 0.6, blue: 1.0)
  static let macroFiber: Color = Color(red: 0.2, green: 0.78, blue: 0.35)

  // Surfaces - improved contrast and readability
  static var surface: Color {
    colorScheme() == .light 
      ? Color.white.opacity(0.9) 
      : Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.95)
  }
  static var surfaceAlt: Color {
    colorScheme() == .light 
      ? Color.white.opacity(0.7) 
      : Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.8)
  }

  // Typography - improved contrast
  static var textPrimary: Color {
    colorScheme() == .light ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color.white
  }
  static var textSecondary: Color {
    colorScheme() == .light
      ? Color(red: 0.28, green: 0.28, blue: 0.30)
      : Color(red: 0.78, green: 0.78, blue: 0.80)
  }

  /// Soft label color for guest / trial sessions (comfortable, non-alarming).
  static var trialUsage: Color {
    colorScheme() == .light
      ? Color(red: 0.42, green: 0.55, blue: 0.62)
      : Color(red: 0.62, green: 0.72, blue: 0.78)
  }
  static var divider: Color {
    colorScheme() == .light 
      ? Color.black.opacity(0.12) 
      : Color.white.opacity(0.15)
  }

  // Layout
  static let cornerRadius: CGFloat = 16
  static let smallRadius: CGFloat = 12
  static let cardPadding: CGFloat = 16

  // Shadows - same weight on tiles, cards, and header circles
  static var cardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
    colorScheme() == .light
      ? (.black.opacity(0.08), 4, 0, 2)
      : (.black.opacity(0.28), 4, 0, 2)
  }

  // Backgrounds - improved modern gradients
  static var backgroundGradient: LinearGradient {
    if colorScheme() == .light {
      return LinearGradient(
        gradient: Gradient(colors: [
          Color(red: 0.98, green: 0.98, blue: 1.0),
          Color(red: 0.9, green: 0.95, blue: 1.0)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    } else {
      return LinearGradient(
        gradient: Gradient(colors: [
          Color(red: 0.05, green: 0.05, blue: 0.08),
          Color(red: 0.08, green: 0.1, blue: 0.15)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
  }

  /// Kept as a solid so leftover gradient callers stay flat.
  static var primaryButtonGradient: LinearGradient {
    LinearGradient(
      colors: [primaryButtonFill, primaryButtonFill],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  // Liquid Glass Styles
  static var liquidGlassStroke: LinearGradient {
    LinearGradient(
      colors: [
        .white.opacity(0.6),
        .white.opacity(0.1),
        .white.opacity(0.05)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private static func colorScheme() -> ColorScheme {
    if let scheme = AppSettingsService.shared.scheme {
      return scheme
    }
    // Fallback to system appearance by checking UITraitCollection
    return UIScreen.main.traitCollection.userInterfaceStyle == .light ? .light : .dark
  }
}

private struct FilledButtonChrome: ViewModifier {
  let fill: Color
  let isPressed: Bool

  func body(content: Content) -> some View {
    let shadow = AppTheme.cardShadow
    content
      .padding()
      .frame(maxWidth: .infinity)
      .background(fill)
      .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
      .foregroundColor(.white)
      .shadow(
        color: isPressed ? shadow.color.opacity(0.3) : shadow.color,
        radius: shadow.radius,
        x: shadow.x,
        y: isPressed ? shadow.y - 2 : shadow.y
      )
      .scaleEffect(isPressed ? 0.97 : 1.0)
      .transaction { t in
        if AppSettingsService.shared.reduceMotion { t.disablesAnimations = true }
      }
      .animation(
        AppSettingsService.shared.reduceMotion
          ? .none : .spring(response: 0.28, dampingFraction: 0.7, blendDuration: 0),
        value: isPressed
      )
  }
}

struct PrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.modifier(
      FilledButtonChrome(fill: AppTheme.primaryButtonFill, isPressed: configuration.isPressed)
    )
  }
}

struct GreenToPurpleButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.modifier(
      FilledButtonChrome(fill: AppTheme.primaryButtonFill, isPressed: configuration.isPressed)
    )
  }
}

struct GreenButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.modifier(
      FilledButtonChrome(fill: AppTheme.success, isPressed: configuration.isPressed)
    )
  }
}

struct PressScaleButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
      .transaction { t in
        if AppSettingsService.shared.reduceMotion { t.disablesAnimations = true }
      }
      .animation(
        AppSettingsService.shared.reduceMotion ? .none : .spring(response: 0.25, dampingFraction: 0.7),
        value: configuration.isPressed
      )
  }
}

// Unified card container modifier for surfaces
struct CardModifier: ViewModifier {
  let paddingValue: CGFloat

  func body(content: Content) -> some View {
    let shadow = AppTheme.cardShadow
    return content
      .padding(paddingValue)
      .background(AppTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
          .stroke(AppTheme.divider, lineWidth: 1)
      )
      .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
  }
}

struct LiquidGlassModifier: ViewModifier {
  let paddingValue: CGFloat
  let cornerRadius: CGFloat
  
  init(paddingValue: CGFloat = 12, cornerRadius: CGFloat = AppTheme.cornerRadius) {
    self.paddingValue = paddingValue
    self.cornerRadius = cornerRadius
  }

  func body(content: Content) -> some View {
    let shadow = AppTheme.cardShadow
    content
      .padding(paddingValue)
      .background(AppTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(AppTheme.divider, lineWidth: 1)
      )
      .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
  }
}

extension View {
  func cardContainer(padding: CGFloat = 12) -> some View {
    modifier(CardModifier(paddingValue: padding))
  }
  
  func liquidGlass(padding: CGFloat = 12, cornerRadius: CGFloat = AppTheme.cornerRadius) -> some View {
    modifier(LiquidGlassModifier(paddingValue: padding, cornerRadius: cornerRadius))
  }

  /// Flat panel used by Home tiles, date chip, and cards.
  func appSurface(cornerRadius: CGFloat = AppTheme.cornerRadius) -> some View {
    let shadow = AppTheme.cardShadow
    return self
      .background(AppTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(AppTheme.divider, lineWidth: 1)
      )
      .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
  }

  /// Same fill, stroke, and shadow as `appSurface`, for circular header chips.
  func appCircleSurface() -> some View {
    let shadow = AppTheme.cardShadow
    return self
      .background(AppTheme.surface)
      .clipShape(Circle())
      .overlay(Circle().stroke(AppTheme.divider, lineWidth: 1))
      .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
  }

  func appCardShadow() -> some View {
    let shadow = AppTheme.cardShadow
    return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
  }

  /// High-contrast input chrome. System rounded-border fields wash out on light theme.
  func appFormField() -> some View {
    modifier(AppFormFieldModifier())
  }
}

private struct AppFormFieldModifier: ViewModifier {
  @Environment(\.colorScheme) private var scheme

  func body(content: Content) -> some View {
    let fill =
      scheme == .light
      ? Color(red: 0.94, green: 0.95, blue: 0.97)
      : Color.white.opacity(0.10)
    let stroke =
      scheme == .light
      ? Color.black.opacity(0.22)
      : Color.white.opacity(0.28)

    content
      .foregroundColor(AppTheme.textPrimary)
      .tint(AppTheme.primaryButtonFill)
      .padding(.horizontal, 12)
      .padding(.vertical, 11)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(fill)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(stroke, lineWidth: 1)
      )
  }
}

// Secondary (neutral) button style
struct SecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding()
      .frame(maxWidth: .infinity)
      .background(AppTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
          .stroke(AppTheme.textSecondary.opacity(0.45), lineWidth: 1)
      )
      .foregroundColor(AppTheme.textPrimary)
      .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
      .transaction { t in
        if AppSettingsService.shared.reduceMotion { t.disablesAnimations = true }
      }
      .animation(
        AppSettingsService.shared.reduceMotion
          ? .none : .spring(response: 0.28, dampingFraction: 0.7, blendDuration: 0),
        value: configuration.isPressed)
  }
}

// Destructive (danger) button style
struct DestructiveButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.modifier(
      FilledButtonChrome(fill: AppTheme.danger, isPressed: configuration.isPressed)
    )
  }
}

/// Label + numeric field used by calorie limits and macro targets.
struct AppLabeledNumberField: View {
  let label: String
  let unit: String
  @Binding var text: String
  var keyboard: UIKeyboardType = .numberPad
  var placeholder: String = "0"

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(.subheadline.weight(.semibold))
        .foregroundColor(AppTheme.textPrimary)
      HStack(spacing: 8) {
        AppNumberTextField(text: $text, placeholder: placeholder, keyboard: keyboard)
          .frame(minHeight: 22)
          .appFormField()
        Text(unit)
          .font(.subheadline.weight(.medium))
          .foregroundColor(AppTheme.textPrimary)
          .frame(minWidth: 36, alignment: .leading)
      }
    }
  }
}

/// UIKit field so number-pad delete works. Focus selects the current value so
/// typing or one delete replaces the suggested target.
struct AppNumberTextField: UIViewRepresentable {
  @Binding var text: String
  var placeholder: String
  var keyboard: UIKeyboardType

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  func makeUIView(context: Context) -> UITextField {
    let tf = UITextField()
    tf.delegate = context.coordinator
    tf.keyboardType = keyboard
    tf.textAlignment = .right
    tf.placeholder = placeholder
    tf.font = UIFont.preferredFont(forTextStyle: .body)
    tf.adjustsFontForContentSizeCategory = true
    tf.clearButtonMode = .whileEditing
    tf.autocorrectionType = .no
    tf.spellCheckingType = .no
    tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
    tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    tf.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)

    let toolbar = UIToolbar()
    let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    let done = UIBarButtonItem(
      title: loc("common.done", "Done"),
      style: .done,
      target: context.coordinator,
      action: #selector(Coordinator.done)
    )
    toolbar.items = [flex, done]
    toolbar.sizeToFit()
    tf.inputAccessoryView = toolbar
    context.coordinator.field = tf
    return tf
  }

  func updateUIView(_ uiView: UITextField, context: Context) {
    context.coordinator.text = $text
    uiView.keyboardType = keyboard
    uiView.placeholder = placeholder
    uiView.textColor = UIColor(AppTheme.textPrimary)
    uiView.tintColor = UIColor(AppTheme.primaryButtonFill)
    if let scheme = AppSettingsService.shared.scheme {
      uiView.keyboardAppearance = scheme == .dark ? .dark : .light
    }
    if uiView.text != text {
      uiView.text = text
    }
  }

  final class Coordinator: NSObject, UITextFieldDelegate {
    var text: Binding<String>
    weak var field: UITextField?

    init(text: Binding<String>) {
      self.text = text
    }

    @objc func changed(_ sender: UITextField) {
      text.wrappedValue = sender.text ?? ""
    }

    @objc func done() {
      field?.resignFirstResponder()
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
      DispatchQueue.main.async {
        textField.selectAll(nil)
      }
    }

    func textField(
      _ textField: UITextField,
      shouldChangeCharactersIn range: NSRange,
      replacementString string: String
    ) -> Bool {
      if string.isEmpty { return true }
      let extra = (textField.keyboardType == .decimalPad) ? ".," : ""
      let allowed = CharacterSet(charactersIn: "0123456789" + extra)
      return string.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
  }
}


