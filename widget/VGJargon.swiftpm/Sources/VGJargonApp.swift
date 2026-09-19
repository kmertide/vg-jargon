import SwiftUI
import AppKit

// MARK: - App Entry Point

@main
struct VGJargonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("VGJargon")
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var vgWindow: NSWindow!
    var calendarWindow: NSWindow?
    var vgStore = CardStore()
    var vgViewModel = WidgetViewModel()
    var userProgress = UserProgress()

    static var shared: AppDelegate?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // VGJargon Widget
        let vgContent = VGJargonWidget(store: vgStore, viewModel: vgViewModel, progress: userProgress)
        vgWindow = createWindow(content: vgContent, x: 100, y: 200)
        vgViewModel.onSizeChange = { [weak self] expanded in
            self?.updateWindowSize(window: self?.vgWindow, expanded: expanded)
        }

        NSApp.setActivationPolicy(.accessory)
    }

    func toggleCalendarWindow() {
        if let window = calendarWindow, window.isVisible {
            window.orderOut(nil)
        } else {
            showCalendarWindow()
        }
    }

    func showCalendarWindow() {
        if calendarWindow == nil {
            let calendarContent = StandaloneCalendarView(progress: userProgress)
            let window = NSWindow(
                contentRect: NSRect(x: 350, y: 300, width: 520, height: 320),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Activity Calendar"
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = NSColor.clear
            window.isOpaque = false
            window.hasShadow = true
            // Normal level minus 1 to stay behind regular windows but still be interactive
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) - 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]

            let hostingView = NSHostingView(rootView: calendarContent)
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
            window.contentView = hostingView
            calendarWindow = window
        }
        calendarWindow?.makeKeyAndOrderFront(nil)
    }

    func createWindow<V: View>(content: V, x: CGFloat, y: CGFloat) -> NSWindow {
        let window = FloatingWindow(
            contentRect: NSRect(x: x, y: y, width: 110, height: 90),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        let hostingView = NSHostingView(rootView: content)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = hostingView
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = false
        // Normal level minus 1 to stay behind regular windows but still be interactive
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) - 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = true
        window.makeKeyAndOrderFront(nil)
        return window
    }

    func updateWindowSize(window: NSWindow?, expanded: Bool) {
        guard let window = window else { return }
        let frame = window.frame

        let newFrame: NSRect
        if expanded {
            newFrame = NSRect(x: frame.origin.x - 95, y: frame.origin.y - 360, width: 300, height: 450)
        } else {
            newFrame = NSRect(x: frame.origin.x + 95, y: frame.origin.y + 360, width: 110, height: 90)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            // Slight overshoot for a spring-like feel (NSWindow frame animation
            // has no native spring API, so this approximates one).
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1.0)
            window.animator().setFrame(newFrame, display: true)
        }
    }
}

class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - User Progress Model

class UserProgress: ObservableObject {
    @Published var streak: Int = 12
    @Published var totalXP: Int = 4250
    @Published var level: Int = 7
    @Published var dailyGoal: Int = 20
    @Published var cardsReviewedToday: Int = 34
    @Published var accuracyToday: Double = 0.78

    // Calendar data (last 90 days for full heatmap)
    @Published var calendarData: [Date: DayProgress] = [:]

    // Per-deck stats for pie chart
    @Published var deckStats: [String: Int] = [
        "file-types": 42,
        "indexes": 28,
        "algorithms": 18,
        "interfaces": 12
    ]

    // Track which app contributed
    @Published var appActivity: [Date: AppDayActivity] = [:]

    struct DayProgress {
        var cardsReviewed: Int
        var accuracy: Double
    }

    struct AppDayActivity {
        var vgJargonCards: Int = 0
        var totalCards: Int { vgJargonCards }
    }

