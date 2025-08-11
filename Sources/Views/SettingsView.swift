//
//  SettingsView.swift
//  Pomm
//
//  Created by Igor Pascoal on 10/08/2025.
//
import SwiftUI

struct SettingsView: View {
    @AppStorage("showTimeWhileRunning") private var showTimeWhileRunning: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Show remaining time while running", isOn: $showTimeWhileRunning)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
