import SwiftUI

struct SettingsView: View {
    @AppStorage("showTimeWhileRunning") private var showTimeWhileRunning: Bool = false
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = true
    @AppStorage("breaksEnabled") private var breaksEnabled: Bool = true
    @AppStorage("showBreakCountdown") private var showBreakCountdown: Bool = false
    @AppStorage("showBreakQuotes") private var showBreakQuotes: Bool = false

    @StateObject private var debug = DebugController.shared
    @Environment(\.dismiss) private var dismiss

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "Pomm \(v) (\(b))"
    }

    @State private var secretTapCount = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Focus") {
                    Toggle("Show remaining time while running", isOn: $showTimeWhileRunning)
                    Toggle("Keep screen on during session", isOn: $keepScreenOn)
                }

                Section("Breaks") {
                    Toggle("Enable breaks after focus", isOn: $breaksEnabled)
                    Toggle("Show countdown during breaks", isOn: $showBreakCountdown)
                        .disabled(!breaksEnabled)
                        .opacity(breaksEnabled ? 1 : 0.5)

                    Toggle("Include quotes in break notifications", isOn: $showBreakQuotes)
                        .disabled(!breaksEnabled)
                        .opacity(breaksEnabled ? 1 : 0.5)
                }

                if debug.isUnlocked {
                    Section("Debug (ephemeral)") {
                        Toggle("Accelerate Timers", isOn: $debug.accelerate)
                        Picker("Speed", selection: $debug.speed) {
                            ForEach(DebugController.Speed.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .disabled(!debug.accelerate)
                        .opacity(debug.accelerate ? 1 : 0.6)
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        Text(versionString)
                            .foregroundStyle(.secondary)
                            .onTapGesture {
                                secretTapCount += 1
                                if secretTapCount >= 7 {
                                    debug.isUnlocked = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    secretTapCount = 0
                                }
                            }
                        Spacer()
                    }
                }
            }
            // Use the system-provided grouped background
            .scrollContentBackground(.automatic)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        // Always dark mode, but let system dark background show through
        .preferredColorScheme(.dark)
    }
}