    init() {
        // Generate sample calendar data for 90 days
        let calendar = Calendar.current
        for i in 0..<90 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let startOfDay = calendar.startOfDay(for: date)
                // More realistic distribution - some days no activity
                let hasActivity = Int.random(in: 0...10) > 2
                let cards = hasActivity ? Int.random(in: 1...45) : 0
                calendarData[startOfDay] = DayProgress(
                    cardsReviewed: cards,
                    accuracy: cards > 0 ? Double.random(in: 0.5...1.0) : 0
                )

                if cards > 0 {
                    appActivity[startOfDay] = AppDayActivity(vgJargonCards: cards)
                }
            }
        }
    }

    func recordAnswer(correct: Bool, deck: String) {
        cardsReviewedToday += 1
        if correct {
            totalXP += 10
        }
        deckStats[deck, default: 0] += 1

        // Update calendar
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var dayProgress = calendarData[today] ?? DayProgress(cardsReviewed: 0, accuracy: 0)
        dayProgress.cardsReviewed += 1
        calendarData[today] = dayProgress

        var activity = appActivity[today] ?? AppDayActivity()
        activity.vgJargonCards += 1
        appActivity[today] = activity
    }
}

class WidgetViewModel: ObservableObject {
    @Published var isExpanded = false
    @Published var showingStats = false
    var onSizeChange: ((Bool) -> Void)?

    func toggle() {
        isExpanded.toggle()
        onSizeChange?(isExpanded)
    }
}

// MARK: - Hoverable Icon Button

struct HoverIconButton: View {
    let systemName: String
    let size: CGFloat
    let color: Color
    let action: () -> Void
    @State private var isHovering = false

    init(_ systemName: String, size: CGFloat = 14, color: Color = .white.opacity(0.75), action: @escaping () -> Void) {
        self.systemName = systemName
        self.size = size
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size))
                .foregroundColor(isHovering ? .white : color)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.18 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

// MARK: - VGJargon Widget (Modern Bioinformatics Theme)

struct VGJargonWidget: View {
    @ObservedObject var store: CardStore
    @ObservedObject var viewModel: WidgetViewModel
    @ObservedObject var progress: UserProgress

    var body: some View {
        Group {
            if viewModel.isExpanded {
                VGExpandedView(store: store, viewModel: viewModel, progress: progress)
            } else {
                VGBadgeView(progress: progress, onTap: { viewModel.toggle() })
            }
        }
        .background(Color.clear)
    }
}

struct VGBadgeView: View {
    @ObservedObject var progress: UserProgress
    var onTap: () -> Void
    @State private var isHovering = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "FFD700"), Color(hex: "DAA520"), Color(hex: "B8860B")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: Color(hex: "FFD700").opacity(0.4), radius: 2)

            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    Text("🌊")
                        .font(.system(size: 20))
                    Text("🧬")
                        .font(.system(size: 20))
                }

                Text("VGJargon")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Streak indicator
                HStack(spacing: 2) {
                    Text("🔥")
                        .font(.system(size: 10))
                    Text("\(progress.streak)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "FF6B35"))
                }
            }
        }
        .frame(width: 100, height: 85)
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button("Show Calendar") {
                AppDelegate.shared?.toggleCalendarWindow()
            }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}

struct VGExpandedView: View {
    @ObservedObject var store: CardStore
    @ObservedObject var viewModel: WidgetViewModel
    @ObservedObject var progress: UserProgress
    @State private var showingStats = false
    @State private var isShowingAnswer = false

