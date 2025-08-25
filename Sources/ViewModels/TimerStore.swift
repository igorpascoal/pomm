import SwiftUI
import CoreData

final class TimerStore: ObservableObject {
    // MARK: - Published UI state
    @Published var appState: AppState = .idle
    @Published var selectedIndex: Int = 1                     // default 25 min
    @Published var countdownValue: Int = 3
    @Published var progress: CGFloat = 0.0
    @Published var sessionColor: Color = .blue
    @Published var remainingSeconds: Int = 0

    let steps: [Int] = [10, 25, 60, 90]

    private var countdownTimer: Timer?
    private var displayTimer: Timer?
    private var startDate: Date?
    private var endDate: Date?
    private var durationSecondsCurrentRun: TimeInterval = 0

    private weak var context: NSManagedObjectContext?
    private let endDateKey = "pomm.activeEndDate"
    private let colorHueKey = "pomm.activeColorHue"
    private let durationKey = "pomm.activeDurationSeconds"
    private let selectedIndexKey = "pomm.activeSelectedIndex"
    private var lastHueSaved: Double = 0.55

    private let transitionAnim = Animation.easeInOut(duration: 0.25)

    // Setup
    func attach(context: NSManagedObjectContext) { self.context = context }

    // Selection
    func adjustIndex(by deltaSteps: Int) {
        guard deltaSteps != 0 else { return }
        let newIndex = max(0, min(steps.count - 1, selectedIndex + deltaSteps))
        if newIndex != selectedIndex {
            selectedIndex = newIndex
            HapticsService.light()
        }
    }

    // Start button
    func userTappedStart() {
        guard appState == .idle, steps.indices.contains(selectedIndex) else { return }
        HapticsService.medium() // feedback on starting
        startCountdown()
    }

    // Cancel countdown
    func cancelCountdownAndReturnToIdle() {
        countdownTimer?.invalidate(); countdownTimer = nil
        countdownValue = 3
        if appState == .countingDown {
            HapticsService.rigid() // small “cancel” haptic
            withAnimation(transitionAnim) { appState = .idle }
        }
    }

    // Countdown
    private func startCountdown() {
        NotificationService.requestAuthorizationIfNeeded()
        countdownValue = 3
        countdownTimer?.invalidate()
        withAnimation(transitionAnim) { appState = .countingDown }
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self else { return }
            if self.countdownValue > 0 { self.countdownValue -= 1 }
            if self.countdownValue <= 0 {
                t.invalidate(); self.countdownTimer = nil
                self.beginRun()
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    // Running
    private func beginRun() {
        let minutes = steps[selectedIndex]
        durationSecondsCurrentRun = TimeInterval(minutes * 60)

        let now = Date()
        startDate = now
        endDate = now.addingTimeInterval(durationSecondsCurrentRun)

        let hue = Double.random(in: 0...1)
        lastHueSaved = hue
        sessionColor = Color(hue: hue, saturation: 0.65, brightness: 0.85)

        UserDefaults.standard.set(endDate, forKey: endDateKey)
        UserDefaults.standard.set(hue, forKey: colorHueKey)
        UserDefaults.standard.set(durationSecondsCurrentRun, forKey: durationKey)
        UserDefaults.standard.set(selectedIndex, forKey: selectedIndexKey)

        if let endDate { NotificationService.scheduleTimerEndNotification(at: endDate) }

        remainingSeconds = Int(durationSecondsCurrentRun)
        progress = 0.0

        HapticsService.success() // “go” haptic
        withAnimation(transitionAnim) { appState = .running }
        startDisplayTimer()
    }

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(displayTimer!, forMode: .common)
    }

    private func tick() {
        guard let start = startDate, let end = endDate else { return }
        let now = Date()
        let total = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)

        let p = max(0, min(1, elapsed / max(0.001, total)))
        if progress != CGFloat(p) { progress = CGFloat(p) }

        let remaining = max(0, Int(ceil(end.timeIntervalSince(now))))
        if remainingSeconds != remaining { remainingSeconds = remaining }

        if now >= end { completeRunAndReturnToSetup() }
    }

    // Stop via Stop button (cancel, no save)
    func cancelRunAndReturnToSetup() {
        displayTimer?.invalidate(); displayTimer = nil
        countdownTimer?.invalidate(); countdownTimer = nil

        NotificationService.cancelPending()
        clearActivePersistence()

        progress = 0
        startDate = nil
        endDate = nil
        remainingSeconds = 0

        HapticsService.warning() // stop haptic
        withAnimation(transitionAnim) { appState = .idle }
    }

    // Finish naturally (save)
    private func completeRunAndReturnToSetup() {
        displayTimer?.invalidate(); displayTimer = nil
        progress = 1.0

        if let ctx = context, let start = startDate {
            let minutes = Int(round(durationSecondsCurrentRun / 60.0))
            PersistenceService.saveSession(
                startDate: start,
                durationMinutes: minutes,
                completed: true,
                colorHue: lastHueSaved,
                context: ctx
            )
        }

        NotificationService.cancelPending()
        clearActivePersistence()

        startDate = nil
        endDate = nil
        remainingSeconds = 0
        progress = 0

        HapticsService.success() // completion haptic
        withAnimation(transitionAnim) { appState = .idle }
    }

    private func clearActivePersistence() {
        let d = UserDefaults.standard
        d.removeObject(forKey: endDateKey)
        d.removeObject(forKey: colorHueKey)
        d.removeObject(forKey: durationKey)
        d.removeObject(forKey: selectedIndexKey)
    }

    // Restoration
    func restoreIfNeeded() {
        guard appState == .idle else { return }
        let d = UserDefaults.standard
        guard let savedEnd = d.object(forKey: endDateKey) as? Date, savedEnd > Date() else {
            clearActivePersistence(); return
        }
        let savedDuration = d.object(forKey: durationKey) as? TimeInterval ?? 0
        let savedIndex = d.object(forKey: selectedIndexKey) as? Int ?? selectedIndex
        guard savedDuration > 0 else { clearActivePersistence(); return }

        let hue = d.object(forKey: colorHueKey) as? Double ?? 0.55
        lastHueSaved = hue
        sessionColor = Color(hue: hue, saturation: 0.65, brightness: 0.85)

        selectedIndex = max(0, min(steps.count - 1, savedIndex))
        startDate = savedEnd.addingTimeInterval(-savedDuration)
        endDate = savedEnd
        durationSecondsCurrentRun = savedDuration

        withAnimation(transitionAnim) { appState = .running }
        startDisplayTimer()
        tick()
    }

    // Termination handling
    func handleAppWillTerminate() {
        NotificationService.cancelPending()
        clearActivePersistence()
    }
}
