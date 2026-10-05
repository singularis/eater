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

  var body: some View {
    NavigationStack {
      ZStack {
        AppTheme.backgroundGradient
          .edgesIgnoringSafeArea(.all)

        VStack(alignment: .leading, spacing: 16) {
          ZStack(alignment: .topLeading) {
            if text.isEmpty {
              Text(loc("type_food.placeholder", "beef steak 100g"))
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
          .frame(minHeight: 160)
          .background(AppTheme.surface)
          .cornerRadius(AppTheme.smallRadius)
          .overlay(
            RoundedRectangle(cornerRadius: AppTheme.smallRadius)
              .stroke(AppTheme.divider, lineWidth: 1)
          )

          Text("\(text.count)/\(characterLimit)")
            .font(.caption)
            .foregroundColor(text.count >= characterLimit ? AppTheme.danger : AppTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .trailing)

          Button(action: submit) {
            HStack(spacing: 8) {
              if isSubmitting {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
              }
              Text(loc("type_food.submit", "Submit"))
                .fontWeight(.semibold)
            }
          }
          .buttonStyle(PrimaryButtonStyle())
          .disabled(!canSubmit)
          .opacity(canSubmit ? 1 : 0.45)

          Spacer()
        }
        .padding(20)
      }
      .navigationTitle(loc("type_food.title", "Type food"))
      .navigationBarTitleDisplayMode(.inline)
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
