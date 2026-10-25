import SwiftUI
import UIKit

struct RootTabView: View {
  @EnvironmentObject var authService: AuthenticationService
  @EnvironmentObject var languageService: LanguageService
  @ObservedObject private var nav = AppNavigation.shared
  @State private var cameraTutorialStep: MainAppTutorialView.TutorialStep?
  @State private var manualWeightInput = ""
  @State private var statsPresented = true
  @State private var selectedTab: AppTab = .today

  var body: some View {
    ZStack {
      ContentView()
        .allowsHitTesting(selectedTab == .today)
        .accessibilityHidden(selectedTab != .today)

      IdeasTabView()
        .opacity(selectedTab == .ideas ? 1 : 0)
        .allowsHitTesting(selectedTab == .ideas)
        .accessibilityHidden(selectedTab != .ideas)
        .zIndex(selectedTab == .ideas ? 1 : 0)

      StatisticsView(isPresented: $statsPresented, showsCloseButton: false)
        .opacity(selectedTab == .stats ? 1 : 0)
        .allowsHitTesting(selectedTab == .stats)
        .accessibilityHidden(selectedTab != .stats)
        .zIndex(selectedTab == .stats ? 1 : 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      AppBottomBar(
        selection: selectedTab,
        onSelect: select,
        onCamera: {
          HapticsService.shared.select()
          nav.openCamera()
        },
        onUpload: {
          HapticsService.shared.select()
          nav.openPhotoLibrary()
        }
      )
    }
    .overlay(alignment: .top) {
      toastOverlay
    }
    .animation(.easeInOut(duration: 0.25), value: nav.toastMessage)
    .onChange(of: nav.selectedTab) { _, newTab in
      guard newTab != .camera, newTab != .upload else { return }
      select(newTab)
    }
    .modifier(SheetsModifier(
      nav: nav,
      cameraTutorialStep: $cameraTutorialStep,
      bindCameraCallbacks: bindCameraCallbacks
    ))
    .modifier(DialogsModifier(
      nav: nav,
      cameraTutorialStep: $cameraTutorialStep,
      manualWeightInput: $manualWeightInput,
      submitManualWeight: submitManualWeight
    ))
    .onAppear {
      nav.languageCode = languageService.currentCode
      if nav.activitiesDateISO.isEmpty {
        nav.activitiesDateISO = todayISO()
      }
      if nav.selectedTab != .camera && nav.selectedTab != .upload {
        selectedTab = nav.selectedTab
      }
    }
  }

  private func select(_ tab: AppTab) {
    guard tab != selectedTab else { return }
    if tab == .stats, !KeychainHelper.shared.getBool("hasSeenStatsTutorial") {
      presentStatsTutorial()
      return
    }
    HapticsService.shared.select()
    selectedTab = tab
    if nav.selectedTab != tab {
      nav.selectedTab = tab
    }
  }

  /// First Stats open shows the explainer, and the current tab stays put.
  private func presentStatsTutorial() {
    DispatchQueue.main.async {
      nav.selectedTab = selectedTab
      nav.openCaptureAfterTutorial = false
      nav.openStatsAfterTutorial = true
      if let step = MainAppTutorialView.steps.first(where: { $0.key == "hasSeenStatsTutorial" }) {
        cameraTutorialStep = step
      }
    }
  }

  @ViewBuilder
  private var toastOverlay: some View {
    if let message = nav.toastMessage {
      ToastBanner(message: message)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
  }

  private func bindCameraCallbacks() {
    CameraCallbackManager.shared.setCallbacks(
      onPhotoSuccess: {
        AppSettingsService.shared.foodScannedCount += 1
        if authService.recordAnonymousFoodScanIfNeeded() {
          nav.queueAnonymousLoginPrompt()
        }
        nav.notePhotoSuccess()
      },
      onPhotoFailure: {
        nav.notePhotoFailure()
      },
      onPhotoStarted: { image in
        nav.beginPendingMeal(image: image)
      }
    )
  }

  @discardableResult
  private func submitManualWeight() -> Bool {
    let normalized = manualWeightInput.replacingOccurrences(of: ",", with: ".")
    guard let value = Float(normalized), value > 0 else {
      HapticsService.shared.error()
      return false
    }
    guard let email = authService.userEmail else { return false }
    nav.isLoadingWeightPhoto = true
    GRPCService().sendManualWeight(weight: value, userEmail: email) { success in
      DispatchQueue.main.async {
        nav.isLoadingWeightPhoto = false
        if success {
          UserDefaults.standard.set(Double(value), forKey: "userWeight")
          StatisticsService.shared.invalidateDay()
          ProductStorageService.shared.clearCache()
          nav.noteWeightSuccess()
        } else {
          HapticsService.shared.error()
        }
      }
    }
    return true
  }

  private func todayISO() -> String {
    let f = DateFormatter()
    f.timeZone = TimeZone(abbreviation: "UTC")
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
  }

  private struct SheetsModifier: ViewModifier {
    @ObservedObject var nav: AppNavigation
    @Binding var cameraTutorialStep: MainAppTutorialView.TutorialStep?
    let bindCameraCallbacks: () -> Void
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var languageService: LanguageService

    func body(content: Content) -> some View {
      content
        .sheet(isPresented: $nav.showFoodCamera, onDismiss: {
          nav.tryPresentAnonymousLoginPrompt()
        }) {
          CameraView(
            photoType: "default_prompt",
            targetDate: nav.isViewingCustomDate ? nav.selectedDate : nil
          )
          .onAppear { bindCameraCallbacks() }
          .appInterfaceScale()
        }
        .sheet(isPresented: $nav.showPhotoLibrary, onDismiss: {
          nav.tryPresentAnonymousLoginPrompt()
        }) {
          PhotoLibraryView(
            photoType: "default_prompt",
            targetDate: nav.isViewingCustomDate ? nav.selectedDate : nil
          )
          .onAppear { bindCameraCallbacks() }
          .appInterfaceScale()
        }
        .sheet(isPresented: $nav.showWeightCamera) {
          WeightCameraView(
            onPhotoSuccess: {
              StatisticsService.shared.invalidateDay()
              ProductStorageService.shared.clearCache()
              nav.noteWeightSuccess()
            },
            onPhotoFailure: {
              nav.isLoadingWeightPhoto = false
            },
            onPhotoStarted: {
              nav.isLoadingWeightPhoto = true
            }
          )
          .appInterfaceScale()
        }
        .sheet(isPresented: $nav.showActivities) {
          ActivitiesView(
            dateISO: nav.activitiesDateISO.isEmpty ? Self.todayISO() : nav.activitiesDateISO
          )
          .appInterfaceScale()
        }
        .sheet(isPresented: $nav.showAlcohol) {
          AlcoholCalendarView(isPresented: $nav.showAlcohol)
            .appInterfaceScale()
        }
        .sheet(isPresented: $nav.showInPlaceLogin) {
          SignInSheet()
            .environmentObject(authService)
            .appInterfaceScale()
        }
        .sheet(isPresented: $nav.showHowItWorks) {
          OnboardingView(isPresented: $nav.showHowItWorks, mode: .howItWorks)
            .environmentObject(languageService)
            .interactiveDismissDisabled()
            .appInterfaceScale()
        }
        .sheet(
          item: $cameraTutorialStep,
          onDismiss: {
            if nav.openCaptureAfterTutorial {
              nav.openCaptureAfterTutorial = false
              if KeychainHelper.shared.getBool("hasSeenCameraTutorial") {
                if nav.pendingCaptureIsUpload {
                  nav.openPhotoLibrary()
                } else {
                  nav.openCamera()
                }
              }
            }
            if nav.openStatsAfterTutorial {
              nav.openStatsAfterTutorial = false
              if KeychainHelper.shared.getBool("hasSeenStatsTutorial") {
                nav.selectedTab = .stats
              }
            }
          }
        ) { step in
          MainAppTutorialView(
            isPresented: Binding(
              get: { cameraTutorialStep != nil },
              set: { if !$0 { cameraTutorialStep = nil } }
            ),
            specificStep: step
          )
          .environmentObject(languageService)
          .appInterfaceScale()
        }
    }

    private static func todayISO() -> String {
      let f = DateFormatter()
      f.timeZone = TimeZone(abbreviation: "UTC")
      f.dateFormat = "yyyy-MM-dd"
      return f.string(from: Date())
    }
  }

  private struct DialogsModifier: ViewModifier {
    @ObservedObject var nav: AppNavigation
    @Binding var cameraTutorialStep: MainAppTutorialView.TutorialStep?
    @Binding var manualWeightInput: String
    let submitManualWeight: () -> Bool
    @State private var openWeightCamera = false

    func body(content: Content) -> some View {
      content
        .sheet(isPresented: $nav.showWeightMenu, onDismiss: {
          guard openWeightCamera else { return }
          openWeightCamera = false
          DispatchQueue.main.async { nav.showWeightCamera = true }
        }) {
          WeightPromptSheet(
            weightText: $manualWeightInput,
            onPhoto: { openWeightCamera = true },
            onSubmit: submitManualWeight
          )
        }
        .sheet(isPresented: $nav.showManualWeight) {
          WeightPromptSheet(
            weightText: $manualWeightInput,
            onPhoto: { nav.showWeightCamera = true },
            onSubmit: submitManualWeight,
            startsOnManual: true
          )
        }
        .scaledNotice(
          loc("login.scan_prompt_title", "Unlock All Features"),
          isPresented: $nav.showAnonymousLoginPrompt,
          message: loc(
            "login.scan_prompt_message",
            "Please login to Google if you are ready or want to recover past food."
          ),
          actions: [
            ScaledNoticeAction(title: loc("login.prompt.confirm", "Login Now")) {
              nav.showInPlaceLogin = true
            },
            ScaledNoticeAction(title: loc("common.not_yet", "Not Yet"), kind: .secondary),
          ]
        )
        .scaledNotice(
          loc("camera.unavailable.title", "Camera Unavailable"),
          isPresented: $nav.cameraUnavailableAlert,
          message: loc("camera.unavailable.msg", "Your device does not have a camera."),
          actions: [ScaledNoticeAction(title: loc("common.ok", "OK"))]
        )
        .scaledNotice(
          loc("library.unavailable.title", "Photo Library Unavailable"),
          isPresented: $nav.photoLibraryUnavailableAlert,
          message: loc("library.unavailable.msg", "Photo library is not available."),
          actions: [ScaledNoticeAction(title: loc("common.ok", "OK"))]
        )
        .scaledNotice(
          loc("backdating.alert.title", "Confirm Past Date"),
          isPresented: $nav.showBackdatingAlert,
          message: nav.backdatingStatusEmoji + " " + nav.backdatingMessage + "\n\n"
            + loc("backdating.alert.tip", "Tip: You can log today's food instead."),
          actions: [
            ScaledNoticeAction(title: loc("backdating.alert.confirm", "Confirm")) {
              nav.confirmPastDateCapture()
            },
            ScaledNoticeAction(title: loc("backdating.alert.log_today", "Log Today's Food"), kind: .secondary) {
              nav.captureForTodayInstead()
            },
            ScaledNoticeAction(title: loc("backdating.alert.cancel", "Cancel"), kind: .secondary),
          ]
        )
        .onChange(of: nav.cameraTutorialRequested) { _, requested in
          guard requested else { return }
          nav.cameraTutorialRequested = false
          if let step = MainAppTutorialView.steps.first(where: { $0.key == "hasSeenCameraTutorial" })
          {
            cameraTutorialStep = step
          } else if nav.pendingCaptureIsUpload {
            nav.showPhotoLibrary = true
          } else {
            nav.showFoodCamera = true
          }
        }
    }
  }
}

/// Floating bottom bar: four small items, plus the raised camera button in the middle.
private struct AppBottomBar: View {
  let selection: AppTab
  let onSelect: (AppTab) -> Void
  let onCamera: () -> Void
  let onUpload: () -> Void

  /// Base sizes. The text-size slider scales the whole window, so this stays at 1.
  private var scale: CGFloat { 1 }

  /// Camera disc is 1.5x a side item, and pokes above the bar by `lift`.
  private var itemSize: CGFloat { 44 * scale }
  private var cameraSize: CGFloat { 66 * scale }
  private var barHeight: CGFloat { 58 * scale }
  private var lift: CGFloat { 26 * scale }
  private var iconSize: CGFloat { 17 * scale }
  private var labelSize: CGFloat { 10 * scale }
  private var cameraGlyphSize: CGFloat { 25 * scale }

  var body: some View {
    ZStack(alignment: .top) {
      items.padding(.top, lift)
      cameraButton
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 2)
  }

  private var items: some View {
    HStack(spacing: 0) {
      item(icon: "sun.max.fill", title: loc("tab.today", "Today"), isOn: selection == .today) {
        onSelect(.today)
      }
      item(icon: "lightbulb.fill", title: loc("tab.ideas", "Ideas"), isOn: selection == .ideas) {
        onSelect(.ideas)
      }
      Color.clear.frame(width: cameraSize + 12, height: 1)
      item(icon: "photo.fill", title: loc("camera.upload", "Upload"), isOn: false, action: onUpload)
      item(icon: "chart.bar.fill", title: loc("tab.stats", "Stats"), isOn: selection == .stats) {
        onSelect(.stats)
      }
    }
    .frame(height: barHeight)
    .background(barSurface)
  }

  private var barSurface: some View {
    let shadow = AppTheme.cardShadow
    return Capsule(style: .continuous)
      .fill(.ultraThinMaterial)
      .overlay(Capsule(style: .continuous).strokeBorder(AppTheme.divider, lineWidth: 0.5))
      .shadow(color: shadow.color, radius: 12, x: 0, y: 4)
  }

  private func item(
    icon: String,
    title: String,
    isOn: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 3 * scale) {
        Image(systemName: icon)
          .font(.system(size: iconSize, weight: .semibold))
        Text(title)
          .font(.system(size: labelSize, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      }
      .foregroundStyle(isOn ? AppTheme.primaryButtonFill : AppTheme.textSecondary)
      .frame(maxWidth: .infinity, minHeight: itemSize)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  private var cameraButton: some View {
    Button(action: onCamera) {
      Circle()
        .fill(AppTheme.primaryButtonFill)
        .frame(width: cameraSize, height: cameraSize)
        .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
        .overlay(
          Image(systemName: "camera.fill")
            .font(.system(size: cameraGlyphSize, weight: .semibold))
            .foregroundStyle(.white)
        )
        .shadow(color: AppTheme.primaryButtonFill.opacity(0.4), radius: 12, x: 0, y: 6)
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityLabel(loc("tab.photo", "Photo"))
  }
}