    var goalExceeded: Bool {
        progress.dailyGoal > 0 && progress.cardsReviewedToday > progress.dailyGoal
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "0d0d14"), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "FFD700"), Color(hex: "DAA520"), Color(hex: "B8860B")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .black.opacity(0.35), radius: 3, y: 2)

            VStack(spacing: 0) {
                // Header
                HStack {
                    VGBadgeView(progress: progress, onTap: { viewModel.toggle() })
                        .scaleEffect(0.5)
                        .frame(width: 50, height: 42)

                    Spacer()

                    // XP & Level
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Level \(progress.level)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "FFD700"))
                        Text("\(progress.totalXP) XP")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    HoverIconButton(showingStats ? "rectangle.stack" : "chart.pie") {
                        showingStats.toggle()
                    }
                    .padding(.leading, 8)

                    HoverIconButton("calendar") {
                        AppDelegate.shared?.toggleCalendarWindow()
                    }

                    HoverIconButton("xmark.circle.fill", size: 16) {
                        viewModel.toggle()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // Daily progress bar
                VStack(spacing: 4) {
                    HStack {
                        Text("Daily Goal")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        HStack(spacing: 3) {
                            Text("\(progress.cardsReviewedToday)/\(progress.dailyGoal)")
                            if goalExceeded {
                                Image(systemName: "checkmark.seal.fill")
                            }
                        }
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(goalExceeded ? Color(hex: "FFD700") : .white.opacity(0.6))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.12))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    goalExceeded
                                        ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "FFD700"), Color(hex: "DAA520")], startPoint: .leading, endPoint: .trailing))
                                        : AnyShapeStyle(Color(hex: "4CAF50"))
                                )
                                .frame(width: geo.size.width * min(1.0, Double(progress.cardsReviewedToday) / Double(progress.dailyGoal)))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)

                Divider().padding(.top, 8).background(Color.white.opacity(0.15))

                if showingStats {
                    StatsView(progress: progress)
                } else {
                    CardReviewView(store: store, progress: progress, isShowingAnswer: $isShowingAnswer)
                }
            }
        }
        .frame(width: 300, height: 450)
    }
}

// MARK: - Card Review View with Confidence Buttons

private struct FlipDownModifier: ViewModifier {
    let angle: Double
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.4)
            .opacity(angle == 0 ? 1 : 0)
    }
}

private extension AnyTransition {
    static var flipDown: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: FlipDownModifier(angle: -80), identity: FlipDownModifier(angle: 0)),
            removal: .opacity
        )
    }
}

struct CardReviewView: View {
    @ObservedObject var store: CardStore
    @ObservedObject var progress: UserProgress
    @Binding var isShowingAnswer: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let card = store.currentCard {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(card.front)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if isShowingAnswer {
                            VStack(alignment: .leading, spacing: 12) {
                                Divider().background(Color.white.opacity(0.15))

                                Text(card.back)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.75))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)

                                if !card.source.isEmpty {
                                    Text(card.source)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                            .transition(.flipDown)
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 180)

                Spacer()

                if isShowingAnswer {
                    // Confidence buttons
                    VStack(spacing: 8) {
                        Text("How well did you know this?")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))

                        HStack(spacing: 8) {
                            ConfidenceButton(label: "Again", color: Color(hex: "F44336"), minutes: "1m") {
                                nextCard(correct: false)
                            }
                            ConfidenceButton(label: "Hard", color: Color(hex: "FF9800"), minutes: "6m") {
                                nextCard(correct: true)
                            }
                            ConfidenceButton(label: "Good", color: Color(hex: "4CAF50"), minutes: "10m") {
                                nextCard(correct: true)
                            }
                            ConfidenceButton(label: "Easy", color: Color(hex: "2196F3"), minutes: "4d") {
                                nextCard(correct: true)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                } else {
                    Button(action: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                            isShowingAnswer = true
                        }
                    }) {
                        Text("Show Answer")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: [Color(hex: "2d8a3e"), Color(hex: "1f6b2c")], startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }

                Divider().background(Color.white.opacity(0.15))

