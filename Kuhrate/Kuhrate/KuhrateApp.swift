//
//  KuhrateApp.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 14.12.2025.
//

import CoreData
import SwiftUI
import UserNotifications

@main
struct KuhrateApp: App {
    let persistenceController = PersistenceController.shared
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

    init() {
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        // Schedule notifications on app launch (if authorized)
        let context = persistenceController.container.viewContext
        NotificationManager.shared.scheduleAllNotifications(context: context)
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(showOnboarding: $showOnboarding)
                }
                .onAppear {
                    // Update badge when app opens
                    NotificationManager.shared.updateBadge(context: persistenceController.container.viewContext)
                }
        }
    }
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    // Handle notification tap (when app is in background/closed)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        if let reviewType = userInfo["reviewType"] as? String {
            print("📱 User tapped notification for: \(reviewType)")
            // TODO: Deep link to appropriate review session
            // This could be handled via a custom URL scheme or notification
        }

        completionHandler()
    }

    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is open
        completionHandler([.banner, .sound, .badge])
    }
}
