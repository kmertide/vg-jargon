import SwiftUI
import AppKit

// MARK: - App Entry Point

@main
struct VGJargonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("VGJargon & HPRC-ShopTalk")
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var vgWindow: NSWindow!
    var hprcWindow: NSWindow!
    var centroWindow: NSWindow!
    var calendarWindow: NSWindow?
    var vgStore = CardStore()
    var hprcStore = CardStore()
    var centroStore = CardStore()
    var vgViewModel = WidgetViewModel()
    var hprcViewModel = WidgetViewModel()
    var centroViewModel = WidgetViewModel()
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

        // HPRC-ShopTalk Widget
        let hprcContent = HPRCShopTalkWidget(store: hprcStore, viewModel: hprcViewModel, progress: userProgress)
        hprcWindow = createWindow(content: hprcContent, x: 220, y: 200)
        hprcViewModel.onSizeChange = { [weak self] expanded in
            self?.updateWindowSize(window: self?.hprcWindow, expanded: expanded)
        }

        // Centro Core Widget
        let centroContent = CentroCoreWidget(store: centroStore, viewModel: centroViewModel, progress: userProgress)
        centroWindow = createWindow(content: centroContent, x: 340, y: 200)
        centroViewModel.onSizeChange = { [weak self] expanded in
            self?.updateWindowSize(window: self?.centroWindow, expanded: expanded)
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

        if expanded {
            let newFrame = NSRect(
                x: frame.origin.x - 95,
                y: frame.origin.y - 360,
                width: 300,
                height: 450
            )
            window.setFrame(newFrame, display: true, animate: true)
        } else {
            let newFrame = NSRect(
                x: frame.origin.x + 95,
                y: frame.origin.y + 360,
                width: 110,
                height: 90
            )
            window.setFrame(newFrame, display: true, animate: true)
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
        var hprcCards: Int = 0
        var totalCards: Int { vgJargonCards + hprcCards }
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

                // Split between apps
                if cards > 0 {
                    let vgCards = Int.random(in: 0...cards)
                    appActivity[startOfDay] = AppDayActivity(
                        vgJargonCards: vgCards,
                        hprcCards: cards - vgCards
                    )
                }
            }
        }
    }

    func recordAnswer(correct: Bool, deck: String, app: String = "vg") {
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
        if app == "vg" {
            activity.vgJargonCards += 1
        } else {
            activity.hprcCards += 1
        }
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
                .shadow(color: Color(hex: "FFD700").opacity(0.4), radius: 8)

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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "FFD700").opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 15, y: 5)

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
                            .foregroundColor(.secondary)
                    }

                    Button(action: { showingStats.toggle() }) {
                        Image(systemName: showingStats ? "rectangle.stack" : "chart.pie")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)

                    Button(action: { AppDelegate.shared?.toggleCalendarWindow() }) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.toggle() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // Daily progress bar
                VStack(spacing: 4) {
                    HStack {
                        Text("Daily Goal")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(progress.cardsReviewedToday)/\(progress.dailyGoal)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.2))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: "4CAF50"))
                                .frame(width: geo.size.width * min(1.0, Double(progress.cardsReviewedToday) / Double(progress.dailyGoal)))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)

                Divider().padding(.top, 8)

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
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if isShowingAnswer {
                            Divider()

                            Text(card.back)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)

                            if !card.source.isEmpty {
                                Text(card.source)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(.top, 4)
                            }
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
                            .foregroundColor(.secondary)

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
                } else {
                    Button(action: { isShowingAnswer = true }) {
                        Text("Show Answer")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "2d8a3e"))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }

                Divider()

                // Navigation
                HStack {
                    Button(action: { store.previousCard(); isShowingAnswer = false }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("\(store.currentIndex + 1)/\(store.filteredCards.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: { store.randomCard(); isShowingAnswer = false }) {
                        Image(systemName: "shuffle")
                    }
                    .buttonStyle(.plain)

                    Button(action: { store.nextCard(); isShowingAnswer = false }) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            } else {
                Text("No cards")
                    .foregroundColor(.secondary)
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

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                Text(minutes)
                    .font(.system(size: 8))
                    .opacity(0.7)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
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

// MARK: - HPRC-ShopTalk Widget (Ancient Rome Theme)

struct HPRCShopTalkWidget: View {
    @ObservedObject var store: CardStore
    @ObservedObject var viewModel: WidgetViewModel
    @ObservedObject var progress: UserProgress

    var body: some View {
        Group {
            if viewModel.isExpanded {
                HPRCExpandedView(store: store, viewModel: viewModel, progress: progress)
            } else {
                HPRCBadgeView(progress: progress, onTap: { viewModel.toggle() })
            }
        }
        .background(Color.clear)
    }
}

struct HPRCBadgeView: View {
    @ObservedObject var progress: UserProgress
    var onTap: () -> Void
    @State private var isHovering = false

    var body: some View {
        ZStack {
            // Marble/stone background
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "2C1810"), Color(hex: "4A3728"), Color(hex: "2C1810")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "D4AF37"), Color(hex: "C5A028"), Color(hex: "B8960F")],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: Color(hex: "D4AF37").opacity(0.3), radius: 8)

            VStack(spacing: 2) {
                // Laurel wreath
                Text("🏛️")
                    .font(.system(size: 22))

                Text("HPRC")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "D4AF37"))

                Text("ShopTalk")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color(hex: "C5A028"))

                // Roman numeral streak
                HStack(spacing: 2) {
                    Text("⚔️")
                        .font(.system(size: 8))
                    Text("XII")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(hex: "D4AF37"))
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

