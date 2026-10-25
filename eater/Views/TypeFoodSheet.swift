import SwiftUI

struct TypeFoodSheet: View {
  let timestampMillis: Int64?
  let onSuccess: () -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var text = ""
  @State private var isSubmitting = false

  private let characterLimit = 200

  private var trimmedText: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canSubmit: Bool {
    !trimmedText.isEmpty && !isSubmitting
  }

  private var examples: [String] {
    [
      loc("type_food.example_1", "rice and vegetables 200g"),
      loc("type_food.example_2", "apple 150g"),
      loc("type_food.example_3", "oatmeal with banana"),
    ]
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AppTheme.backgroundGradient
          .edgesIgnoringSafeArea(.all)

        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            Text(loc("type_food.intro", "Write one meal in your own words. No photo needed."))
              .font(.body)
              .foregroundColor(AppTheme.textPrimary)
              .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
              hint(icon: "text.cursor", text: loc("type_food.hint_name", "Name the food"))
              hint(
                icon: "scalemass",
                text: loc(
                  "type_food.hint_amount",
                  "Add the amount if you know it, such as 200g or 1 cup"))
              hint(
                icon: "sparkles",
                text: loc("type_food.hint_estimate", "We estimate the calories"))
            }

            VStack(alignment: .leading, spacing: 8) {
              Text(loc("type_food.examples", "Try an example"))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.textSecondary)

              ForEach(examples, id: \.self) { example in
                exampleButton(example)
              }
            }

            editor
          }
          .padding(20)
          .padding(.bottom, 8)
        }
        .safeAreaInset(edge: .bottom) {
          Button(action: submit) {
            HStack(spacing: 8) {
              if isSubmitting {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
              }
              Text(loc("type_food.submit", "Log meal"))
                .fontWeight(.semibold)
            }
          }
          .buttonStyle(PrimaryButtonStyle())
          .disabled(!canSubmit)
          .opacity(canSubmit ? 1 : 0.45)
          .padding(.horizontal, 20)
          .padding(.top, 8)
          .padding(.bottom, 12)
          .background(AppTheme.surface)
        }
      }
      .scaledNavTitle(loc("type_food.title", "Type food"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(loc("common.cancel", "Cancel")) {
            dismiss()
          }
          .disabled(isSubmitting)
        }
      }
      .onChange(of: text) { _, newValue in
        if newValue.count > characterLimit {
          text = String(newValue.prefix(characterLimit))
        }
      }
    }
  }

  private var editor: some View {
    VStack(alignment: .trailing, spacing: 6) {
      ZStack(alignment: .topLeading) {
        if text.isEmpty {
          Text(loc("type_food.placeholder", "What did you eat?"))
            .foregroundColor(AppTheme.textSecondary)
            .font(.body)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .allowsHitTesting(false)
        }

        TextEditor(text: $text)
          .font(.body)
          .foregroundColor(AppTheme.textPrimary)
          .scrollContentBackground(.hidden)
          .background(Color.clear)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .disabled(isSubmitting)
      }
      .frame(minHeight: 120)
      .background(AppTheme.surface)
      .appCorner(AppTheme.smallRadius)
      .overlay(
        RoundedRectangle(cornerRadius: AppTheme.smallRadius, style: .continuous)
          .stroke(AppTheme.divider, lineWidth: 1)
      )

      Text("\(text.count)/\(characterLimit)")
        .font(.caption)
        .foregroundColor(text.count >= characterLimit ? AppTheme.danger : AppTheme.textSecondary)
    }
  }

  private func hint(icon: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(AppTheme.primaryButtonFill)
        .frame(width: 22, alignment: .center)
        .padding(.top, 1)
      Text(text)
        .font(.subheadline)
        .foregroundColor(AppTheme.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func exampleButton(_ example: String) -> some View {
    let selected = trimmedText == example
    return Button {
      HapticsService.shared.select()
      text = example
    } label: {
      HStack(spacing: 12) {
        Text(example)
          .font(.subheadline.weight(.medium))
          .foregroundColor(AppTheme.textPrimary)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: selected ? "checkmark.circle.fill" : "plus.circle")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(AppTheme.primaryButtonFill)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(AppTheme.surface)
      .appCorner(AppTheme.smallRadius)
      .overlay(
        RoundedRectangle(cornerRadius: AppTheme.smallRadius, style: .continuous)
          .stroke(selected ? AppTheme.primaryButtonFill : AppTheme.divider, lineWidth: selected ? 1.5 : 1)
      )
    }
    .buttonStyle(PressScaleButtonStyle())
    .disabled(isSubmitting)
  }

  private func submit() {
    guard canSubmit else { return }
    HapticsService.shared.mediumImpact()
    isSubmitting = true
    GRPCService().sendFoodText(text: trimmedText, timestampMillis: timestampMillis) { success in
      DispatchQueue.main.async {
        isSubmitting = false
        if success {
          onSuccess()
        }
      }
    }
  }
}
