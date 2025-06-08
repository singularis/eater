import SwiftUI

struct ProfileImageView: View {
    let profilePictureURL: String?
    let size: CGFloat
    let fallbackIconColor: Color
    
    init(profilePictureURL: String?, size: CGFloat = 80, fallbackIconColor: Color = .white) {
        self.profilePictureURL = profilePictureURL
        self.size = size
        self.fallbackIconColor = fallbackIconColor
    }
    
    var body: some View {
        if let urlString = profilePictureURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } placeholder: {
                // Show placeholder while loading
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(fallbackIconColor)
            }
        } else {
            // Fallback to generic icon when no profile picture URL is available
            Image(systemName: "person.circle.fill")
                .font(.system(size: size))
                .foregroundColor(fallbackIconColor)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfileImageView(profilePictureURL: nil)
        ProfileImageView(
            profilePictureURL: "https://lh3.googleusercontent.com/a/example",
            size: 60,
            fallbackIconColor: .blue
        )
    }
    .padding()
    .background(Color.black)
} 