struct HPRCExpandedView: View {
    @ObservedObject var store: CardStore
    @ObservedObject var viewModel: WidgetViewModel
    @ObservedObject var progress: UserProgress
    @State private var showingStats = false
    @State private var isShowingAnswer = false

    var body: some View {
        ZStack {
            // Parchment/marble background
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "F5E6D3"), Color(hex: "E8D5C4"), Color(hex: "F5E6D3")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "D4AF37"), Color(hex: "8B7355")],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 15, y: 5)

            // Decorative columns
            HStack {
                RomanColumn()
                Spacer()
                RomanColumn()
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // Header with Roman styling
                HStack {
                    HPRCBadgeView(progress: progress, onTap: { viewModel.toggle() })
                        .scaleEffect(0.5)
                        .frame(width: 50, height: 42)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("CENTURION VII")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "8B4513"))
                        Text("MMCCL XP")
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: "8B7355"))
                    }

                    Button(action: { showingStats.toggle() }) {
                        Image(systemName: showingStats ? "scroll" : "chart.pie")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "8B4513"))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)

                    Button(action: { AppDelegate.shared?.toggleCalendarWindow() }) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "8B4513"))
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.toggle() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "8B7355"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Roman progress bar
                VStack(spacing: 4) {
                    HStack {
                        Text("Daily Conquest")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(hex: "8B4513"))
                        Spacer()
                        Text("XXXIV/XX")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "8B4513"))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: "8B7355").opacity(0.3))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "D4AF37"), Color(hex: "B8960F")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * min(1.0, Double(progress.cardsReviewedToday) / Double(progress.dailyGoal)))
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)

                // Decorative divider
                HStack {
                    Rectangle().fill(Color(hex: "D4AF37")).frame(height: 1)
                    Text("⚜️")
                        .font(.system(size: 10))
                    Rectangle().fill(Color(hex: "D4AF37")).frame(height: 1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if showingStats {
                    HPRCStatsView(progress: progress)
                } else {
                    HPRCCardView(store: store, progress: progress, isShowingAnswer: $isShowingAnswer)
                }
            }
        }
        .frame(width: 300, height: 450)
    }
}

struct RomanColumn: View {
    var body: some View {
        VStack(spacing: 0) {
            // Capital
            Rectangle()
                .fill(Color(hex: "D4AF37").opacity(0.5))
                .frame(width: 12, height: 8)
            // Shaft
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "E8D5C4"), Color(hex: "D4C4B0"), Color(hex: "E8D5C4")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 8, height: 380)
            // Base
            Rectangle()
                .fill(Color(hex: "D4AF37").opacity(0.5))
                .frame(width: 14, height: 10)
        }
        .opacity(0.6)
    }
}

