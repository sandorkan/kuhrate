//
//  KuhrateApp.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 14.12.2025.
//

import SwiftUI
import CoreData

@main
struct KuhrateApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
