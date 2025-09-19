import SwiftUI
import CoreData

@MainActor
final class TimerStore: ObservableObject {
    // MARK: - Published UI state
    @Published var appState: AppState = .idle
    @Published var selectedIndex: Int = 1                     // default 25 min
    @Published var countdownValue: Int = 3
    @Published var progress: CGFloat = 0.0                    // focus OR break progress (0...1)
    @Published var sessionColor: Color = .blue
    @Published var remainingSeconds: Int = 0                  // focus OR break remaining

    // Focus steps
    let steps: [Int] = [10, 25, 60, 90]

    // Timers
    private var countdownTimer: Timer?
    private var displayTimer: Timer?

    // Focus timing
    private var focusStart: Date?
    private var focusEnd: Date?
    private var focusDurationSeconds: TimeInterval = 0

    // Break timing
    private var breakStart: Date?
    private var breakEnd: Date?
    private var breakDurationSeconds: TimeInterval = 0

    // Persistence
    private weak var context: NSManagedObjectContext?

    private let endDateKey = "pomm.activeEndDate"              // focus end
    private let colorHueKey = "pomm.activeColorHue"
    private let durationKey = "pomm.activeDurationSeconds"     // focus duration seconds (scaled)
    private let selectedIndexKey = "pomm.activeSelectedIndex"

    private let breakEndKey = "pomm.breakEndDate"
    private let breakDurationKey = "pomm.breakDurationSeconds" // scaled
    private let phaseKey = "pomm.activePhase"                  // "focus" or "break"

    private var lastHueSaved: Double = 0.55

    private let transitionAnim = Animation.easeInOut(duration: 0.25)

    // MARK: - Setup
    func attach(context: NSManagedObjectContext) { self.context = context }

    // MARK: - Selection
    func adjustIndex(by deltaSteps: Int) {
        guard deltaSteps != 0 else { return }
        let newIndex = max(0, min(steps.count - 1, selectedIndex + deltaSteps))
        if newIndex != selectedIndex {
            selectedIndex = newIndex
            HapticsService.light()
        }
    }

    // MARK: - Start focus (via Start button)
    func userTappedStart() {
        guard appState == .idle, steps.indices.contains(selectedIndex) else { return }
        HapticsService.medium()
        startCountdown()
    }

    func cancelCountdownAndReturnToIdle() {
        countdownTimer?.invalidate(); countdownTimer = nil
        countdownValue = 3
        if appState == .countingDown {
            HapticsService.rigid()
            withAnimation(transitionAnim) { appState = .idle }
        }
    }

