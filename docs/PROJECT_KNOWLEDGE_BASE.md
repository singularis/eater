# Eateria (Eater) — iOS App Project Knowledge Base

> **Purpose:** Quick-start reference for AI agents working on this codebase. Read this first to save tokens and context.

---

## 1. What Is This App?

**Eateria** is a SwiftUI iOS food-tracking app. Users photograph food, and an LLM-powered backend analyzes it to estimate calories, macros, and health ratings. The app also tracks weight (via scale photos or manual entry), activities (including chess), alcohol consumption, and provides LLM-generated dietary recommendations.

- **Bundle ID:** `com.singularis.eater`
- **Display Name:** Eateria
- **Minimum iOS:** 15.0+
- **Language:** Swift 5.5+, SwiftUI
- **Current version:** 4.0

---

## 2. Project Root Layout

```
/Users/dante/Documents/dante/Documents/eater/
├── eater/                    ← Main iOS app source (THE code you'll edit)
│   ├── eaterApp.swift        ← @main entry point
│   ├── ContentView.swift     ← Main screen (~2100 lines, the heart of the UI)
│   ├── DesignSystem.swift    ← Design tokens, colors, button styles
│   ├── Views/                ← 32 SwiftUI view files
│   ├── Services/             ← 53 files: business logic, networking, proto files
│   ├── Models/               ← Product.swift, DailyStatistics.swift
│   ├── Localization/         ← 36 language JSON files + quotes/
│   ├── Assets.xcassets/      ← Images, colors, app icon
│   ├── .docs/                ← BACKEND_AUTH_IMPLEMENTATION.md, BACKEND_MIGRATION_GUIDE.md
│   ├── config.plist          ← Currently empty dict (placeholder)
│   └── eater.entitlements    ← Apple Sign-In capability
├── eater.xcodeproj/          ← Xcode project (primary)
├── 1eater.xcodeproj/         ← Secondary/old Xcode project (ignore)
├── Info.plist                ← App config: Google Client ID, camera/photo permissions, ATS
├── scripts/                  ← apple_submission.md, image resize scripts
├── src/                      ← Empty placeholder dirs (components, models, screens, services)
├── privacy-policy/           ← Privacy policy content
├── AppStore_Release_Notes_4.0.md ← Localized release notes for v4.0
└── README.md                 ← High-level project description
```

> [!IMPORTANT]
> The `src/` directory is empty — all source code lives under `eater/`. The `eater 2025-*` directories are Xcode archive snapshots (ignore them).

---

## 3. Architecture Overview

### App Entry (`eaterApp.swift`)
```
@main AppNameApp
  ├── if authenticated → ContentView (main app)
  └── else → LoginView (sign-in screen)
```
- `AuthenticationService` is a `@StateObject` — injected as `@EnvironmentObject` everywhere
- `LanguageService.shared` and `AppSettingsService.shared` are also injected as `@EnvironmentObject`
- Color scheme controlled by `AppSettingsService.shared.scheme`

### Authentication Flow
1. User taps "Sign in with Google" or "Sign in with Apple" on `LoginView`
2. `AuthenticationService` gets provider ID token
3. Sends `POST /eater_auth` with `{ provider, idToken, email, name, profilePictureURL }`
4. Backend verifies token with provider, issues HS256 JWT
5. JWT stored in **Keychain** (via `KeychainHelper`), user info in `UserDefaults`
6. Client only checks JWT structure + expiration — **never verifies signature**

> [!CAUTION]
> **No JWT secret in the client.** The old hardcoded secret was removed. Backend-only signing.

### Networking Pattern
- **`GRPCService`** (1356 lines) — despite the name, uses **HTTP REST + Protobuf serialization**, NOT actual gRPC
- Base URL switching via `AppEnvironment`:
  - **Production:** `https://chater.singularis.work`
  - **Dev:** `http://192.168.0.10:30601/dev` (local network)
- Auth header: `Bearer <JWT>` from Keychain on every request
- Retry logic: exponential backoff, max 10 retries
- Content types: `application/protobuf` for most endpoints, `application/json` for newer ones (nickname, chess, activity, goal)

### Data Flow (Main Screen)
```
ContentView.onAppear → fetchDataWithLoading()
  → ProductStorageService.fetchAndProcessProducts()
    → check local cache (UserDefaults, 60-min TTL)
    → if stale → GRPCService().fetchProducts() [GET /eater_get_today]
      → TodayFood protobuf → [Product] array
    → save to local cache
  → update UI state: products, caloriesLeft, personWeight, macros
```

