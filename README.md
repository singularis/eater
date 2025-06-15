# Eater - Food Tracking iOS App

Eater is a modern iOS application built with SwiftUI that helps users track their food intake and maintain a healthy diet. The app features a clean, dark-themed interface and integrates with Google Sign-In for authentication.

## Features

- 📱 Modern SwiftUI interface with dark mode support
- 🔐 Google Sign-In authentication
- 📸 Food photo capture and analysis
- 📊 Daily calorie tracking
- ⚖️ Weight tracking
- 📅 Calendar view for historical data
- 🎯 Customizable calorie limits
- 👤 User profile management
- 🏥 Health data integration

## Technical Stack

- SwiftUI for the user interface
- Google Sign-In for authentication
- Core Data for local storage
- HealthKit integration
- Camera integration for food photos

## Project Structure

```
eater/
├── Views/           # SwiftUI view components
├── Services/        # Business logic and services
├── Models/          # Data models
├── Assets.xcassets/ # App assets and images
└── eaterApp.swift   # Main app entry point
```

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- Google Sign-In account and configuration

## Setup

1. Clone the repository
2. Open the project in Xcode
3. Configure Google Sign-In:
   - Add your Google Sign-In configuration to `config.plist`
   - Update the bundle identifier in Xcode
4. Build and run the project

## Features in Detail

### Authentication
- Secure Google Sign-In integration
- User profile management
- Persistent login state

### Food Tracking
- Capture food photos
- View food history
- Track daily calorie intake
- Set custom calorie limits
- View historical data

### Health Integration
- Weight tracking
- Health-based calorie calculations
- Health data synchronization

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- SwiftUI framework
- Google Sign-In SDK
- HealthKit framework 