struct HPRCCardView: View {
    @ObservedObject var store: CardStore
    @ObservedObject var progress: UserProgress
    @Binding var isShowingAnswer: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let card = store.currentCard {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(card.front)
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundColor(Color(hex: "2C1810"))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if isShowingAnswer {
                            HStack {
                                Rectangle().fill(Color(hex: "D4AF37")).frame(height: 1)
                                Text("📜")
                                    .font(.system(size: 8))
                                Rectangle().fill(Color(hex: "D4AF37")).frame(height: 1)
                            }

                            Text(card.back)
                                .font(.system(size: 13, design: .serif))
                                .foregroundColor(Color(hex: "4A3728"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: 180)

                Spacer()

                if isShowingAnswer {
                    VStack(spacing: 8) {
                        Text("Judge thy knowledge")
                            .font(.system(size: 10, design: .serif))
                            .foregroundColor(Color(hex: "8B4513"))

                        HStack(spacing: 8) {
                            RomanButton(label: "Nay", numeral: "I", color: Color(hex: "8B0000")) {
                                nextCard(correct: false)
                            }
                            RomanButton(label: "Difficult", numeral: "VI", color: Color(hex: "CD853F")) {
                                nextCard(correct: true)
                            }
                            RomanButton(label: "Good", numeral: "X", color: Color(hex: "228B22")) {
                                nextCard(correct: true)
                            }
                            RomanButton(label: "Easy", numeral: "IV D", color: Color(hex: "4169E1")) {
                                nextCard(correct: true)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 8)
                } else {
                    Button(action: { isShowingAnswer = true }) {
                        Text("Reveal Wisdom")
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(Color(hex: "F5E6D3"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "8B4513"), Color(hex: "654321")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "D4AF37"), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }

                // Navigation
                HStack {
                    Rectangle().fill(Color(hex: "D4AF37")).frame(height: 1)
                }
                .padding(.horizontal, 20)

                HStack {
                    Button(action: { store.previousCard(); isShowingAnswer = false }) {
                        Text("◀")
                            .foregroundColor(Color(hex: "8B4513"))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("\(toRoman(store.currentIndex + 1))/\(toRoman(store.filteredCards.count))")
                        .font(.system(size: 10, design: .serif))
                        .foregroundColor(Color(hex: "8B7355"))

                    Spacer()

                    Button(action: { store.randomCard(); isShowingAnswer = false }) {
                        Text("🎲")
                    }
                    .buttonStyle(.plain)

                    Button(action: { store.nextCard(); isShowingAnswer = false }) {
                        Text("▶")
                            .foregroundColor(Color(hex: "8B4513"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
            }
        }
    }

    func nextCard(correct: Bool) {
        progress.recordAnswer(correct: correct, deck: store.currentCard?.deck ?? "")
        isShowingAnswer = false
        store.nextCard()
    }

    func toRoman(_ num: Int) -> String {
        let values = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"), (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var result = ""
        var n = num
        for (value, numeral) in values {
            while n >= value {
                result += numeral
                n -= value
            }
        }
        return result.isEmpty ? "0" : result
    }
}

struct RomanButton: View {
    let label: String
    let numeral: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .serif))
                Text(numeral)
                    .font(.system(size: 7, design: .serif))
                    .opacity(0.7)
            }
            .foregroundColor(Color(hex: "F5E6D3"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(hex: "D4AF37").opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct HPRCStatsView: View {
    @ObservedObject var progress: UserProgress

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Calendar with Roman styling
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Campaign History")
                            .font(.system(size: 12, weight: .semibold, design: .serif))
                            .foregroundColor(Color(hex: "2C1810"))
                        Spacer()
                        HStack(spacing: 2) {
                            Text("⚔️")
                                .font(.system(size: 12))
                            Text("XII day conquest")
                                .font(.system(size: 10, design: .serif))
                                .foregroundColor(Color(hex: "8B4513"))
                        }
                    }

                    RomanCalendarHeatmap(data: progress.calendarData)
                }
                .padding(12)
                .background(Color(hex: "E8D5C4").opacity(0.5))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "D4AF37").opacity(0.5), lineWidth: 1)
                )

                // Pie Chart with Roman styling
                VStack(alignment: .leading, spacing: 8) {
                    Text("Territories Conquered")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundColor(Color(hex: "2C1810"))

                    HStack(spacing: 16) {
                        RomanPieChart(data: progress.deckStats)
                            .frame(width: 80, height: 80)

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(progress.deckStats.keys.sorted()), id: \.self) { key in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(romanColorForDeck(key))
                                        .frame(width: 8, height: 8)
                                    Text(key)
                                        .font(.system(size: 10, design: .serif))
                                        .foregroundColor(Color(hex: "4A3728"))
                                    Spacer()
                                    Text("\(progress.deckStats[key] ?? 0)%")
                                        .font(.system(size: 10, weight: .medium, design: .serif))
                                        .foregroundColor(Color(hex: "2C1810"))
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(hex: "E8D5C4").opacity(0.5))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "D4AF37").opacity(0.5), lineWidth: 1)
                )

                // Stats boxes
                HStack(spacing: 12) {
                    RomanStatBox(title: "Hodie", value: "XXXIV", subtitle: "scrolls")
                    RomanStatBox(title: "Victoria", value: "LXXVIII%", subtitle: "rate")
                    RomanStatBox(title: "Gloria", value: "+CCLXXX", subtitle: "XP")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    func romanColorForDeck(_ deck: String) -> Color {
        switch deck {
        case "file-types": return Color(hex: "8B0000")
        case "indexes": return Color(hex: "4169E1")
        case "algorithms": return Color(hex: "DAA520")
        case "interfaces": return Color(hex: "6B3FA0")
        default: return Color.gray
        }
    }
}

struct RomanCalendarHeatmap: View {
    let data: [Date: UserProgress.DayProgress]

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        HStack(spacing: 4) {
            ForEach(0..<14, id: \.self) { i in
                if let date = calendar.date(byAdding: .day, value: -(13 - i), to: today) {
                    let dayData = data[calendar.startOfDay(for: date)]
                    let intensity = min(1.0, Double(dayData?.cardsReviewed ?? 0) / 30.0)

                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(intensity > 0 ? Color(hex: "8B0000").opacity(0.3 + intensity * 0.7) : Color(hex: "D4AF37").opacity(0.2))
                            .frame(width: 16, height: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color(hex: "D4AF37").opacity(0.3), lineWidth: 0.5)
                            )

                        if i == 13 {
                            Text("Now")
                                .font(.system(size: 6, design: .serif))
                                .foregroundColor(Color(hex: "8B4513"))
                        }
                    }
                }
            }
        }
    }
}

