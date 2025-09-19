import SwiftUI
import UserNotifications
import UIKit

@main
struct PommApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var store = TimerStore()

    init() {
        // Use the shared delegate defined in NotificationDelegate.swift
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(store)
        }
    }
}
