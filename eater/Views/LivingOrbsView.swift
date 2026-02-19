import SwiftUI

/// Living Orbs: central mascot (dog/cat) + planets (activities) orbiting around.
struct LivingOrbsView: View {
  let orbData: [ActivityStatisticsView.OrbData]
  @Binding var selectedActivity: String?
  let timeRange: ActivityStatisticsView.TimeRange
  let centralImageName: String?
  var onCentralTap: (() -> Void)? = nil
  
  @State private var orbOffsets: [String: CGSize] = [:]
  @State private var draggedKey: String? = nil
  @State private var dragTranslation: CGSize = CGSize.zero
  
  private let activityOrder = ["gym", "steps", "treadmill", "elliptical", "yoga", "chess"]
  private let orbitSpeed: Double = 0.18
  private let dragMinimumDistance: CGFloat = 18
  
  /// Planet-inspired colors, bright for low brightness screens
  private func planetColor(_ key: String) -> Color {
    switch key {
    case "gym": return Color(red: 1, green: 0.5, blue: 0.3)          // Mars
    case "steps": return Color(red: 0.35, green: 0.85, blue: 0.65)   // Earth
    case "treadmill": return Color(red: 0.5, green: 0.85, blue: 1)   // Uranus
    case "elliptical": return Color(red: 0.95, green: 0.88, blue: 0.7) // Venus
    case "yoga": return Color(red: 0.4, green: 0.6, blue: 1)         // Neptune
    case "chess": return Color(red: 0.95, green: 0.85, blue: 0.5)    // Saturn
    default: return Color(red: 0.7, green: 0.7, blue: 0.75)
    }
  }
  
  private func activityDisplayName(_ key: String) -> String {
    switch key {
    case "gym": return Localization.shared.tr("activities.gym", default: "Gym")
    case "steps": return Localization.shared.tr("activities.steps", default: "Steps")
    case "treadmill": return Localization.shared.tr("activities.treadmill", default: "Treadmill")
    case "elliptical": return Localization.shared.tr("activities.elliptical", default: "Elliptical")
    case "yoga": return Localization.shared.tr("activities.yoga", default: "Yoga")
    case "chess": return Localization.shared.tr("activities.chess.name", default: "Chess")
    default: return key.capitalized
    }
  }
  
  var body: some View {
    GeometryReader { geo in
      orbScene(geo: geo)
    }
    .frame(height: 420)
  }
  
  private func orbScene(geo: GeometryProxy) -> some View {
    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
    let maxR = min(geo.size.width, geo.size.height) * 0.48
    let layout = computeLayout(center: center, maxRadius: maxR)
    return orbTimeline(center: center, layout: layout, size: geo.size)
      .animation(.easeInOut(duration: 0.4), value: layoutAnimationKey)
      .onChange(of: layoutAnimationKey) {
        orbOffsets = [:]
        draggedKey = nil
        dragTranslation = CGSize.zero
      }
  }
  
  /// 1/15 ≈ 15 FPS — менше навантаження на CPU, анімація все ще плавна.
  private func orbTimeline(center: CGPoint, layout: [LayoutItem], size: CGSize) -> some View {
    TimelineView(.animation(minimumInterval: 1/15, paused: false)) { ctx in
      orbsZStack(center: center, layout: layout, phase: ctx.date.timeIntervalSinceReferenceDate)
    }
    .frame(width: size.width, height: size.height)
  }
  
  private func orbsZStack(center: CGPoint, layout: [LayoutItem], phase: Double) -> some View {
    ZStack {
      ForEach(Array(layout.enumerated()), id: \.element.key) { _, item in
        orbItemView(item: item, center: center, phase: phase)
      }
      .drawingGroup() // один шар для GPU — менше перемальовувань
      centralCore(at: center)
    }
  }
  
