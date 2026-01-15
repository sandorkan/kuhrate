//
//  KuhrateApp.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 14.12.2025.
//

import CoreData
import SwiftUI

@main
struct KuhrateApp: App {
    let persistenceController = PersistenceController.shared
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(showOnboarding: $showOnboarding)
                }
        }
    }
}