struct RomanPieChart: View {
    let data: [String: Int]

    var body: some View {
        let total = data.values.reduce(0, +)
        let sortedKeys = data.keys.sorted()

        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 4

            var startAngle = Angle.degrees(-90)

            for key in sortedKeys {
                let value = data[key] ?? 0
                let angle = Angle.degrees(Double(value) / Double(total) * 360)

                let path = Path { p in
                    p.move(to: center)
                    p.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle + angle, clockwise: false)
                    p.closeSubpath()
                }

                context.fill(path, with: .color(romanColorForKey(key)))
                startAngle += angle
            }
        }
    }

    func romanColorForKey(_ key: String) -> Color {
        switch key {
        case "file-types": return Color(hex: "8B0000")
        case "indexes": return Color(hex: "4169E1")
        case "algorithms": return Color(hex: "DAA520")
        case "interfaces": return Color(hex: "6B3FA0")
        default: return Color.gray
        }
    }
}

struct RomanStatBox: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, design: .serif))
                .foregroundColor(Color(hex: "8B4513"))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "2C1810"))
            Text(subtitle)
                .font(.system(size: 8, design: .serif))
                .foregroundColor(Color(hex: "8B7355"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(hex: "E8D5C4").opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "D4AF37").opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Centro Core Widget (Deep Ocean Scientific Theme)

struct CentroCoreWidget: View {
    @ObservedObject var store: CardStore
    @ObservedObject var viewModel: WidgetViewModel
    @ObservedObject var progress: UserProgress

    var body: some View {
        Group {
            if viewModel.isExpanded {
                CentroExpandedView(store: store, viewModel: viewModel, progress: progress)
            } else {
                CentroCoreBadgeView(progress: progress, onTap: { viewModel.toggle() })
            }
        }
        .background(Color.clear)
    }
}

struct CentroCoreBadgeView: View {
    @ObservedObject var progress: UserProgress
    var onTap: () -> Void
    @State private var isHovering = false

    var body: some View {
        ZStack {
            // Deep ocean gradient background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "0B0F1A"), Color(hex: "121826"), Color(hex: "0B0F1A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "C6A85C").opacity(0.4), Color(hex: "E3C97A").opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color(hex: "C6A85C").opacity(0.15), radius: isHovering ? 12 : 6)

            VStack(spacing: 4) {
                // Centromere icon
                Text("⊕")
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .foregroundColor(Color(hex: "E3C97A"))

                Text("CENTRO")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "C6A85C"))
                    .tracking(1.5)

                Text("Core")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color(hex: "9AA4B2"))
                    .tracking(0.5)

                // Streak indicator
                HStack(spacing: 2) {
                    Circle()
                        .fill(Color(hex: "E6B84C"))
                        .frame(width: 4, height: 4)
                    Text("\(progress.streak)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "E6B84C"))
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

struct CentroExpandedView: View {
    @ObservedObject var store: CardStore
    @ObservedObject var viewModel: WidgetViewModel
    @ObservedObject var progress: UserProgress
    @State private var showingStats = false
    @State private var isShowingAnswer = false

    var body: some View {
        ZStack {
            // Deep ocean glassmorphism background
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "0B0F1A").opacity(0.95), Color(hex: "121826").opacity(0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "C6A85C").opacity(0.3), Color(hex: "4A6FA5").opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 20, y: 8)

            // Subtle dot pattern overlay
            GeometryReader { geo in
                Canvas { context, size in
                    let spacing: CGFloat = 8
                    for x in stride(from: 0, to: size.width, by: spacing) {
                        for y in stride(from: 0, to: size.height, by: spacing) {
                            context.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                                with: .color(Color(hex: "C6A85C").opacity(0.05))
                            )
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(spacing: 0) {
                // Header
                HStack {
                    CentroCoreBadgeView(progress: progress, onTap: { viewModel.toggle() })
                        .scaleEffect(0.5)
                        .frame(width: 50, height: 42)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Level \(progress.level)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "E3C97A"))
                        Text("\(progress.totalXP) XP")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "9AA4B2"))
                    }

                    Button(action: { showingStats.toggle() }) {
                        Image(systemName: showingStats ? "rectangle.stack" : "chart.pie")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "9AA4B2"))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)

                    Button(action: { AppDelegate.shared?.toggleCalendarWindow() }) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "9AA4B2"))
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.toggle() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "4A6FA5").opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // Progress bar
                VStack(spacing: 4) {
                    HStack {
                        Text("Daily Goal")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "9AA4B2"))
                        Spacer()
                        Text("\(progress.cardsReviewedToday)/\(progress.dailyGoal)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "E6EAF2"))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: "4A6FA5").opacity(0.2))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "E6B84C"), Color(hex: "C6A85C")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * min(1.0, Double(progress.cardsReviewedToday) / Double(progress.dailyGoal)))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)

                // Separator line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color(hex: "C6A85C").opacity(0.3), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.top, 8)

                if showingStats {
                    CentroStatsView(progress: progress)
                } else {
                    CentroCardView(store: store, progress: progress, isShowingAnswer: $isShowingAnswer)
                }
            }
        }
        .frame(width: 300, height: 450)
    }
}