  private func orbItemView(item: LayoutItem, center: CGPoint, phase: Double) -> some View {
    let orbitAngle = phase * orbitSpeed * item.orbitSpeedFactor
    let angle = item.baseAngle + orbitAngle
    let pos = CGPoint(
      x: center.x + item.distance * CGFloat(cos(angle)),
      y: center.y + item.distance * CGFloat(sin(angle))
    )
    let baseOffset = orbOffsets[item.key] ?? CGSize.zero
    let currentDrag = draggedKey == item.key ? dragTranslation : CGSize.zero
    let dragOffset = CGSize(width: baseOffset.width + currentDrag.width, height: baseOffset.height + currentDrag.height)
    return orbView(
      key: item.key,
      center: pos,
      radius: item.radius,
      hasData: item.hasData,
      isSelected: selectedActivity == item.key,
      phase: phase,
      dragOffset: dragOffset,
      onDragChanged: { trans in
        draggedKey = item.key
        dragTranslation = trans
      },
      onDragEnded: { trans in
        orbOffsets[item.key] = CGSize(
          width: (orbOffsets[item.key]?.width ?? CGFloat(0)) + trans.width,
          height: (orbOffsets[item.key]?.height ?? CGFloat(0)) + trans.height
        )
        draggedKey = nil
        dragTranslation = CGSize.zero
      },
      onTap: {
        HapticsService.shared.lightImpact()
        withAnimation(.easeInOut(duration: 0.28)) {
          selectedActivity = selectedActivity == item.key ? nil : item.key
        }
      }
    )
  }
  
  private var layoutAnimationKey: String {
    orbData.map { "\($0.key):\($0.sessions):\(Int($0.consistency * 100))" }.joined(separator: "|")
  }
  