                // Navigation
                HStack {
                    HoverIconButton("chevron.left") {
                        store.previousCard(); isShowingAnswer = false
                    }

                    Spacer()

                    Text("\(store.currentIndex + 1)/\(store.filteredCards.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))

                    Spacer()

                    HoverIconButton("shuffle") {
                        store.randomCard(); isShowingAnswer = false
                    }

                    HoverIconButton("chevron.right") {
                        store.nextCard(); isShowingAnswer = false
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            } else {
                Text("No cards")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    func nextCard(correct: Bool) {
        progress.recordAnswer(correct: correct, deck: store.currentCard?.deck ?? "")
        isShowingAnswer = false
        store.nextCard()
    }
}

struct ConfidenceButton: View {
    let label: String
    let color: Color
    let minutes: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                Text(minutes)
                    .font(.system(size: 8))
                    .opacity(0.75)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(hex: "FFD700").opacity(isHovering ? 0.6 : 0), lineWidth: 1.5)
            )
            .shadow(color: color.opacity(0.4), radius: isHovering ? 4 : 1, y: 1)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.04 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Stats View with Calendar & Pie Chart (Roman + Redwood Theme)

struct StatsView: View {
    @ObservedObject var progress: UserProgress

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Calendar Heatmap - Roman/Redwood Theme
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        HStack(spacing: 4) {
                            Text("🌲")
                                .font(.system(size: 14))
                            Text("Daily Chronicle")
                                .font(.system(size: 13, weight: .bold, design: .serif))
                                .foregroundColor(Color(hex: "5D3A1A"))
                        }
                        Spacer()
                        HStack(spacing: 3) {
                            Text("🔥")
                                .font(.system(size: 12))
                            Text("\(progress.streak) day streak")
                                .font(.system(size: 10, weight: .medium, design: .serif))
                                .foregroundColor(Color(hex: "8B4513"))
                        }
                    }

                    // Roman-style decorative line
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(LinearGradient(colors: [Color(hex: "8B4513"), Color(hex: "D4AF37")], startPoint: .leading, endPoint: .trailing))
                            .frame(height: 1)
                        Text("⚜️")
                            .font(.system(size: 8))
                        Rectangle()
                            .fill(LinearGradient(colors: [Color(hex: "D4AF37"), Color(hex: "8B4513")], startPoint: .leading, endPoint: .trailing))
                            .frame(height: 1)
                    }
                    .padding(.bottom, 4)

                    RedwoodCalendarHeatmap(data: progress.calendarData)
                }
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "FDF5E6"), Color(hex: "F5E6D3"), Color(hex: "FDF5E6")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "D4AF37"), Color(hex: "8B4513"), Color(hex: "D4AF37")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color(hex: "8B4513").opacity(0.2), radius: 4, y: 2)

                // Pie Chart - Redwood Theme
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 4) {
                        Text("🧬")
                            .font(.system(size: 14))
                        Text("Today's Categories")
                            .font(.system(size: 13, weight: .bold, design: .serif))
                            .foregroundColor(Color(hex: "5D3A1A"))
                    }

                    HStack(spacing: 16) {
                        RedwoodPieChart(data: progress.deckStats)
                            .frame(width: 85, height: 85)

                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(progress.deckStats.keys.sorted()), id: \.self) { key in
                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(redwoodColorForDeck(key))
                                        .frame(width: 10, height: 10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 2)
                                                .stroke(Color(hex: "D4AF37").opacity(0.5), lineWidth: 0.5)
                                        )
                                    Text(key)
                                        .font(.system(size: 10, design: .serif))
                                        .foregroundColor(Color(hex: "5D3A1A"))
                                    Spacer()
                                    Text("\(progress.deckStats[key] ?? 0)")
                                        .font(.system(size: 10, weight: .bold, design: .serif))
                                        .foregroundColor(Color(hex: "8B4513"))
                                }
                            }
                        }
                    }
                }
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "FDF5E6"), Color(hex: "F5E6D3"), Color(hex: "FDF5E6")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "D4AF37"), Color(hex: "8B4513"), Color(hex: "D4AF37")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color(hex: "8B4513").opacity(0.2), radius: 4, y: 2)

                // Today's Stats - Roman numerals
                HStack(spacing: 10) {
                    RedwoodStatBox(title: "Hodie", value: "\(progress.cardsReviewedToday)", subtitle: "cards")
                    RedwoodStatBox(title: "Accuracy", value: "\(Int(progress.accuracyToday * 100))%", subtitle: "correct")
                    RedwoodStatBox(title: "XP", value: "+280", subtitle: "earned")
                }
            }
            .padding(12)
        }
    }

    func redwoodColorForDeck(_ deck: String) -> Color {
        switch deck {
        case "file-types": return Color(hex: "8B4513")      // Saddle brown
        case "indexes": return Color(hex: "A0522D")         // Sienna
        case "algorithms": return Color(hex: "CD853F")      // Peru
        case "interfaces": return Color(hex: "D2691E")      // Chocolate
        default: return Color(hex: "BC8F8F")                // Rosy brown
        }
    }
}

