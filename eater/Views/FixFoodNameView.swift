import SwiftUI

/// Sheet shown from the food card's "⋯" menu ("Try manually") to let the user
/// correct a misrecognized dish name. Offers LLM-suggested alternate names
/// (re-analyzed from the original photo) in addition to free text entry.
struct FixFoodNameView: View {
  @Environment(\.colorScheme) private var environmentColorScheme

  let currentName: String
  let imageId: String
  let languageCode: String
  let onSave: (String) -> Void
  let onCancel: () -> Void

  @State private var nameText: String = ""
  @State private var suggestions: [String] = []
  @State private var isLoadingSuggestions: Bool = true

  private var trimmedName: String {
    nameText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 8) {
            Text(loc("manual_food.title", "Fix food name"))
              .font(.title3.weight(.semibold))
              .foregroundColor(AppTheme.textPrimary)
            Text(loc(
              "manual_food.msg",
              "Enter the correct dish name. This will replace the current name in your log."
            ))
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
          }

          TextField(currentName, text: $nameText)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .autocapitalization(.words)
            .disableAutocorrection(false)

          suggestionsSection
        }
        .padding(20)
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(loc("common.cancel", "Cancel")) {
            onCancel()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(loc("common.save", "Save")) {
            guard !trimmedName.isEmpty else { return }
            onSave(trimmedName)
          }
          .disabled(trimmedName.isEmpty)
        }
      }
    }
    .onAppear {
      nameText = currentName
      fetchSuggestions()
    }
  }

  @ViewBuilder
  private var suggestionsSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(loc("manual_food.suggestions_title", "Suggested names"))
        .font(.subheadline.weight(.semibold))
        .foregroundColor(AppTheme.textPrimary)

      if isLoadingSuggestions {
        HStack(spacing: 8) {
          ProgressView()
          Text(loc("manual_food.suggestions_loading", "Looking for suggestions…"))
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
        }
      } else if suggestions.isEmpty {
        Text(loc(
          "manual_food.suggestions_empty",
          "No suggestions available. You can still type the name manually."
        ))
        .font(.caption)
        .foregroundColor(AppTheme.textSecondary)
      } else {
        FlowLayout(spacing: 8) {
          ForEach(suggestions, id: \.self) { suggestion in
            Button(action: {
              HapticsService.shared.select()
              nameText = suggestion
            }) {
              Text(suggestion)
                .font(.subheadline)
                .foregroundColor(
                  nameText == suggestion ? Color.white : AppTheme.textPrimary
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                  Capsule().fill(
                    nameText == suggestion ? AppTheme.accent : AppTheme.surfaceAlt)
                )
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private func fetchSuggestions() {
    isLoadingSuggestions = true
    GRPCService().suggestDishNames(
      imageId: imageId, currentName: currentName, languageCode: languageCode
    ) { result in
      DispatchQueue.main.async {
        self.suggestions = result.filter {
          $0.caseInsensitiveCompare(currentName) != .orderedSame
        }
        self.isLoadingSuggestions = false
      }
    }
  }
}

/// Simple wrapping layout for chip-style suggestion buttons.
private struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(
    proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) -> CGSize {
    let width = proposal.width ?? .infinity
    var rowWidth: CGFloat = 0
    var totalHeight: CGFloat = 0
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if rowWidth + size.width > width, rowWidth > 0 {
        totalHeight += rowHeight + spacing
        rowWidth = 0
        rowHeight = 0
      }
      rowWidth += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    totalHeight += rowHeight
    return CGSize(width: width, height: totalHeight)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var x = bounds.minX
    var y = bounds.minY
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > bounds.maxX, x > bounds.minX {
        x = bounds.minX
        y += rowHeight + spacing
        rowHeight = 0
      }
      subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}
