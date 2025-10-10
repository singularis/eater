import SwiftUI

struct EmptyStateView<Actions: View>: View {
  let systemImage: String
  let title: String
  let subtitle: String?
  @ViewBuilder var actions: Actions

  init(
    systemImage: String,
    title: String,
    subtitle: String? = nil,
    @ViewBuilder actions: () -> Actions
  ) {
    self.systemImage = systemImage
    self.title = title
    self.subtitle = subtitle
    self.actions = actions()
  }

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 48))
        .foregroundColor(AppTheme.textSecondary)

      Text(title)
        .font(.title3)
        .foregroundColor(AppTheme.textPrimary)

      if let subtitle = subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.subheadline)
          .foregroundColor(AppTheme.textSecondary)
          .multilineTextAlignment(.center)
      }

      actions
    }
    .frame(maxWidth: .infinity)
    .cardContainer(padding: 16)
  }
}

extension EmptyStateView where Actions == EmptyView {
  init(systemImage: String, title: String, subtitle: String? = nil) {
    self.init(systemImage: systemImage, title: title, subtitle: subtitle) { EmptyView() }
  }
}


