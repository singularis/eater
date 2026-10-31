# Eateria (iOS)

SwiftUI food tracker. Take a photo or type a meal and the backend returns calories, macros and a health score. Also tracks weight, activities and alcohol, and suggests meals from the past week.

## Requirements

- Xcode 26 with the iOS 26 SDK (Liquid Glass design). Deployment target is iOS 18.1.
- Google Sign-In client ID in `Info.plist`. Apple Sign-In capability in `eater/eater.entitlements`.

## Layout

- `eater/` all app code. The Xcode project uses synchronized folders, so files added here are compiled.
  - `Views/`, `Services/`, `Models/`, `DesignSystem.swift`, `ContentView.swift`
  - `Services/*.proto` and generated `*.pb.swift` for the HTTP + protobuf backend API
  - `Localization/` one JSON file per language, `en.json` is the source of keys
- `docs/PROJECT_KNOWLEDGE_BASE.md` architecture and gotchas, read this first
- `docs/AppStore_5.3.txt` App Store text for the current release
- `docs/postman/` Postman collection for the backend
- `scripts/sync-localization.py` adds missing keys from `en.json` to every language (`--check` to report only)
- `privacy-policy/` privacy policy text

## Build

Open `eater.xcodeproj`, pick the `eater` scheme, build and run.