  private func centralCore(at center: CGPoint) -> some View {
    let size: CGFloat = 72 * 2
    return ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [Color.white.opacity(0.15), Color.white.opacity(0.05), Color.clear],
            center: .center,
            startRadius: 0,
            endRadius: size / 2
          )
        )
        .frame(width: size + 24, height: size + 24)
      if let name = centralImageName {
        Image(name)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: size, height: size)
          .clipShape(Circle())
          .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 3))
          .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 4)
      } else {
        Circle()
          .fill(Color.white.opacity(0.15))
          .frame(width: size, height: size)
          .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 3))
        Image(systemName: "person.fill")
          .font(.system(size: 72, weight: .medium))
          .foregroundStyle(Color.white.opacity(0.9))
      }
    }
    .frame(width: size + 24, height: size + 24)
    .contentShape(Circle())
    .position(center)
    .allowsHitTesting(onCentralTap != nil)
    .onTapGesture {
      if let tap = onCentralTap { HapticsService.shared.lightImpact(); tap() }
    }
  }
  
  private struct LayoutItem {
    let key: String
    let distance: CGFloat
    let baseAngle: Double
    let radius: CGFloat
    let hasData: Bool
    /// Orbital speed multiplier (usage: more sessions → faster orbit)
    let orbitSpeedFactor: Double
  }
  
  private func angleJitter(for key: String) -> Double {
    let hash = key.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    return Double(hash % 31 - 15) * (2 * .pi / 360)
  }
  
  private func computeLayout(center: CGPoint, maxRadius: CGFloat) -> [LayoutItem] {
    guard !orbData.isEmpty else { return [] }
    let maxSessions = max(1, orbData.map(\.sessions).max() ?? 1)
    let minOrbR: CGFloat = 28
    let maxOrbR: CGFloat = 58
    let coreRadius: CGFloat = (72 * 2) / 2 + 16
    let innerR: CGFloat = coreRadius + 44
    let outerR: CGFloat = max(20, maxRadius - coreRadius - 40)
    
    var items: [(key: String, position: CGPoint, radius: CGFloat, hasData: Bool, orbitSpeedFactor: Double)] = []
    let n = orbData.count
    for (i, orb) in orbData.enumerated() {
      let baseAngle = (Double(i) / Double(max(n, 1))) * 2 * .pi - .pi / 2
      let angle = baseAngle + angleJitter(for: orb.key)
      let distance = innerR + (1 - orb.consistency) * outerR
      let x = center.x + distance * CGFloat(cos(angle))
      let y = center.y + distance * CGFloat(sin(angle))
      let rawR = orb.sessions > 0
        ? minOrbR + CGFloat(orb.sessions) / CGFloat(maxSessions) * (maxOrbR - minOrbR)
        : minOrbR
      let speedFactor = orb.sessions > 0
        ? 0.75 + 0.5 * Double(orb.sessions) / Double(maxSessions)
        : 1.0
      items.append((orb.key, CGPoint(x: x, y: y), rawR, orb.sessions > 0, speedFactor))
    }
    
    let padding: CGFloat = 14
    let saturnRingFactor: CGFloat = 1.4
    var radii = items.map(\.radius)
    let keys = items.map(\.key)
    for _ in 0..<40 {
      var changed = false
      for i in 0..<items.count {
        var maxAllowed: CGFloat = 1e6
        let coreDist = hypot(items[i].position.x - center.x, items[i].position.y - center.y)
        let fromCore = coreDist - coreRadius - padding - 4
        maxAllowed = min(maxAllowed, fromCore)
        for j in 0..<items.count where i != j {
          let d = hypot(items[i].position.x - items[j].position.x, items[i].position.y - items[j].position.y)
          let rj = keys[j] == "chess" ? radii[j] * saturnRingFactor : radii[j]
          let gap = d - rj - 2 * padding
          let limit = keys[i] == "chess" ? gap / saturnRingFactor : gap
          maxAllowed = min(maxAllowed, limit)
        }
        let minR: CGFloat = 16
        let clamped = max(minR, min(radii[i], maxAllowed))
        if clamped < radii[i] {
          radii[i] = clamped
          changed = true
        }
      }
      if !changed { break }
    }
    
    return zip(items, radii).map { item, r in
      let d = hypot(item.position.x - center.x, item.position.y - center.y)
      let a = atan2(item.position.y - center.y, item.position.x - center.x)
      return LayoutItem(key: item.key, distance: d, baseAngle: a, radius: r, hasData: item.hasData, orbitSpeedFactor: item.orbitSpeedFactor)
    }
  }
  
  @ViewBuilder
  private func planetSurfaceOverlay(key: String, side: CGFloat, radius: CGFloat, hasData: Bool, color: Color) -> some View {
    switch key {
    case "gym":
      ZStack {
        ForEach(0..<6, id: \.self) { i in
          let x = (CGFloat(i % 3) - 1) * radius * 0.35
          let y = (CGFloat(i / 3) - 0.5) * radius * 0.4
          Circle()
            .fill(Color(red: 0.5, green: 0.2, blue: 0.1).opacity(hasData ? 0.5 : 0.35))
            .frame(width: radius * (0.15 + CGFloat(i % 2) * 0.08), height: radius * (0.12 + CGFloat(i % 2) * 0.06))
            .offset(x: x, y: y)
        }
      }
    case "elliptical":
      ZStack {
        Ellipse()
          .fill(Color.white.opacity(hasData ? 0.3 : 0.2))
          .frame(width: side * 0.7, height: side * 0.15)
          .offset(y: -radius * 0.2)
        Ellipse()
          .fill(Color.white.opacity(hasData ? 0.2 : 0.14))
          .frame(width: side * 0.5, height: side * 0.12)
          .offset(y: radius * 0.25)
      }
    case "steps":
      ZStack {
        Circle()
          .fill(Color(red: 0.15, green: 0.4, blue: 0.35).opacity(hasData ? 0.45 : 0.3))
          .frame(width: radius * 0.5, height: radius * 0.4)
          .offset(x: radius * 0.25, y: -radius * 0.2)
        Circle()
          .fill(Color(red: 0.12, green: 0.35, blue: 0.3).opacity(hasData ? 0.4 : 0.25))
          .frame(width: radius * 0.35, height: radius * 0.5)
          .offset(x: -radius * 0.3, y: radius * 0.15)
      }
    case "treadmill":
      Ellipse()
        .fill(Color.white.opacity(hasData ? 0.15 : 0.1))
        .frame(width: side * 0.8, height: side * 0.12)
        .offset(y: radius * 0.1)
    case "yoga":
      ZStack {
        Ellipse()
          .fill(Color.white.opacity(hasData ? 0.12 : 0.08))
          .frame(width: side * 0.6, height: side * 0.1)
          .offset(y: -radius * 0.15)
        Circle()
          .fill(Color(red: 0.1, green: 0.15, blue: 0.35).opacity(hasData ? 0.5 : 0.35))
          .frame(width: radius * 0.4, height: radius * 0.35)
          .offset(x: radius * 0.2, y: radius * 0.2)
      }
    default:
      EmptyView()
    }
  }
  
  private func orbShortLabel(_ key: String) -> String {
    switch key {
    case "gym": return Localization.shared.tr("activities.gym", default: "Gym")
    case "steps": return Localization.shared.tr("activities.steps", default: "Steps")
    case "treadmill": return Localization.shared.tr("activities.treadmill", default: "Treadmill")
    case "elliptical": return Localization.shared.tr("activities.elliptical", default: "Elliptical")
    case "yoga": return Localization.shared.tr("activities.yoga", default: "Yoga")
    case "chess": return Localization.shared.tr("activities.chess.name", default: "Chess")
    default: return key.capitalized
    }
  }
  
  private func orbView(key: String, center pos: CGPoint, radius: CGFloat, hasData: Bool, isSelected: Bool, phase: Double, dragOffset: CGSize, onDragChanged: @escaping (CGSize) -> Void, onDragEnded: @escaping (CGSize) -> Void, onTap: @escaping () -> Void) -> some View {
    orbViewContent(key: key, radius: radius, hasData: hasData, phase: phase)
      .frame(width: radius * 2, height: radius * 2)
      .contentShape(Circle())
      .scaleEffect(isSelected ? 1.22 : (1 + 0.05 * sin(phase * 1.2)))
      .opacity(isSelected ? 1 : (selectedActivity == nil ? (hasData ? 1 : 0.55) : 0.4))
      .shadow(color: planetColor(key).opacity(0.55), radius: isSelected ? 14 : 8, x: 0, y: 2)
      .offset(dragOffset)
      .position(pos)
      .gesture(
        DragGesture(minimumDistance: dragMinimumDistance)
          .onChanged { onDragChanged($0.translation) }
          .onEnded { onDragEnded($0.translation) }
      )
      .onTapGesture(perform: onTap)
      .animation(.easeInOut(duration: 0.28), value: isSelected)
      .animation(.easeInOut(duration: 0.28), value: selectedActivity)
  }
  
  @ViewBuilder
  private func orbViewContent(key: String, radius: CGFloat, hasData: Bool, phase: Double) -> some View {
    let side = radius * 2
    let color = planetColor(key)
    ZStack {
      if key == "chess" {
        Ellipse()
          .stroke(
            LinearGradient(
              colors: [color.opacity(0.75), color.opacity(0.5), color.opacity(0.35)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: max(2, radius * 0.25)
          )
          .frame(width: side * 1.55, height: side * 0.5)
          .rotationEffect(.radians(phase * 0.12))
      }
      Circle()
        .fill(
          LinearGradient(
            colors: [color.opacity(hasData ? 1 : 0.85), color.opacity(hasData ? 0.75 : 0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .overlay(planetSurfaceOverlay(key: key, side: side, radius: radius, hasData: hasData, color: color))
        .overlay(orbHighlightOverlay(side: side, radius: radius, hasData: hasData))
        .overlay(Circle().stroke(color.opacity(1), lineWidth: 2.5))
      Text(orbShortLabel(key))
        .font(.system(size: min(16, max(10, radius * 0.38)), weight: .semibold))
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 6)
    }
  }
  
  private func orbHighlightOverlay(side: CGFloat, radius: CGFloat, hasData: Bool) -> some View {
    Ellipse()
      .fill(
        LinearGradient(
          colors: [Color.white.opacity(hasData ? 0.22 : 0.14), Color.white.opacity(0.06)],
          startPoint: .topLeading,
          endPoint: .center
        )
      )
      .frame(width: side * 0.42, height: side * 0.24)
      .offset(x: -radius * 0.3, y: -radius * 0.3)
  }
}