---

## 4. Key Files Quick Reference

### Core UI
| File | Lines | Purpose |
|------|-------|---------|
| `ContentView.swift` | ~2100 | Main screen: product list, stats bar, camera button, macros, calendar |
| `LoginView.swift` | 83 | Sign-in screen (Google + Apple buttons) |
| `OnboardingView.swift` | ~88K bytes | Multi-mode onboarding (initial, health, social) |
| `ActivitiesView.swift` | ~56K bytes | Activity tracking (chess, sports) |
| `StatisticsView.swift` | ~21K bytes | Charts and statistics visualization |
| `UserProfileView.swift` | ~34K bytes | Profile, settings, theme selection |
| `HealthSettingsView.swift` | ~29K bytes | Health data input and calorie calculations |
| `ProductListView.swift` | ~5K | Scrollable list of today's food items |
| `ProductRowView.swift` | ~13K | Individual food item card |
| `CameraButtonView.swift` | ~21K | Camera capture + multi-photo + food entry |

### Services
| File | Purpose |
|------|---------|
| `GRPCService.swift` | All backend API calls (REST+Protobuf). 1356 lines. |
| `AuthenticationService.swift` | Google/Apple sign-in, JWT management, Keychain storage |
| `AppEnvironment.swift` | URL switching: prod vs dev environment |
| `AppSettingsService.swift` | User preferences (appearance, reduce motion, photo save) |
| `ThemeService.swift` | Mascot system (cat/dog/none), sounds, motivational messages |
| `LanguageService.swift` | 36-language support, runtime language switching |
| `Localization.swift` | Translation lookup: `loc("key", "default")` global function |
| `ProductStorageService.swift` | Local cache for products (UserDefaults) + health level cache |
| `ImageStorageService.swift` | Local food photo storage and retrieval |
| `StatisticsService.swift` | Statistics data fetching with cache |
| `StatisticsCacheService.swift` | Cache layer for statistics data |
| `NotificationService.swift` | Meal reminders (breakfast 12:00, lunch 17:00, dinner 21:00) |
| `HapticsService.swift` | Haptic feedback wrapper |
| `KeychainHelper.swift` | iOS Keychain read/write for auth token |
| `FoodExtrasStore.swift` | Extra food items (sugar, lemon, wasabi, soy sauce, etc.) |
| `CalorieLimitsStorageService.swift` | Calorie limit persistence |
| `WeightMotivationService.swift` | Motivational messages after weight logging |
| `FriendsSearchWebSocket.swift` | WebSocket for friend search autocomplete |

### Models
| File | Purpose |
|------|---------|
| `Product.swift` | Food item: time, name, calories, weight, ingredients, healthRating, imageId, extras |
| `DailyStatistics.swift` | Daily aggregate: calories, macros, weight, meal count |

### Protobuf Files (in `Services/`)
Proto files define request/response formats: `today_food.proto`, `photo_message.proto`, `delete_food.proto`, `custom_date_food.proto`, `feedback.proto`, `modify_food_record.proto`, `share_food.proto`, `add_friend.proto`, `get_friends.proto`, `get_recomendation.proto`, `manual_weight.proto`, `delete_user.proto`, `food_health_level.proto`, `set_language.proto`, `alcohol.proto`, `multiple_photos.proto`

---

## 5. Backend API Endpoints

All requests include `Authorization: Bearer <JWT>` header.

### Protobuf Endpoints (Content-Type: application/protobuf)
| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/eater_get_today` | Fetch today's food list + calories + weight |
| POST | `/eater_receive_photo` | Upload food/weight photo for LLM analysis |
| POST | `/delete_food` | Delete a food entry by timestamp |
| POST | `/get_food_custom_date` | Fetch food for a specific date (dd-MM-yyyy) |
| POST | `/get_recommendation` | Get LLM dietary recommendation |
| POST | `/modify_food_record` | Modify portion, retry LLM analysis, add sugar |
| POST | `/manual_weight` | Submit manual weight entry |
| POST | `/delete_user` | Delete user account |
| POST | `/feedback` | Submit user feedback |
| POST | `/food_health_level` | Get detailed health analysis for a food item |
| POST | `/set_language` | Set user's preferred language |
| GET | `/alcohol_latest` | Get latest alcohol event |
| POST | `/alcohol_range` | Get alcohol events in date range |

### JSON Endpoints (Content-Type: application/json)
| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/eater_auth` | Authentication (exchange provider token for JWT) |
| POST | `/modify_food_manual` | Rename food without re-analyzing |
| POST | `/nickname_update` | Update user nickname |
| POST | `/goal_update` | Set weight goal and calorie target |
| POST | `/activity_log` | Log an activity (sport, chess) |
| GET | `/activity_summary?date=` | Get activity summary for a date |
| POST | `/record_chess_game` | Record chess match result |

