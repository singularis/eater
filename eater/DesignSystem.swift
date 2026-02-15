import SwiftUI
import UIKit

enum AppTheme {
  // Accent and system colors
  static var accent: Color { 
    colorScheme() == .light ? Color(red: 0.0, green: 0.78, blue: 0.85) : Color.cyan
  }
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
      ? Color(red: 0.4, green: 0.4, blue: 0.4)
      : Color(red: 0.7, green: 0.7, blue: 0.7)
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

  // Shadows - consistent and subtle
  static var cardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
    colorScheme() == .light
      ? (.black.opacity(0.1), 8, 0, 4)
      : (.black.opacity(0.3), 8, 0, 4)
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

  // Buttons - improved contrast and accessibility
  static var primaryButtonGradient: LinearGradient {
    if colorScheme() == .light {
      return LinearGradient(
        gradient: Gradient(colors: [
          Color(red: 0.0, green: 0.48, blue: 1.0),
          Color(red: 0.0, green: 0.78, blue: 0.85)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    } else {
      return LinearGradient(
        gradient: Gradient(colors: [
          Color(red: 0.1, green: 0.58, blue: 1.0),
          Color(red: 0.0, green: 0.88, blue: 0.95)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
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

struct PrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    let shadow = AppTheme.cardShadow
    return configuration.label
      .padding()
      .frame(maxWidth: .infinity)
      .background(
        ZStack {
           AppTheme.primaryButtonGradient
           // Liquid overlay
           RoundedRectangle(cornerRadius: 25, style: .continuous)
             .fill(.white.opacity(0.1))
             .blur(radius: 0.5)
        }
      )
      .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 25, style: .continuous)
          .stroke(AppTheme.liquidGlassStroke, lineWidth: 1.5)
      )
      .foregroundColor(.white)
      .shadow(
        color: configuration.isPressed ? shadow.color.opacity(0.3) : shadow.color,
        radius: shadow.radius,
        x: shadow.x,
        y: configuration.isPressed ? shadow.y - 2 : shadow.y
      )
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

struct GreenButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    let shadow = AppTheme.cardShadow
    return configuration.label
      .padding()
      .frame(maxWidth: .infinity)
      .background(
        ZStack {
           LinearGradient(
             colors: [Color(red: 0.2, green: 0.78, blue: 0.35), Color(red: 0.1, green: 0.62, blue: 0.3)],
             startPoint: .leading,
             endPoint: .trailing
           )
           // Liquid overlay
           RoundedRectangle(cornerRadius: 25, style: .continuous)
             .fill(.white.opacity(0.1))
             .blur(radius: 0.5)
        }
      )
      .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 25, style: .continuous)
          .stroke(AppTheme.liquidGlassStroke, lineWidth: 1.5)
      )
      .foregroundColor(.white)
      .shadow(
        color: configuration.isPressed ? shadow.color.opacity(0.3) : shadow.color,
        radius: shadow.radius,
        x: shadow.x,
        y: configuration.isPressed ? shadow.y - 2 : shadow.y
      )
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
      .background(
        ZStack {
          // Glass material
          Rectangle()
            .fill(.ultraThinMaterial)
          
          // Subtle tint for definition
          Rectangle()
            .fill(AppTheme.surface.opacity(0.3))
        }
      )
      .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
          .stroke(AppTheme.liquidGlassStroke, lineWidth: 1)
      )
      .shadow(color: shadow.color.opacity(0.5), radius: shadow.radius + 2, x: shadow.x, y: shadow.y)
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
    content
      .padding(paddingValue)
      .background(.ultraThinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(AppTheme.liquidGlassStroke, lineWidth: 1)
      )
      .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
  }
}

extension View {
  func cardContainer(padding: CGFloat = 12) -> some View {
    modifier(CardModifier(paddingValue: padding))
  }
  
  func liquidGlass(padding: CGFloat = 12, cornerRadius: CGFloat = AppTheme.cornerRadius) -> some View {
    modifier(LiquidGlassModifier(paddingValue: padding, cornerRadius: cornerRadius))
  }
}

// Secondary (neutral) button style
struct SecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding()
      .frame(maxWidth: .infinity)
      .background(
        ZStack {
          Rectangle()
            .fill(.ultraThinMaterial)
          Rectangle()
            .fill(AppTheme.surface.opacity(0.5))
        }
      )
      .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 25, style: .continuous)
          .stroke(AppTheme.liquidGlassStroke, lineWidth: 1)
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
    let gradient = LinearGradient(
      gradient: Gradient(colors: [AppTheme.danger.opacity(0.9), AppTheme.danger.opacity(0.7)]),
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    let shadow = AppTheme.cardShadow

    return configuration.label
      .padding()
      .frame(maxWidth: .infinity)
      .background(
        ZStack {
          gradient
          RoundedRectangle(cornerRadius: 25, style: .continuous)
            .fill(.white.opacity(0.1))
            .blur(radius: 0.5)
        }
      )
      .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 25, style: .continuous)
          .stroke(AppTheme.liquidGlassStroke, lineWidth: 1.5)
      )
      .foregroundColor(.white)
      .shadow(
        color: configuration.isPressed ? shadow.color.opacity(0.3) : shadow.color,
        radius: shadow.radius,
        x: shadow.x,
        y: configuration.isPressed ? shadow.y - 2 : shadow.y
      )
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


