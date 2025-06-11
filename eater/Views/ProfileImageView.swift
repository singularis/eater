import SwiftUI

struct ProfileImageView: View {
    let profilePictureURL: String?
    let size: CGFloat
    let fallbackIconColor: Color
    let userName: String?
    let userEmail: String?
    
    init(profilePictureURL: String?, size: CGFloat = 80, fallbackIconColor: Color = .white, userName: String? = nil, userEmail: String? = nil) {
        self.profilePictureURL = profilePictureURL
        self.size = size
        self.fallbackIconColor = fallbackIconColor
        self.userName = userName
        self.userEmail = userEmail
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
                fallbackAvatarView
            }
        } else {
            // Show initials-based avatar or fallback icon
            fallbackAvatarView
        }
    }
    
    private var fallbackAvatarView: some View {
        ZStack {
            Circle()
                .fill(avatarBackgroundColor)
                .frame(width: size, height: size)
            
            if let initials = getInitials() {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(fallbackIconColor)
            }
        }
    }
    
    private var avatarBackgroundColor: Color {
        // Generate a consistent color based on user's email or name
        let seed = (userEmail ?? userName ?? "").hashValue
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .pink, .indigo, .teal]
        return colors[abs(seed) % colors.count]
    }
    
    private func getInitials() -> String? {
        if let name = userName, !name.isEmpty {
            let components = name.components(separatedBy: " ")
            let initials = components.compactMap { $0.first }.prefix(2)
            return String(initials).uppercased()
        } else if let email = userEmail, !email.isEmpty {
            let emailPrefix = email.components(separatedBy: "@")[0]
            return String(emailPrefix.prefix(2)).uppercased()
        }
        return nil
    }
}

#Preview {
    VStack(spacing: 20) {
        // Apple user with name - shows initials
        ProfileImageView(
            profilePictureURL: nil,
            userName: "John Apple",
            userEmail: "john@icloud.com"
        )
        
        // Apple user with only email - shows email initials
        ProfileImageView(
            profilePictureURL: nil,
            size: 60,
            userName: nil,
            userEmail: "apple.user@icloud.com"
        )
        
        // Google user with profile picture
        ProfileImageView(
            profilePictureURL: "https://lh3.googleusercontent.com/a/example",
            size: 40,
            fallbackIconColor: .blue,
            userName: "Google User",
            userEmail: "google@gmail.com"
        )
        
        // Fallback when no info available
        ProfileImageView(profilePictureURL: nil, size: 30)
    }
    .padding()
    .background(Color.black)
} 