struct RedwoodCalendarHeatmap: View {
    let data: [Date: UserProgress.DayProgress]

    // Redwood color palette - from light to dark
    let redwoodColors: [Color] = [
        Color(hex: "E8D5C4"),   // Light bark
        Color(hex: "CD853F"),   // Light redwood
        Color(hex: "A0522D"),   // Medium redwood
        Color(hex: "8B4513"),   // Dark redwood
        Color(hex: "5D3A1A")    // Deep redwood
    ]

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        VStack(spacing: 6) {
            // Day labels
            HStack(spacing: 4) {
                ForEach(0..<14, id: \.self) { i in
                    if let date = calendar.date(byAdding: .day, value: -(13 - i), to: today) {
                        Text(dayAbbrev(calendar.component(.weekday, from: date)))
                            .font(.system(size: 7, weight: .medium, design: .serif))
                            .foregroundColor(Color(hex: "8B4513").opacity(0.7))
                            .frame(width: 16)
                    }
                }
            }

            // Calendar squares
            HStack(spacing: 4) {
                ForEach(0..<14, id: \.self) { i in
                    if let date = calendar.date(byAdding: .day, value: -(13 - i), to: today) {
                        let dayData = data[calendar.startOfDay(for: date)]
                        let cardsReviewed = dayData?.cardsReviewed ?? 0
                        let colorIndex = colorIndexForCards(cardsReviewed)

                        VStack(spacing: 3) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(redwoodColors[colorIndex])
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color(hex: "D4AF37").opacity(colorIndex > 0 ? 0.6 : 0.2), lineWidth: 1)
                                    )
                                    .shadow(color: colorIndex > 2 ? Color(hex: "8B4513").opacity(0.3) : .clear, radius: 2)

                                // Show tree ring for high activity
                                if colorIndex >= 3 {
                                    Text("🌲")
                                        .font(.system(size: 8))
                                }
                            }

                            if i == 13 {
                                Text("Now")
                                    .font(.system(size: 7, weight: .bold, design: .serif))
                                    .foregroundColor(Color(hex: "8B4513"))
                            } else {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.system(size: 7, design: .serif))
                                    .foregroundColor(Color(hex: "8B4513").opacity(0.7))
                            }
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: 12) {
                Text("Less")
                    .font(.system(size: 8, design: .serif))
                    .foregroundColor(Color(hex: "8B4513"))

                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(redwoodColors[i])
                            .frame(width: 10, height: 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color(hex: "D4AF37").opacity(0.3), lineWidth: 0.5)
                            )
                    }
                }

                Text("More")
                    .font(.system(size: 8, design: .serif))
                    .foregroundColor(Color(hex: "8B4513"))
            }
            .padding(.top, 4)
        }
    }

    func dayAbbrev(_ weekday: Int) -> String {
        let days = ["", "S", "M", "T", "W", "T", "F", "S"]
        return days[weekday]
    }

    func colorIndexForCards(_ cards: Int) -> Int {
        switch cards {
        case 0: return 0
        case 1...5: return 1
        case 6...15: return 2
        case 16...25: return 3
        default: return 4
        }
    }
}

struct RedwoodPieChart: View {
    let data: [String: Int]