struct CentroCardView: View {
    @ObservedObject var store: CardStore
    @ObservedObject var progress: UserProgress
    @Binding var isShowingAnswer: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let card = store.currentCard {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Term (front)
                        Text(card.front)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "E6EAF2"))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if isShowingAnswer {
                            // Subtle divider
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.clear, Color(hex: "C6A85C").opacity(0.2), Color.clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 0.5)

                            // Definition (back)
                            Text(card.back)
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "9AA4B2"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)

                            // Metadata tags (if available in source)
                            if !card.source.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(extractTags(from: card.source), id: \.self) { tag in
                                        Text(tag)
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(colorForTag(tag))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(colorForTag(tag).opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 180)

                Spacer()

                if isShowingAnswer {
                    // Confidence buttons
                    VStack(spacing: 8) {
                        Text("Rate your understanding")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "9AA4B2"))

                        HStack(spacing: 8) {
                            CentroButton(label: "Again", time: "1m", color: Color(hex: "4A6FA5").opacity(0.6)) {
                                nextCard(correct: false)
                            }
                            CentroButton(label: "Hard", time: "6m", color: Color(hex: "4A6FA5")) {
                                nextCard(correct: true)
                            }
                            CentroButton(label: "Good", time: "10m", color: Color(hex: "C6A85C")) {
                                nextCard(correct: true)
                            }
                            CentroButton(label: "Easy", time: "4d", color: Color(hex: "E6B84C")) {
                                nextCard(correct: true)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                } else {
                    Button(action: { isShowingAnswer = true }) {
                        Text("Reveal Definition")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "0B0F1A"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "E3C97A"), Color(hex: "C6A85C")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(10)
                            .shadow(color: Color(hex: "E6B84C").opacity(0.3), radius: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }

                // Separator
                Rectangle()
                    .fill(Color(hex: "C6A85C").opacity(0.2))
                    .frame(height: 0.5)

                // Navigation
                HStack {
                    Button(action: { store.previousCard(); isShowingAnswer = false }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color(hex: "9AA4B2"))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("\(store.currentIndex + 1)/\(store.filteredCards.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "9AA4B2"))

                    Spacer()

                    Button(action: { store.randomCard(); isShowingAnswer = false }) {
                        Image(systemName: "shuffle")
                            .foregroundColor(Color(hex: "9AA4B2"))
                    }
                    .buttonStyle(.plain)

                    Button(action: { store.nextCard(); isShowingAnswer = false }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color(hex: "9AA4B2"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            } else {
                Text("No cards")
                    .foregroundColor(Color(hex: "9AA4B2"))
            }
        }
    }

    func nextCard(correct: Bool) {
        progress.recordAnswer(correct: correct, deck: store.currentCard?.deck ?? "", app: "centro")
        isShowingAnswer = false
        store.nextCard()
    }

    func extractTags(from source: String) -> [String] {
        // Simple tag extraction - could be enhanced
        let keywords = ["CENP-A", "alpha-satellite", "HOR", "kinetochore", "chromatin", "DNA", "protein"]
        return keywords.filter { source.lowercased().contains($0.lowercased()) }
    }

    func colorForTag(_ tag: String) -> Color {
        if tag.contains("DNA") || tag.contains("satellite") || tag.contains("HOR") {
            return Color(hex: "C6A85C") // Gold for DNA/repeats
        } else if tag.contains("CENP") || tag.contains("protein") || tag.contains("chromatin") {
            return Color(hex: "4A6FA5") // Blue for proteins
        } else {
            return Color(hex: "E6B84C") // Amber for key concepts
        }
    }
}

struct CentroButton: View {
    let label: String
    let time: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                Text(time)
                    .font(.system(size: 8))
                    .opacity(0.7)
            }
            .foregroundColor(Color(hex: "E6EAF2"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CentroStatsView: View {
    @ObservedObject var progress: UserProgress

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Calendar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Activity Matrix")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "E6EAF2"))
                        Spacer()
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color(hex: "E6B84C"))
                                .frame(width: 4, height: 4)
                            Text("\(progress.streak) day streak")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "9AA4B2"))
                        }
                    }

                    CentroCalendarHeatmap(data: progress.calendarData)
                }
                .padding(12)
                .background(Color(hex: "121826").opacity(0.5))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "C6A85C").opacity(0.2), lineWidth: 0.5)
                )

                // Pie Chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category Distribution")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "E6EAF2"))

                    HStack(spacing: 16) {
                        CentroPieChart(data: progress.deckStats)
                            .frame(width: 80, height: 80)

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(progress.deckStats.keys.sorted()), id: \.self) { key in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(centroColorForDeck(key))
                                        .frame(width: 8, height: 8)
                                    Text(key)
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "9AA4B2"))
                                    Spacer()
                                    Text("\(progress.deckStats[key] ?? 0)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color(hex: "E6EAF2"))
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(hex: "121826").opacity(0.5))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "C6A85C").opacity(0.2), lineWidth: 0.5)
                )

                // Stats
                HStack(spacing: 12) {
                    CentroStatBox(title: "Today", value: "\(progress.cardsReviewedToday)", subtitle: "terms")
                    CentroStatBox(title: "Accuracy", value: "\(Int(progress.accuracyToday * 100))%", subtitle: "correct")
                    CentroStatBox(title: "XP", value: "+280", subtitle: "earned")
                }
            }
            .padding(12)
        }
    }

    func centroColorForDeck(_ deck: String) -> Color {
        switch deck {
        case "file-types": return Color(hex: "C6A85C")
        case "indexes": return Color(hex: "4A6FA5")
        case "algorithms": return Color(hex: "E6B84C")
        case "interfaces": return Color(hex: "E3C97A")
        default: return Color(hex: "9AA4B2")
        }
    }
}

