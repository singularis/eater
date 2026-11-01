import SwiftUI
import UIKit

struct ScaledNoticeAction {
  enum Kind {
    case primary
    case secondary
    case destructive
  }

  var title: String
  var kind: Kind = .primary
  /// Text color for secondary rows in long menus (portion menu share, additives, custom).
  var tint: Color? = nil
  var action: () -> Void = {}
}

/// Dialog that follows the text-size slider. System alerts stay at 100%.
struct ScaledNotice: View {
  let title: String
  let message: String
  let actions: [ScaledNoticeAction]
  /// Set when hosted from UIKit, where SwiftUI `dismiss` cannot close the controller.
  var onFinish: ((ScaledNoticeAction) -> Void)? = nil

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text(title)
          .font(.title3.weight(.semibold))
          .foregroundColor(AppTheme.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)

        if !message.isEmpty {
          Text(message)
            .font(.body)
            .foregroundColor(AppTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        VStack(spacing: 10) {
          ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
            actionButton(item)
          }
        }
        .padding(.top, 8)
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .appSheetBackground()
    .appInterfaceScale()
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .presentationContentInteraction(.resizes)
  }

  @ViewBuilder
  private func actionButton(_ item: ScaledNoticeAction) -> some View {
    let button = Button {
      if let onFinish {
        onFinish(item)
      } else {
        item.action()
        dismiss()
      }
    } label: {
      if let tint = item.tint {
        Text(item.title).foregroundColor(tint)
      } else {
        Text(item.title)
      }
    }
    switch item.kind {
    case .primary:
      button.buttonStyle(PrimaryButtonStyle())
    case .secondary:
      button.buttonStyle(SecondaryButtonStyle())
    case .destructive:
      button.buttonStyle(DestructiveButtonStyle())
    }
  }
}

extension View {
  func scaledNotice(
    _ title: String,
    isPresented: Binding<Bool>,
    message: String,
    actions: [ScaledNoticeAction]
  ) -> some View {
    sheet(isPresented: isPresented) {
      ScaledNotice(title: title, message: message, actions: actions)
    }
  }
}

/// Presents SwiftUI content from UIKit code paths (AlertHelper) so it follows the text-size slider.
enum ScaledHost {
  typealias Close = (_ then: @escaping () -> Void) -> Void

  static func makeController<Content: View>(
    detents: [UISheetPresentationController.Detent] = [.medium(), .large()],
    selectedDetent: UISheetPresentationController.Detent.Identifier? = nil,
    swipeToDismiss: Bool = true,
    onSwipeDismiss: (() -> Void)? = nil,
    @ViewBuilder content: (_ close: @escaping Close) -> Content
  ) -> UIViewController {
    weak var weakHost: UIViewController?
    let close: Close = { then in
      guard let host = weakHost else {
        then()
        return
      }
      host.dismiss(animated: true) { then() }
    }
    let settings = AppSettingsService.shared
    let host = SwipeDismissHostingController(
      rootView: AnyView(
        content(close)
          .preferredColorScheme(settings.scheme)
          .environmentObject(settings)
      )
    )
    weakHost = host
    host.view.backgroundColor = .clear
    host.modalPresentationStyle = .pageSheet
    host.isModalInPresentation = !swipeToDismiss
    host.onSwipeDismiss = onSwipeDismiss
    host.presentationController?.delegate = host
    if let sheet = host.sheetPresentationController {
      sheet.detents = detents
      sheet.prefersGrabberVisible = true
      if let selectedDetent {
        sheet.selectedDetentIdentifier = selectedDetent
      }
      // Drag lifts the sheet, same as the ingredient card. Scrolling starts after it is fully up.
      sheet.prefersScrollingExpandsWhenScrolledToEdge = true
    }
    return host
  }

  /// Opens at half height, swipe up for full height, swipe down closes.
  /// With one button, a swipe down counts as that button.
  static func notice(
    title: String,
    message: String,
    actions: [ScaledNoticeAction]
  ) -> UIViewController {
    let onlyAction = actions.count == 1 ? actions[0].action : nil
    return makeController(onSwipeDismiss: onlyAction) { close in
      ScaledNotice(title: title, message: message, actions: actions) { item in
        close { item.action() }
      }
    }
  }

  static func textPrompt(
    title: String,
    message: String,
    placeholder: String,
    keyboard: UIKeyboardType,
    onSubmit: @escaping (String) -> Void
  ) -> UIViewController {
    makeController(swipeToDismiss: true) { close in
      ScaledTextPrompt(
        title: title,
        message: message,
        placeholder: placeholder,
        keyboard: keyboard,
        onCancel: { close {} },
        onSubmit: { text in close { onSubmit(text) } }
      )
    }
  }

