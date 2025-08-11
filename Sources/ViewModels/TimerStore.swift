//
//  TimerStore.swift
//  Pomm
//
//  Created by Igor Pascoal on 10/08/2025.
//
import SwiftUI
import CoreData

final class TimerStore: ObservableObject {
    // MARK: - Published UI state
    @Published var appState: AppState = .idle
    @Published var selectedIndex: Int = 0
    @Published var countdownValue: Int = 3
    @Published var progress: CGFloat = 0.0
    @Published var sessionColor: Color = .blue
    @Published var remainingSeconds: Int = 0               // for HUD

    // Allowed minute steps
    let steps: [Int] = [0, 5, 10, 15, 20, 25, 30, 40, 50, 60, 70, 80, 90]

    // MARK: - Private timers/state
    private var inactivityWorkItem: DispatchWorkItem?
    private var countdownTimer: Timer?
    private var displayTimer: Timer?

    private var startDate: Date?
    private var endDate: Date?
    private var durationSeconds: TimeInterval {
        TimeInterval(steps[selectedIndex] * 60)
    }

    // Persistence
    private weak var context: NSManagedObjectContext?
    private let endDateKey = "pomm.activeEndDate"
    private let colorHueKey = "pomm.activeColorHue"
    private let durationKey = "pomm.activeDurationSeconds"
    private let selectedIndexKey = "pomm.activeSelectedIndex"
    private var lastHueSaved: Double = 0.55                 // cached for save

    // MARK: - Setup
    func attach(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Public helpers (debug)
    func goToCountdown() { appState = .countingDown }
    func goToRunning()   { appState = .running }
    func goToEnded()     { appState = .ended }

    // MARK: - Selection logic
    func adjustIndex(by deltaSteps: Int) {
        guard deltaSteps != 0 else { return }
        let newIndex = max(0, min(steps.count - 1, selectedIndex + deltaSteps))
        if newIndex != selectedIndex {
            selectedIndex = newIndex
            HapticsService.light()
        }
    }

    // MARK: - Idle → countdown scheduling
    func scheduleCountdownAfterInactivity() {
        cancelPendingStart()
        guard steps[selectedIndex] > 0 else { return }
        let work = DispatchWorkItem { [weak self] in self?.startCountdown() }
        inactivityWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    func cancelPendingStart() {
        inactivityWorkItem?.cancel()
        inactivityWorkItem = nil
    }

    // MARK: - Countdown
    private func startCountdown() {
        NotificationService.requestAuthorizationIfNeeded()
        countdownValue = 3
        appState = .countingDown
        countdownTimer?.invalidate()
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

    func cancelCountdownAndReturnToIdle() {
        cancelPendingStart()
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownValue = 3
        if appState != .running { appState = .idle }
    }

    // MARK: - Start running
    private func beginRun() {
        let now = Date()
        startDate = now
        endDate = now.addingTimeInterval(durationSeconds)

        // Pleasant color (random hue, fixed S/B)
        let hue = Double.random(in: 0...1)
        lastHueSaved = hue
        sessionColor = Color(hue: hue, saturation: 0.65, brightness: 0.85)

        // Persist for restoration
        UserDefaults.standard.set(endDate, forKey: endDateKey)
        UserDefaults.standard.set(hue, forKey: colorHueKey)
        UserDefaults.standard.set(durationSeconds, forKey: durationKey)
        UserDefaults.standard.set(selectedIndex, forKey: selectedIndexKey)

        // Schedule end notification
        if let endDate { NotificationService.scheduleTimerEndNotification(at: endDate) }

        // Start UI ticking
        remainingSeconds = Int(durationSeconds)
        startDisplayTimer()

        progress = 0.0
        appState = .running
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

        if now >= end { finishRun() }
    }

    private func finishRun() {
        displayTimer?.invalidate()
        displayTimer = nil
        progress = 1.0
        appState = .ended

        // Save the session (best-effort)
        if let ctx = context, let start = startDate {
            let minutes = Int(round((durationSeconds) / 60.0))
            PersistenceService.saveSession(
                startDate: start,
                durationMinutes: minutes,
                completed: true,
                colorHue: lastHueSaved,
                context: ctx
            )
        }

        clearActivePersistence()
        // Notification sound handled by system + delegate; no extra sound needed.
    }

    // MARK: - Reset
    func reset() {
        cancelPendingStart()
        countdownTimer?.invalidate(); countdownTimer = nil
        displayTimer?.invalidate(); displayTimer = nil

        NotificationService.cancelPending()
        clearActivePersistence()

        appState = .idle
        selectedIndex = 0
        countdownValue = 3
        progress = 0
        sessionColor = .blue
        startDate = nil
        endDate = nil
        remainingSeconds = 0
    }

    private func clearActivePersistence() {
        let d = UserDefaults.standard
        d.removeObject(forKey: endDateKey)
        d.removeObject(forKey: colorHueKey)
        d.removeObject(forKey: durationKey)
        d.removeObject(forKey: selectedIndexKey)
    }

    // MARK: - Restoration
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
        appState = .running
        startDisplayTimer()
        tick()
    }

    // MARK: - Termination handling
    func handleAppWillTerminate() {
        NotificationService.cancelPending()
        clearActivePersistence()
    }
}