struct CentroCalendarHeatmap: View {
    let data: [Date: UserProgress.DayProgress]

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        HStack(spacing: 4) {
            ForEach(0..<14, id: \.self) { i in
                if let date = calendar.date(byAdding: .day, value: -(13 - i), to: today) {
                    let dayData = data[calendar.startOfDay(for: date)]
                    let intensity = min(1.0, Double(dayData?.cardsReviewed ?? 0) / 30.0)

                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(intensity > 0 ? Color(hex: "E6B84C").opacity(0.3 + intensity * 0.7) : Color(hex: "4A6FA5").opacity(0.1))
                            .frame(width: 16, height: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color(hex: "C6A85C").opacity(0.2), lineWidth: 0.5)
                            )

                        if i == 13 {
                            Text("Now")
                                .font(.system(size: 6))
                                .foregroundColor(Color(hex: "9AA4B2"))
                        }
                    }
                }
            }
        }
    }
}

struct CentroPieChart: View {
    let data: [String: Int]

    var body: some View {
        let total = data.values.reduce(0, +)
        let sortedKeys = data.keys.sorted()

        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 4

            var startAngle = Angle.degrees(-90)

            for key in sortedKeys {
                let value = data[key] ?? 0
                let angle = Angle.degrees(Double(value) / Double(max(1, total)) * 360)

                let path = Path { p in
                    p.move(to: center)
                    p.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle + angle, clockwise: false)
                    p.closeSubpath()
                }

                context.fill(path, with: .color(centroColorForKey(key)))
                startAngle += angle
            }
        }
    }

    func centroColorForKey(_ key: String) -> Color {
        switch key {
        case "file-types": return Color(hex: "C6A85C")
        case "indexes": return Color(hex: "4A6FA5")
        case "algorithms": return Color(hex: "E6B84C")
        case "interfaces": return Color(hex: "E3C97A")
        default: return Color(hex: "9AA4B2")
        }
    }
}

struct CentroStatBox: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(Color(hex: "9AA4B2"))
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "E6EAF2"))
            Text(subtitle)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: "9AA4B2"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(hex: "121826").opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "C6A85C").opacity(0.2), lineWidth: 0.5)
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

                    // App breakdown for today
                    if let todayActivity = progress.appActivity[calendar.startOfDay(for: Date())] {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: "2196F3")).frame(width: 8, height: 8)
                                Text("VGJargon: \(todayActivity.vgJargonCards)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: "D4AF37")).frame(width: 8, height: 8)
                                Text("HPRC: \(todayActivity.hprcCards)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
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
                HStack(spacing: 8) {
                    Text("VG: \(activity.vgJargonCards)")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "2196F3"))
                    Text("HPRC: \(activity.hprcCards)")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "D4AF37"))
                }
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
