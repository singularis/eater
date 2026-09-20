import SwiftUI
import UIKit

extension UIImage {
  /// Empty 25pt slot so the Photo label sits with the other tab titles.
  static let transparentTabIcon: UIImage = UIGraphicsImageRenderer(
    size: CGSize(width: 25, height: 25)
  ).image { _ in }.withRenderingMode(.alwaysOriginal)
}

struct RootTabView: View {
  @EnvironmentObject var authService: AuthenticationService
  @EnvironmentObject var languageService: LanguageService
  @ObservedObject private var nav = AppNavigation.shared
  @State private var cameraTutorialStep: MainAppTutorialView.TutorialStep?
  @State private var manualWeightInput = ""
  @State private var statsPresented = true
  @State private var selectedTab: AppTab = .today

  var body: some View {
    TabView(selection: $selectedTab) {
      ContentView()
        .tabItem { Label(loc("tab.today", "Today"), systemImage: "sun.max.fill") }
        .tag(AppTab.today)

      IdeasTabView()
        .tabItem { Label(loc("tab.ideas", "Ideas"), systemImage: "lightbulb.fill") }
        .tag(AppTab.ideas)

      PhotoActionPage()
        .tabItem {
          Image(uiImage: .transparentTabIcon)
          Text(loc("tab.photo", "Photo"))
        }
        .tag(AppTab.camera)

      UploadActionPage()
        .tabItem { Label(loc("camera.upload", "Upload"), systemImage: "photo.fill") }
        .tag(AppTab.upload)

      StatisticsView(isPresented: $statsPresented, showsCloseButton: false)
        .tabItem { Label(loc("tab.stats", "Stats"), systemImage: "chart.bar.fill") }
        .tag(AppTab.stats)
    }
    .tint(AppTheme.primaryButtonFill)
    .overlay {
      PhotoCaptureButton {
        HapticsService.shared.select()
        nav.openCamera()
      }
    }
    .overlay(alignment: .top) {
      toastOverlay
    }
    .animation(.easeInOut(duration: 0.25), value: nav.toastMessage)
    .onChange(of: selectedTab) { oldTab, newTab in
      handleLocalTabChange(from: oldTab, to: newTab)
    }
    .onChange(of: nav.selectedTab) { _, newTab in
      guard newTab != .camera, newTab != .upload, selectedTab != newTab else { return }
      selectedTab = newTab
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

  private func handleLocalTabChange(from oldTab: AppTab, to newTab: AppTab) {
    if newTab == .stats, !KeychainHelper.shared.getBool("hasSeenStatsTutorial") {
      let restore = (oldTab == .camera || oldTab == .upload) ? .today : oldTab
      DispatchQueue.main.async {
        selectedTab = restore
        nav.selectedTab = restore
        nav.openCaptureAfterTutorial = false
        nav.openStatsAfterTutorial = true
        if let step = MainAppTutorialView.steps.first(where: { $0.key == "hasSeenStatsTutorial" }) {
          cameraTutorialStep = step
        }
      }
      return
    }
    guard newTab == .camera || newTab == .upload else {
      if nav.selectedTab != newTab {
        nav.selectedTab = newTab
      }
      return
    }
    let restore: AppTab = (oldTab == .camera || oldTab == .upload) ? .today : oldTab
    DispatchQueue.main.async {
      selectedTab = restore
      nav.selectedTab = restore
      if newTab == .camera {
        nav.openCamera()
      } else {
        nav.openPhotoLibrary()
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
        nav.notePhotoSuccess()
      },
      onPhotoFailure: {
        nav.notePhotoFailure()
      },
      onPhotoStarted: { image in
        nav.beginPendingMeal(image: image)
        if authService.recordAnonymousFoodScanIfNeeded() {
          nav.showAnonymousLoginPrompt = true
        }
      }
    )
  }

  private func submitManualWeight() {
    let normalized = manualWeightInput.replacingOccurrences(of: ",", with: ".")
    guard let value = Float(normalized), value > 0 else {
      HapticsService.shared.error()
      return
    }
    guard let email = authService.userEmail else { return }
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
        .sheet(isPresented: $nav.showFoodCamera) {
          CameraView(
            photoType: "default_prompt",
            targetDate: nav.isViewingCustomDate ? nav.selectedDate : nil
          )
          .onAppear { bindCameraCallbacks() }
        }
        .sheet(isPresented: $nav.showPhotoLibrary) {
          PhotoLibraryView(
            photoType: "default_prompt",
            targetDate: nav.isViewingCustomDate ? nav.selectedDate : nil
          )
          .onAppear { bindCameraCallbacks() }
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
        }
        .sheet(isPresented: $nav.showActivities) {
          ActivitiesView(
            dateISO: nav.activitiesDateISO.isEmpty ? Self.todayISO() : nav.activitiesDateISO
          )
        }
        .sheet(isPresented: $nav.showAlcohol) {
          AlcoholCalendarView(isPresented: $nav.showAlcohol)
        }
        .sheet(isPresented: $nav.showInPlaceLogin) {
          SignInSheet()
            .environmentObject(authService)
        }
        .sheet(isPresented: $nav.showHowItWorks) {
          OnboardingView(isPresented: $nav.showHowItWorks, mode: .howItWorks)
            .environmentObject(languageService)
            .interactiveDismissDisabled()
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
    let submitManualWeight: () -> Void

    func body(content: Content) -> some View {
      content
        .confirmationDialog(
          loc("weight.record.title", "Record Weight"),
          isPresented: $nav.showWeightMenu,
          titleVisibility: .visible
        ) {
          Button(loc("weight.take_photo", "Take scale photo")) {
            HapticsService.shared.select()
            nav.showWeightCamera = true
          }
          Button(loc("weight.manual_entry", "Manual Entry")) {
            HapticsService.shared.select()
            manualWeightInput = ""
            nav.showManualWeight = true
          }
          Button(loc("common.cancel", "Cancel"), role: .cancel) {}
        } message: {
          Text(loc("weight.record.msg", "Choose how you'd like to record your weight"))
        }
        .alert(loc("weight.enter.title", "Enter Weight"), isPresented: $nav.showManualWeight) {
          TextField(loc("weight.enter.placeholder", "Weight (kg)"), text: $manualWeightInput)
            .keyboardType(.decimalPad)
          Button(loc("common.save", "Submit")) { submitManualWeight() }
          Button(loc("common.cancel", "Cancel"), role: .cancel) {}
        } message: {
          Text(loc("weight.enter.msg", "Enter your weight in kilograms"))
        }
        .alert(
          loc("login.scan_prompt_title", "Unlock All Features"),
          isPresented: $nav.showAnonymousLoginPrompt
        ) {
          Button(loc("common.not_yet", "Not Yet"), role: .cancel) {}
          Button(loc("login.prompt.confirm", "Login Now")) { nav.showInPlaceLogin = true }
        } message: {
          Text(
            loc(
              "login.scan_prompt_message",
              "Please login to Google if you are ready or want to recover past food."
            ))
        }
        .alert(
          loc("camera.unavailable.title", "Camera Unavailable"),
          isPresented: $nav.cameraUnavailableAlert
        ) {
          Button(loc("common.ok", "OK")) {}
        } message: {
          Text(loc("camera.unavailable.msg", "Your device does not have a camera."))
        }
        .alert(
          loc("library.unavailable.title", "Photo Library Unavailable"),
          isPresented: $nav.photoLibraryUnavailableAlert
        ) {
          Button(loc("common.ok", "OK")) {}
        } message: {
          Text(loc("library.unavailable.msg", "Photo library is not available."))
        }
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

/// Capture control in the middle tab slot. Shares the other glyphs' midline;
/// only this control is 1.2× and stays primary blue.
private struct PhotoCaptureButton: View {
  let action: () -> Void
  @State private var iconCenter: CGPoint = .zero

  private let tabIconSize: CGFloat = 25

  var body: some View {
    ZStack {
      TabIconCenterReader(tabIndex: 2) { iconCenter = $0 }
        .allowsHitTesting(false)
      if iconCenter != .zero {
        Button(action: action) {
          Image(systemName: "camera.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: tabIconSize, height: tabIconSize)
            .background(AppTheme.primaryButtonFill, in: Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .scaleEffect(1.2)
        .position(iconCenter)
        .accessibilityLabel(loc("camera.takefood", "Take Food Photo"))
      }
    }
    .ignoresSafeArea()
  }
}

/// Reads the center of a system tab-bar glyph so overlays sit on the same line.
private struct TabIconCenterReader: UIViewRepresentable {
  let tabIndex: Int
  let onChange: (CGPoint) -> Void

  func makeUIView(context: Context) -> ProbeView {
    let view = ProbeView()
    view.tabIndex = tabIndex
    view.onChange = onChange
    view.isUserInteractionEnabled = false
    view.backgroundColor = .clear
    return view
  }

  func updateUIView(_ uiView: ProbeView, context: Context) {
    uiView.tabIndex = tabIndex
    uiView.onChange = onChange
    uiView.report()
  }

  final class ProbeView: UIView {
    var tabIndex = 2
    var onChange: ((CGPoint) -> Void)?
    private var lastCenter = CGPoint(x: -1, y: -1)

    override func didMoveToWindow() {
      super.didMoveToWindow()
      DispatchQueue.main.async { [weak self] in self?.report() }
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      DispatchQueue.main.async { [weak self] in self?.report() }
    }

    func report() {
      guard let window else { return }
      guard let bar = Self.tabBar(in: window) else { return }
      let buttons = bar.subviews
        .filter { NSStringFromClass(type(of: $0)).contains("TabBarButton") }
        .sorted { $0.frame.minX < $1.frame.minX }
      guard buttons.indices.contains(tabIndex) else { return }
      let slot = buttons[tabIndex]
      let midX = slot.convert(CGPoint(x: slot.bounds.midX, y: 0), to: self).x
      let neighborIndexes = [tabIndex - 1, tabIndex + 1].filter { buttons.indices.contains($0) }
      let neighborYs = neighborIndexes.compactMap { Self.iconCenter(of: buttons[$0], to: self)?.y }
      let midY: CGFloat
      if !neighborYs.isEmpty {
        midY = neighborYs.reduce(0, +) / CGFloat(neighborYs.count)
      } else if let own = Self.iconCenter(of: slot, to: self) {
        midY = own.y
      } else {
        return
      }
      let center = CGPoint(x: midX, y: midY)
      guard hypot(center.x - lastCenter.x, center.y - lastCenter.y) > 0.5 else { return }
      lastCenter = center
      onChange?(center)
    }

    private static func iconCenter(of button: UIView, to host: UIView) -> CGPoint? {
      let image = firstImage(in: button)
      guard let image, image.bounds.width >= 8 else { return nil }
      return image.convert(CGPoint(x: image.bounds.midX, y: image.bounds.midY), to: host)
    }

    private static func firstImage(in view: UIView) -> UIImageView? {
      if let image = view as? UIImageView, image.bounds.width >= 8 { return image }
      for child in view.subviews {
        if let image = firstImage(in: child) { return image }
      }
      return nil
    }

    private static func tabBar(in root: UIView) -> UITabBar? {
      if let bar = root as? UITabBar { return bar }
      for child in root.subviews {
        if let bar = tabBar(in: child) { return bar }
      }
      return nil
    }
  }
}

private struct PhotoActionPage: View {
  var body: some View {
    AppTheme.backgroundGradient.ignoresSafeArea()
  }
}

private struct UploadActionPage: View {
  var body: some View {
    AppTheme.backgroundGradient.ignoresSafeArea()
  }
}
