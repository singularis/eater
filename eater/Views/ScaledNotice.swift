import SwiftUI

struct ScaledNoticeAction {
  enum Kind {
    case primary
    case secondary
    case destructive
  }

  var title: String
  var kind: Kind = .primary
  var action: () -> Void = {}
}

/// Dialog that follows the text-size slider. System alerts stay at 100%.
struct ScaledNotice: View {
  let title: String
  let message: String
  let actions: [ScaledNoticeAction]

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
    .background(AppTheme.backgroundGradient.ignoresSafeArea())
    .appInterfaceScale()
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }

  @ViewBuilder
  private func actionButton(_ item: ScaledNoticeAction) -> some View {
    let button = Button(item.title) {
      item.action()
      dismiss()
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
