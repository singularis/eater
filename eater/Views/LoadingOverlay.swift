import SwiftUI

struct LoadingOverlay: View {
    let isVisible: Bool
    let message: String
    
    var body: some View {
        if isVisible {
            ZStack {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text(message)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .background(Color.black.opacity(0.8))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .animation(.easeInOut(duration: 0.3), value: isVisible)
        }
    }
}

#Preview {
    ZStack {
        Color.gray
        LoadingOverlay(isVisible: true, message: loc("loading.food", "Loading food data..."))
    }
} 