import SwiftUI
import CoreData

final class TimerStore: ObservableObject {
    // MARK: - Published UI state
    @Published var appState: AppState = .idle                 // .ended unused; we return to .idle on finish
    @Published var selectedIndex: Int = 1                     // default 25 min (index in steps)
    @Published var countdownValue: Int = 3                    // 3→0 overlay
    @Published var progress: CGFloat = 0.0                    // 0...1
    @Published var sessionColor: Color = .blue
    @Published var remainingSeconds: Int = 0                  // for optional HUD

    // Allowed minute steps (PRD)
    let steps: [Int] = [10, 25, 60, 90]

    // MARK: - Private timers/state
    private var countdownTimer: Timer?
    private var displayTimer: Timer?
    private var startDate: Date?
    private var endDate: Date?

    private var durationSecondsCurrentRun: TimeInterval = 0

    // Persistence (Core Data + restoration)
    private weak var context: NSManagedObjectContext?
    private let endDateKey = "pomm.activeEndDate"
    private let colorHueKey = "pomm.activeColorHue"
    private let durationKey = "pomm.activeDurationSeconds"
    private let selectedIndexKey = "pomm.activeSelectedIndex"
    private var lastHueSaved: Double = 0.55

    // Default animation used for state changes
    private let transitionAnim = Animation.easeInOut(duration: 0.25)

    // MARK: - Setup
    func attach(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Selection logic (drag increments)
    func adjustIndex(by deltaSteps: Int) {
        guard deltaSteps != 0 else { return }
        let newIndex = max(0, min(steps.count - 1, selectedIndex + deltaSteps))
        if newIndex != selectedIndex {
            selectedIndex = newIndex
            HapticsService.light()
        }
    }

    // MARK: - Start button flow
    func userTappedStart() {
        guard appState == .idle else { return }
        guard steps.indices.contains(selectedIndex) else { return }
        startCountdown()
    }

    // Cancel countdown on any interaction
    func cancelCountdownAndReturnToIdle() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownValue = 3
        if appState == .countingDown {
            withAnimation(transitionAnim) {
                appState = .idle
            }
        }
    }

    // MARK: - Countdown
    private func startCountdown() {
        NotificationService.requestAuthorizationIfNeeded()
        countdownValue = 3
        countdownTimer?.invalidate()
        withAnimation(transitionAnim) {
            appState = .countingDown
        }
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

    // MARK: - Running
    private func beginRun() {
        let minutes = steps[selectedIndex]
        durationSecondsCurrentRun = TimeInterval(minutes * 60)

        let now = Date()
        startDate = now
        endDate = now.addingTimeInterval(durationSecondsCurrentRun)

        // Pleasant random color (fixed S/B)
        let hue = Double.random(in: 0...1)
        lastHueSaved = hue
        sessionColor = Color(hue: hue, saturation: 0.65, brightness: 0.85)

        // Persist for restoration
        UserDefaults.standard.set(endDate, forKey: endDateKey)
        UserDefaults.standard.set(hue, forKey: colorHueKey)
        UserDefaults.standard.set(durationSecondsCurrentRun, forKey: durationKey)
        UserDefaults.standard.set(selectedIndex, forKey: selectedIndexKey)

        // Schedule end notification
        if let endDate { NotificationService.scheduleTimerEndNotification(at: endDate) }

        remainingSeconds = Int(durationSecondsCurrentRun)
        progress = 0.0

        withAnimation(transitionAnim) {
            appState = .running
        }
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

        if now >= end {
            completeRunAndReturnToSetup()
        }
    }

    // Stop via overlay Stop button (cancel w/o saving)
    func cancelRunAndReturnToSetup() {
        displayTimer?.invalidate(); displayTimer = nil
        countdownTimer?.invalidate(); countdownTimer = nil

        NotificationService.cancelPending()
        clearActivePersistence()

        // Reset temporal fields but KEEP selectedIndex (user’s last choice)
        progress = 0
        startDate = nil
        endDate = nil
        remainingSeconds = 0

        withAnimation(transitionAnim) {
            appState = .idle
        }
    }

    // Finish naturally: save + return to setup
    private func completeRunAndReturnToSetup() {
        displayTimer?.invalidate(); displayTimer = nil
        progress = 1.0

        // Save completed session
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

        // Reset temporal fields but KEEP selectedIndex (so the chosen duration remains)
        startDate = nil
        endDate = nil
        remainingSeconds = 0
        progress = 0

        withAnimation(transitionAnim) {
            appState = .idle
        }
    }

    private func clearActivePersistence() {
        let d = UserDefaults.standard
        d.removeObject(forKey: endDateKey)
        d.removeObject(forKey: colorHueKey)
        d.removeObject(forKey: durationKey)
        d.removeObject(forKey: selectedIndexKey)
    }

    // MARK: - Restoration (if app is killed unexpectedly)
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

        withAnimation(transitionAnim) {
            appState = .running
        }
        startDisplayTimer()
        tick()
    }

    // MARK: - Termination handling (cancel on swipe-kill)
    func handleAppWillTerminate() {
        NotificationService.cancelPending()
        clearActivePersistence()
    }
}