    var body: some View {
        let total = data.values.reduce(0, +)
        let sortedKeys = data.keys.sorted()

        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 6

                var startAngle = Angle.degrees(-90)

                for key in sortedKeys {
                    let value = data[key] ?? 0
                    let angle = Angle.degrees(Double(value) / Double(max(1, total)) * 360)

                    let path = Path { p in
                        p.move(to: center)
                        p.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle + angle, clockwise: false)
                        p.closeSubpath()
                    }

                    context.fill(path, with: .color(redwoodColorForKey(key)))

                    // Add gold border between slices
                    let borderPath = Path { p in
                        p.move(to: center)
                        p.addLine(to: CGPoint(
                            x: center.x + radius * cos(CGFloat(startAngle.radians)),
                            y: center.y + radius * sin(CGFloat(startAngle.radians))
                        ))
                    }
                    context.stroke(borderPath, with: .color(Color(hex: "D4AF37")), lineWidth: 1)

                    startAngle += angle
                }
            }

            // Center decoration
            Circle()
                .fill(Color(hex: "FDF5E6"))
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color(hex: "D4AF37"), lineWidth: 1.5)
                )
                .overlay(
                    Text("🧬")
                        .font(.system(size: 14))
                )
        }
    }

    func redwoodColorForKey(_ key: String) -> Color {
        switch key {
        case "file-types": return Color(hex: "8B4513")
        case "indexes": return Color(hex: "A0522D")
        case "algorithms": return Color(hex: "CD853F")
        case "interfaces": return Color(hex: "D2691E")
        default: return Color(hex: "BC8F8F")
        }
    }
}

struct RedwoodStatBox: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .serif))
                .foregroundColor(Color(hex: "8B4513"))
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "5D3A1A"))
            Text(subtitle)
                .font(.system(size: 8, design: .serif))
                .foregroundColor(Color(hex: "A0522D"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color(hex: "FDF5E6"), Color(hex: "F5E6D3")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "D4AF37"), Color(hex: "8B4513")],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - Standalone Calendar View (GitHub-style Heatmap)

struct StandaloneCalendarView: View {
    @ObservedObject var progress: UserProgress
    @State private var hoveredDate: Date? = nil
    @State private var selectedMonth: Int = 0

    let calendar = Calendar.current
    let columns = 13  // ~3 months of weeks