### Social Endpoints (via `autocomplete` base URL)
| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/autocomplete/addfriend` | Add friend (protobuf) |
| GET | `/autocomplete/getfriend` | Get friends list (protobuf) |
| POST | `/autocomplete/sharefood` | Share food with friend (protobuf) |
| POST | `/autocomplete/get_chess_stats` | Get chess stats (JSON) |
| GET | `/autocomplete/get_chess_history` | Get chess game history (JSON) |
| GET | `/autocomplete/get_all_chess_data` | Get all chess data (JSON) |
| WS | `/autocomplete` | WebSocket for friend search |

---

## 6. Design System

Defined in `DesignSystem.swift`:

- **Theme:** Supports light and dark mode (controlled by `AppSettingsService.appearance`)
- **Key colors:** `AppTheme.accent` (cyan), `.success` (green), `.warning` (orange), `.danger` (red)
- **Surfaces:** `AppTheme.surface`, `.surfaceAlt` — glassmorphism style
- **Layout:** `cornerRadius: 16`, `smallRadius: 12`, `cardPadding: 16`
- **Button styles:** `PrimaryButtonStyle`, `GreenButtonStyle`, `GreenToPurpleButtonStyle`, `SecondaryButtonStyle`, `DestructiveButtonStyle`, `PressScaleButtonStyle`
- **Modifiers:** `.cardContainer()`, `.liquidGlass()` — unified card/glass appearance
- **Animations:** Spring-based with `reduceMotion` accessibility support

### Mascot/Theme System (`ThemeService`)
- Three mascots: `.none` (default), `.cat` (British cat), `.dog` (French bulldog)
- Each mascot has states: `.happy`, `.angry`, `.badFood`, `.gym`, `.alcohol`
- Mascot-specific icon remapping (e.g., flame → fish for cat theme)
- Sound effects per mascot (purr/hiss for cat, woof/growl for dog)
- Image rotation per state for variety

---

## 7. Localization System

- **36 languages** supported via JSON files in `Localization/` directory
- Global function: `loc("key", "fallback")` — defined in `Localization.swift`
- `LanguageService.shared` manages current language, persists to `UserDefaults`
- Language change syncs with backend via `GRPCService().setLanguage()`
- Food name translation via `Localization.translateFoodName()`
- Localized food quotes for notifications in `Localization/quotes/`

---

## 8. Local Storage Patterns

| What | Where | Key(s) |
|------|-------|--------|
| Auth JWT | **Keychain** | `"auth_token"` |
| User email | UserDefaults | `"user_email"` |
| User name | UserDefaults | `"user_name"` |
| Profile picture URL | UserDefaults | `"profile_picture_url"` |
| Cached products | UserDefaults | `"cached_products"` (JSON encoded) |
| Cached calories | UserDefaults | `"cached_calories"` |
| Cached weight | UserDefaults | `"cached_weight"` |
| Calorie limits | UserDefaults | `"softLimit"`, `"hardLimit"` |
| Onboarding state | UserDefaults | `"hasSeenOnboarding"`, `"hasSeenXxxTutorial"` |
| Language | UserDefaults | `"app_language_code"`, `"app_language_name"` |
| Appearance | UserDefaults | `"app_appearance_mode"` |
| Mascot selection | UserDefaults | `"app_mascot"` |
| Dev environment toggle | UserDefaults | `"use_dev_environment"` |
| Data display mode | UserDefaults | `"dataDisplayMode"` ("full" or other) |
| Food photos | File system | Via `ImageStorageService` |

---

## 9. Environment Configuration

```swift
// AppEnvironment.swift
struct AppEnvironment {
    static var baseURL: String {
        useDevEnvironment
            ? "http://192.168.0.10:30601/dev"     // Local K8s dev
            : "https://chater.singularis.work"     // Production
    }
    static var autocompleteBaseURL: String {
        useDevEnvironment
            ? "http://192.168.0.118"               // Local eater-users-dev
            : "https://chater.singularis.work"
    }
}
```

- **DEBUG builds** default to dev environment
- **Release builds** always use production
- Toggle stored in UserDefaults: `"use_dev_environment"`
- ATS allows local networking (`NSAllowsLocalNetworking: true`)

---

## 10. Key Patterns & Conventions

### Singleton Services
Most services use `static let shared` pattern:
- `ThemeService.shared`, `LanguageService.shared`, `AppSettingsService.shared`
- `ProductStorageService.shared`, `ImageStorageService.shared`
- `NotificationService.shared`, `HapticsService.shared`, `KeychainHelper.shared`

### Navigation
- Main screen uses `TabView` with page style (swipe between Statistics ↔ Home)
- Sub-screens presented as `.sheet()` modals
- Onboarding is a `.overlay()` on the main content

### State Management
- `@EnvironmentObject` for auth service, language service, app settings
- `@StateObject` for theme service
- `@State` for all local UI state in ContentView
- `@AppStorage` for persisted preferences

### Date Format Convention
- Backend dates use `dd-MM-yyyy` format
- Timestamps are Unix milliseconds (Int64)
- UTC date strings for current day: `getCurrentUTCDateString()`

### Error Handling
- Network errors: retry with exponential backoff
- Photo analysis errors: show localized alert via `AlertHelper.showAlert()`
- Auth errors: user stays logged in but secure operations require re-auth

---

## 11. Infrastructure Context

- **Backend:** Python FastAPI, deployed on Kubernetes
- **K8s namespaces:** `chater-auth-dev`, `chater-auth` (prod), `chater-ui`, `eater`, `eater-dev`
- **Image storage:** MinIO (referenced by `imageId` in Product)
- **Google Cloud Project ID:** `661157308222`
- **Google OAuth Client ID:** `661157308222-q1n7sgf6fp3k5ec67tflc3tes1e1nevf.apps.googleusercontent.com`
- **Production domain:** `chater.singularis.work`
- **JWT signing:** HS256 with `JWT_SECRET` K8s secret (server-only, 48h expiration)

---

## 12. Common Tasks Quick Guide

### Adding a new backend API call
1. If protobuf: create `.proto` file in `Services/`, generate `.pb.swift`
2. Add method to `GRPCService.swift` following existing pattern
3. Use `createRequest(endpoint:httpMethod:body:)` + `sendRequest(request:retriesLeft:completion:)`

### Adding a new View
1. Create SwiftUI file in `Views/`
2. Accept `@EnvironmentObject` for auth/language as needed
3. Use `AppTheme.*` colors and `loc()` for strings
4. Present via `.sheet()` from ContentView or parent

### Adding a localization key
1. Add key-value to `Localization/en.json` (and other language files)
2. Use `loc("your.key", "Fallback text")` in Swift code

### Changing the design system
1. Edit `DesignSystem.swift` — all tokens are there
2. Button styles, card modifiers, glass effects are all defined centrally

### Debugging auth issues
1. Check `AppEnvironment.baseURL` — dev vs prod
2. Verify Google Client ID in `Info.plist` matches Cloud Console
3. Check Keychain token: `KeychainHelper.shared.read("auth_token")`
4. See `.docs/BACKEND_AUTH_IMPLEMENTATION.md` for full auth flow

---

## 13. Known Gotchas

1. **ContentView is massive** (~2100 lines, 78KB). Most UI logic lives here. Consider this when planning changes.
2. **"GRPCService" is not gRPC** — it's HTTP REST with protobuf bodies. The name is historical.
3. **`src/` directory is empty** — all code is in `eater/`. Don't create files there.
4. **Dev environment uses local IPs** (192.168.0.x) — won't work outside the developer's network.
5. **Multiple Xcode projects exist** — use `eater.xcodeproj` (not `1eater.xcodeproj`).
6. **Protobuf files are checked in** — both `.proto` and generated `.pb.swift` files are in `Services/`.
7. **The app's struct is `AppNameApp`** not `EaterApp` — defined in `eaterApp.swift`.
8. **Date format is `dd-MM-yyyy`** not `yyyy-MM-dd` for backend communication.