  /// UIKit screens with system fonts follow the slider through this text-size trait.
  static var contentSizeCategory: UIContentSizeCategory {
    switch AppSettingsService.shared.fontScale {
    case ..<0.88: return .small
    case ..<0.96: return .medium
    case ..<1.05: return .large
    case ..<1.15: return .extraLarge
    case ..<1.25: return .extraExtraLarge
    case ..<1.38: return .extraExtraExtraLarge
    case ..<1.55: return .accessibilityMedium
    default: return .accessibilityLarge
    }
  }
}

/// Reports a swipe-down dismissal, which skips the notice's own buttons.
final class SwipeDismissHostingController: UIHostingController<AnyView>,
  UIAdaptivePresentationControllerDelegate
{
  var onSwipeDismiss: (() -> Void)?

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    onSwipeDismiss?()
  }
}

/// One text field with Cancel / OK that follows the text-size slider.
struct ScaledTextPrompt: View {
  let title: String
  let message: String
  let placeholder: String
  let keyboard: UIKeyboardType
  let onCancel: () -> Void
  let onSubmit: (String) -> Void

  @State private var text = ""
  @FocusState private var focused: Bool

  private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text(title)
          .font(.title3.weight(.semibold))
          .foregroundColor(AppTheme.textPrimary)
          .fixedSize(horizontal: false, vertical: true)

        if !message.isEmpty {
          Text(message)
            .font(.body)
            .foregroundColor(AppTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        TextField(placeholder, text: $text)
          .keyboardType(keyboard)
          .focused($focused)
          .padding(.horizontal, 12)
          .frame(height: 44)
          .appSurface(cornerRadius: AppTheme.smallRadius)

        VStack(spacing: 10) {
          Button(loc("common.ok", "OK")) { onSubmit(trimmed) }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(trimmed.isEmpty)
            .opacity(trimmed.isEmpty ? 0.5 : 1)
          Button(loc("common.cancel", "Cancel")) { onCancel() }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.top, 8)
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .appSheetBackground()
    .appInterfaceScale()
    .onAppear { focused = true }
  }
}

/// Custom grams / percent picker from the portion menu.
struct CustomPortionSheet: View {
  let foodName: String
  let originalWeight: Int
  let onCancel: () -> Void
  let onSelect: (Int32, Double?) -> Void

  @State private var gramsText = ""
  @FocusState private var gramsFocused: Bool

  private var percentages: [Int32] { stride(from: 10, through: 300, by: 10).map { Int32($0) } }

  private var manualGrams: Double? {
    guard let grams = Double(gramsText.replacingOccurrences(of: ",", with: ".")), grams > 0 else {
      return nil
    }
    return grams
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          Text(String(
            format: loc("portion.custom.msg", "Select the amount of '%@' you ate:\nOriginal weight: %dg"),
            foodName, originalWeight))
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(AppTheme.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)

          HStack(spacing: 12) {
            TextField(loc("portion.custom.manual_placeholder", "e.g. 146.4"), text: $gramsText)
              .keyboardType(.decimalPad)
              .focused($gramsFocused)
              .padding(.horizontal, 12)
              .frame(height: 44)
              .appSurface(cornerRadius: AppTheme.smallRadius)

            Button(loc("common.apply", "Apply")) { applyManual() }
              .font(.system(size: 16, weight: .bold))
              .foregroundColor(.white)
              .lineLimit(1)
              .fixedSize()
              .padding(.horizontal, 16)
              .frame(height: 44)
              .background(AppTheme.accent)
              .appCorner(AppTheme.smallRadius)
              .opacity(manualGrams == nil ? 0.5 : 1)
              .disabled(manualGrams == nil)
          }

          ForEach(percentages, id: \.self) { percentage in
            Button {
              onSelect(percentage, nil)
            } label: {
              Text(String(
                format: loc("portion.custom.option", "%d%% (%dg)"),
                percentage, Int(Double(originalWeight) * Double(percentage) / 100.0)))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(AppTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(AppTheme.accent.opacity(0.1))
                .overlay(
                  RoundedRectangle(cornerRadius: AppTheme.smallRadius, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
                )
                .appCorner(AppTheme.smallRadius)
            }
            .buttonStyle(PressScaleButtonStyle())
          }
        }
        .padding(20)
      }
      .appSheetBackground()
      .scaledNavTitle(loc("portion.custom.title", "Custom Portion"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(loc("common.cancel", "Cancel")) { onCancel() }
        }
      }
    }
    .appInterfaceScale()
  }

  private func applyManual() {
    guard let grams = manualGrams else { return }
    gramsFocused = false
    let percentage = Int32(max(1, round((grams / Double(max(originalWeight, 1))) * 100.0)))
    onSelect(percentage, grams)
  }
}