    // GitHub-style green palette
    let intensityColors: [Color] = [
        Color(hex: "161B22"),  // Empty - dark
        Color(hex: "0E4429"),  // Level 1
        Color(hex: "006D32"),  // Level 2
        Color(hex: "26A641"),  // Level 3
        Color(hex: "39D353")   // Level 4 - brightest
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity Calendar")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("\(totalCardsLast90Days) cards reviewed in the last 90 days")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Stats summary
                HStack(spacing: 16) {
                    VStack(alignment: .center, spacing: 2) {
                        Text("\(progress.streak)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "FF6B35"))
                        Text("day streak")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .center, spacing: 2) {
                        Text("\(progress.totalXP)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "FFD700"))
                        Text("total XP")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .center, spacing: 2) {
                        Text("Lvl \(progress.level)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "2196F3"))
                        Text("rank")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Calendar grid
            VStack(alignment: .leading, spacing: 8) {
                // Month labels
                HStack(spacing: 0) {
                    Text("")
                        .frame(width: 30)
                    ForEach(monthLabels, id: \.offset) { label in
                        Text(label.name)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: CGFloat(label.weeks) * 15, alignment: .leading)
                    }
                }
                .padding(.leading, 4)

                // Day labels + grid
                HStack(alignment: .top, spacing: 4) {
                    // Day of week labels
                    VStack(spacing: 3) {
                        Text("").frame(height: 12)
                        Text("Mon").font(.system(size: 9)).foregroundColor(.secondary)
                        Text("").frame(height: 12)
                        Text("Wed").font(.system(size: 9)).foregroundColor(.secondary)
                        Text("").frame(height: 12)
                        Text("Fri").font(.system(size: 9)).foregroundColor(.secondary)
                        Text("").frame(height: 12)
                    }
                    .frame(width: 26)

                    // Grid of contribution squares
                    HStack(spacing: 3) {
                        ForEach(weeksData.indices, id: \.self) { weekIndex in
                            VStack(spacing: 3) {
                                ForEach(weeksData[weekIndex], id: \.self) { date in
                                    ContributionSquare(
                                        date: date,
                                        progress: progress,
                                        colors: intensityColors,
                                        isHovered: hoveredDate == date
                                    )
                                    .onHover { isHovered in
                                        hoveredDate = isHovered ? date : nil
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 4)

                // Legend
                HStack(spacing: 16) {
                    Spacer()

                    // Today's activity
                    if let todayActivity = progress.appActivity[calendar.startOfDay(for: Date())] {
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: "2196F3")).frame(width: 8, height: 8)
                            Text("VGJargon: \(todayActivity.vgJargonCards)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Intensity legend
                    HStack(spacing: 4) {
                        Text("Less")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(intensityColors[i])
                                .frame(width: 12, height: 12)
                        }

                        Text("More")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            }
            .padding(20)

            // Hover tooltip
            if let date = hoveredDate {
                HStack {
                    Spacer()
                    tooltipView(for: date)
                    Spacer()
                }
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    var totalCardsLast90Days: Int {
        progress.calendarData.values.reduce(0) { $0 + $1.cardsReviewed }
    }

    var weeksData: [[Date]] {
        let today = calendar.startOfDay(for: Date())
        var weeks: [[Date]] = []

        // Go back 90 days and organize into weeks
        var currentWeek: [Date] = []
        for i in (0..<91).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let weekday = calendar.component(.weekday, from: date)
                // Start week on Sunday (weekday 1)
                if weekday == 1 && !currentWeek.isEmpty {
                    weeks.append(currentWeek)
                    currentWeek = []
                }
                currentWeek.append(date)
            }
        }
        if !currentWeek.isEmpty {
            weeks.append(currentWeek)
        }

        return weeks
    }

    struct MonthLabel: Hashable {
        let name: String
        let weeks: Int
        let offset: Int
    }

    var monthLabels: [MonthLabel] {
        var labels: [MonthLabel] = []
        var currentMonth = -1
        var weekCount = 0
        var offset = 0

        for week in weeksData {
            if let firstDay = week.first {
                let month = calendar.component(.month, from: firstDay)
                if month != currentMonth {
                    if currentMonth != -1 {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "MMM"
                        if let prevDate = calendar.date(from: DateComponents(month: currentMonth)) {
                            labels.append(MonthLabel(name: formatter.string(from: prevDate), weeks: weekCount, offset: offset))
                        }
                        offset += weekCount
                    }
                    currentMonth = month
                    weekCount = 1
                } else {
                    weekCount += 1
                }
            }
        }
        // Add last month
        if currentMonth != -1 {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            if let date = calendar.date(from: DateComponents(month: currentMonth)) {
                labels.append(MonthLabel(name: formatter.string(from: date), weeks: weekCount, offset: offset))
            }
        }

        return labels
    }

    func tooltipView(for date: Date) -> some View {
        let dayData = progress.calendarData[calendar.startOfDay(for: date)]
        let activity = progress.appActivity[calendar.startOfDay(for: date)]
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"

        return VStack(spacing: 4) {
            Text("\(dayData?.cardsReviewed ?? 0) cards reviewed")
                .font(.system(size: 12, weight: .semibold))
            Text(formatter.string(from: date))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            if let activity = activity, activity.totalCards > 0 {
                Text("VG: \(activity.vgJargonCards)")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "2196F3"))
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .shadow(radius: 4)
    }
}

struct ContributionSquare: View {
    let date: Date
    let progress: UserProgress
    let colors: [Color]
    let isHovered: Bool

    var body: some View {
        let calendar = Calendar.current
        let dayData = progress.calendarData[calendar.startOfDay(for: date)]
        let cards = dayData?.cardsReviewed ?? 0
        let colorIndex = intensityLevel(cards)

        RoundedRectangle(cornerRadius: 2)
            .fill(colors[colorIndex])
            .frame(width: 12, height: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isHovered ? Color.white : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isHovered)
    }

    func intensityLevel(_ cards: Int) -> Int {
        switch cards {
        case 0: return 0
        case 1...5: return 1
        case 6...15: return 2
        case 16...30: return 3
        default: return 4
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        r = Double((int >> 16) & 0xFF) / 255
        g = Double((int >> 8) & 0xFF) / 255
        b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