    private func startCountdown() {
        NotificationService.requestAuthorizationIfNeeded()
        countdownValue = 3
        countdownTimer?.invalidate()

        withAnimation(transitionAnim) { appState = .countingDown }

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            // Hop back to the main actor for any state access/mutation
            Task { @MainActor in
                guard let self = self else { return }
                if self.countdownValue > 0 { self.countdownValue -= 1 }
                if self.countdownValue <= 0 {
                    t.invalidate()
                    self.countdownTimer = nil
                    self.beginFocus() // main-actor call is now OK
                }
            }
        }
        if let countdownTimer { RunLoop.main.add(countdownTimer, forMode: .common) }
    }


    // MARK: - Focus run
    private func beginFocus() {
        let realMinutes = steps[selectedIndex]
        let realSeconds = TimeInterval(realMinutes * 60)
        let scaled = realSeconds * DebugController.shared.effectiveMultiplier

        focusDurationSeconds = scaled
        focusStart = Date()
        focusEnd = focusStart!.addingTimeInterval(focusDurationSeconds)

        // Random pleasant color
        let hue = Double.random(in: 0...1)
        lastHueSaved = hue
        sessionColor = Color(hue: hue, saturation: 0.65, brightness: 0.85)

        // Persist focus phase (scaled numbers to match scheduled end)
        let d = UserDefaults.standard
        d.set(focusEnd, forKey: endDateKey)
        d.set(hue, forKey: colorHueKey)
        d.set(focusDurationSeconds, forKey: durationKey)
        d.set(selectedIndex, forKey: selectedIndexKey)
        d.set("focus", forKey: phaseKey)

        // Schedule "focus done — take a X-minute break" (message shows real break minutes)
        let breaksEnabled = d.object(forKey: "breaksEnabled") as? Bool ?? true
        let realBreakMinutes = breaksEnabled ? computeBreakMinutes(forFocus: realMinutes) : nil
        if let end = focusEnd {
            NotificationService.scheduleFocusEndNotification(at: end, breakMinutes: realBreakMinutes)
        }

        remainingSeconds = Int(focusDurationSeconds)
        progress = 0.0

        HapticsService.success()
        withAnimation(transitionAnim) { appState = .running }
        startDisplayTimer()
    }

    // MARK: - Break run
    private func beginBreak() {
        let d = UserDefaults.standard
        let breaksEnabled = d.object(forKey: "breaksEnabled") as? Bool ?? true
        guard breaksEnabled else {
            finishFocusAndReturnToSetup()
            return
        }

        // Compute proportional break duration (real), then scale for wall time
        let realFocusMinutes = steps[selectedIndex]
        let realBreakMinutes = computeBreakMinutes(forFocus: realFocusMinutes)
        let realBreakSeconds = TimeInterval(realBreakMinutes * 60)
        let scaledBreak = realBreakSeconds * DebugController.shared.effectiveMultiplier

        breakDurationSeconds = scaledBreak
        breakStart = Date()
        breakEnd = breakStart!.addingTimeInterval(breakDurationSeconds)

        d.set(breakEnd, forKey: breakEndKey)
        d.set(breakDurationSeconds, forKey: breakDurationKey)
        d.set("break", forKey: phaseKey)

        // NEW: includeQuote toggle read from AppStorage / UserDefaults (default false)
        let includeQuote = d.object(forKey: "showBreakQuotes") as? Bool ?? false
        if let be = breakEnd {
            NotificationService.scheduleBreakEndNotification(at: be, includeQuote: includeQuote)
        }

        remainingSeconds = Int(breakDurationSeconds)
        progress = 0.0

        withAnimation(transitionAnim) { appState = .breakRunning }
        startDisplayTimer()
    }


    /// ceil(focus/25)*5 rule (minutes)
    private func computeBreakMinutes(forFocus focusMinutes: Int) -> Int {
        let blocks = ceil(Double(focusMinutes) / 25.0)
        return Int(blocks) * 5
    }

    // MARK: - Tick / display timer
    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick() // safe: tick() is main-actor isolated
            }
        }
        if let displayTimer { RunLoop.main.add(displayTimer, forMode: .common) }
    }


    private func tick() {
        switch appState {
        case .running:
            guard let s = focusStart, let e = focusEnd else { return }
            let now = Date()
            let total = e.timeIntervalSince(s)
            let elapsed = now.timeIntervalSince(s)
            let p = max(0, min(1, elapsed / max(0.001, total)))
            if progress != CGFloat(p) { progress = CGFloat(p) }
            let remaining = max(0, Int(ceil(e.timeIntervalSince(now))))
            if remainingSeconds != remaining { remainingSeconds = remaining }
            if now >= e { completeFocusPhase() }

        case .breakRunning:
            guard let s = breakStart, let e = breakEnd else { return }
            let now = Date()
            let total = e.timeIntervalSince(s)
            let elapsed = now.timeIntervalSince(s)
            let p = max(0, min(1, elapsed / max(0.001, total)))
            if progress != CGFloat(p) { progress = CGFloat(p) }
            let remaining = max(0, Int(ceil(e.timeIntervalSince(now))))
            if remainingSeconds != remaining { remainingSeconds = remaining }
            if now >= e { endBreakAndReturnToSetup() }

        default:
            break
        }
    }

    // MARK: - Focus finishing path
    private func completeFocusPhase() {
        // Save the focus session (real minutes inferred from selection)
        if let ctx = context, let start = focusStart {
            let minutes = steps[selectedIndex]
            PersistenceService.saveSession(
                startDate: start,
                durationMinutes: minutes,
                completed: true,
                colorHue: lastHueSaved,
                context: ctx
            )
        }
        beginBreak()
    }

    private func finishFocusAndReturnToSetup() {
        NotificationService.cancelFocusPending()    // was: cancelPending()
        clearActivePersistence()
        focusStart = nil; focusEnd = nil
        focusDurationSeconds = 0
        remainingSeconds = 0
        progress = 0
        HapticsService.success()
        withAnimation(transitionAnim) { appState = .idle }
    }

    // MARK: - Break finishing path
    private func endBreakAndReturnToSetup() {
        // Do NOT cancel immediately or you may preempt delivery.
        // Let iOS deliver, then tidy pending after a short delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NotificationService.cancelBreakPending()
        }
        clearActivePersistence()
        breakStart = nil; breakEnd = nil
        breakDurationSeconds = 0
        remainingSeconds = 0
        progress = 0
        withAnimation(transitionAnim) { appState = .idle }
    }


    // User tapped Stop during break → skip
    func skipBreakAndReturnToSetup() {
        displayTimer?.invalidate(); displayTimer = nil
        NotificationService.cancelBreakPending()   // was: cancelPending()
        clearActivePersistence()
        breakStart = nil; breakEnd = nil
        breakDurationSeconds = 0
        remainingSeconds = 0
        progress = 0
        HapticsService.warning()
        withAnimation(transitionAnim) { appState = .idle }
    }


    // Stop during focus (cancel, no save)
    func cancelRunAndReturnToSetup() {
        displayTimer?.invalidate(); displayTimer = nil
        countdownTimer?.invalidate(); countdownTimer = nil
        NotificationService.cancelFocusPending()    // was: cancelPending()
        clearActivePersistence()
        focusStart = nil; focusEnd = nil
        focusDurationSeconds = 0
        remainingSeconds = 0
        progress = 0
        HapticsService.warning()
        withAnimation(transitionAnim) { appState = .idle }
    }

    private func clearActivePersistence() {
        let d = UserDefaults.standard
        d.removeObject(forKey: endDateKey)
        d.removeObject(forKey: colorHueKey)
        d.removeObject(forKey: durationKey)
        d.removeObject(forKey: selectedIndexKey)
        d.removeObject(forKey: breakEndKey)
        d.removeObject(forKey: breakDurationKey)
        d.removeObject(forKey: phaseKey)
    }

    // MARK: - Restoration
    func restoreIfNeeded() {
        guard appState == .idle else { return }
        let d = UserDefaults.standard
        let phase = d.string(forKey: phaseKey) ?? ""

        if phase == "focus",
           let savedEnd = d.object(forKey: endDateKey) as? Date,
           savedEnd > Date() {
            let savedDuration = d.object(forKey: durationKey) as? TimeInterval ?? 0
            let savedIndex = d.object(forKey: selectedIndexKey) as? Int ?? selectedIndex
            guard savedDuration > 0 else { clearActivePersistence(); return }

            let hue = d.object(forKey: colorHueKey) as? Double ?? 0.55
            lastHueSaved = hue
            sessionColor = Color(hue: hue, saturation: 0.65, brightness: 0.85)

            selectedIndex = max(0, min(steps.count - 1, savedIndex))
            focusStart = savedEnd.addingTimeInterval(-savedDuration)
            focusEnd = savedEnd
            focusDurationSeconds = savedDuration

            withAnimation(transitionAnim) { appState = .running }
            startDisplayTimer()
            tick()
            return
        }

        if phase == "break",
           let savedBreakEnd = d.object(forKey: breakEndKey) as? Date,
           savedBreakEnd > Date() {
            let savedBreakDuration = d.object(forKey: breakDurationKey) as? TimeInterval ?? 0
            let hue = d.object(forKey: colorHueKey) as? Double ?? 0.55
            lastHueSaved = hue
            sessionColor = Color(hue: hue, saturation: 0.65, brightness: 0.85)

            breakStart = savedBreakEnd.addingTimeInterval(-savedBreakDuration)
            breakEnd = savedBreakEnd
            breakDurationSeconds = savedBreakDuration

            withAnimation(transitionAnim) { appState = .breakRunning }
            startDisplayTimer()
            tick()
            return
        }

        clearActivePersistence()
    }

    // MARK: - Termination handling
    func handleAppWillTerminate() {
        NotificationService.cancelAllPending()   // was: cancelPending()
        clearActivePersistence()
    }
}
