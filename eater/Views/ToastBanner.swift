import SwiftUI

struct ToastBanner: View {
  let message: String

  var body: some View {
    Text(message)
      .font(.subheadline.weight(.medium))
      .foregroundColor(.white)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(Color.black.opacity(0.82))
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .padding(.horizontal, 24)
      .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
  }
}
