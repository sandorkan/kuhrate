//
//  SettingsView.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 26.12.2025.
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    
    // Notification Settings State
    @AppStorage("weeklyReviewDay") private var weeklyReviewDay: Int = 1 // Sunday
    @AppStorage("notificationHour") private var notificationHour: Int = 20 // 8 PM
    @AppStorage("notificationMinute") private var notificationMinute: Int = 0
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    
    // Export State
    @State private var isExporting = false
    @State private var exportURL: URL?
    
    // Debug State
    @State private var debugTapCount = 0
    @State private var showDebugMenu = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { oldValue, newValue in
                            if newValue {
                                NotificationManager.shared.requestPermission { granted in
                                    if !granted {
                                        notificationsEnabled = false
                                        // Ideally show alert to open settings
                                    } else {
                                        rescheduleNotifications()
                                    }
                                }
                            } else {
                                NotificationManager.shared.cancelAllNotifications()
                            }
                        }
                    
                    if notificationsEnabled {
                        Picker("Weekly Review Day", selection: $weeklyReviewDay) {
                            Text("Sunday").tag(1)
                            Text("Monday").tag(2)
                            Text("Tuesday").tag(3)
                            Text("Wednesday").tag(4)
                            Text("Thursday").tag(5)
                            Text("Friday").tag(6)
                            Text("Saturday").tag(7)
                        }
                        .onChange(of: weeklyReviewDay) { oldValue, newValue in
                            rescheduleNotifications()
                        }
                        
                        DatePicker("Notification Time", selection: Binding(
                            get: {
                                Calendar.current.date(from: DateComponents(hour: notificationHour, minute: notificationMinute)) ?? Date()
                            },
                            set: { newDate in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                notificationHour = components.hour ?? 20
                                notificationMinute = components.minute ?? 0
                                rescheduleNotifications()
                            }
                        ), displayedComponents: .hourAndMinute)
                    }
                }
                
                Section("Data Management") {
                    if let url = exportURL {
                        ShareLink(item: url) {
                            Label("Download Export File", systemImage: "square.and.arrow.up")
                        }
                        
                        Button("Generate New Export") {
                            exportURL = nil
                            exportData()
                        }
                        .foregroundColor(.blue)
                    } else {
                        Button {
                            exportData()
                        } label: {
                            if isExporting {
                                ProgressView()
                            } else {
                                Label("Export Data (JSON)", systemImage: "arrow.down.doc")
                            }
                        }
                        .disabled(isExporting)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (1)")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        debugTapCount += 1
                        if debugTapCount >= 5 {
                            showDebugMenu = true
                            debugTapCount = 0
                        }
                    }
                }
                
                if showDebugMenu {
                    Section("Developer Tools") {
                        Button {
                            seedData()
                        } label: {
                            Label("Seed Sample Notes", systemImage: "plus.square.on.square")
                        }
                        
                        Button(role: .destructive) {
                            resetStatus()
                        } label: {
                            Label("Reset All Review Progress", systemImage: "arrow.counterclockwise")
                        }

                        Button(role: .destructive) {
                            deleteAllNotes()
                        } label: {
                            Label("Delete All Notes", systemImage: "trash")
                        }
                        
                        Button(role: .destructive) {
                            resetOnboarding()
                        } label: {
                            Label("Reset Onboarding & Notes", systemImage: "sparkles")
                        }
                        
                        Button {
                            NotificationManager.shared.scheduleAllNotifications(context: viewContext)
                        } label: {
                            Label("Test Notification Schedule", systemImage: "bell.badge")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func rescheduleNotifications() {
        NotificationManager.shared.scheduleAllNotifications(context: viewContext)
    }
    
    // MARK: - Export Logic
    
    private func exportData() {
        isExporting = true
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        
        do {
            let notes = try viewContext.fetch(request)
            
            let exportNotes = notes.map { note in
                let cycleName = ReviewCycle(rawValue: note.reviewCycle)?.title ?? "Unknown"
                
                return ExportNote(
                    id: note.id?.uuidString,
                    content: note.content,
                    createdDate: note.createdDate,
                    category: note.category?.name,
                    tags: (note.tags?.allObjects as? [TagEntity])?.compactMap { $0.name } ?? [],
                    source: note.source,
                    sourceType: note.sourceType?.name,
                    status: ExportStatus(
                        cycle: cycleName,
                        isArchived: note.isArchived,
                        lastReviewed: note.lastReviewedDate
                    )
                )
            }
            
            let container = ExportContainer(
                version: "1.0",
                exportDate: Date(),
                notes: exportNotes
            )
            
            // Encode to JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(container)
            
            // Write to Temp File
            let fileName = "Kuhrate_Export_\(ISO8601DateFormatter().string(from: Date())).json"
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            
            self.exportURL = fileURL
            self.isExporting = false
            
        } catch {
            print("❌ Export failed: \(error)")
            self.isExporting = false
        }
    }
    
    // MARK: - Debug Logic
    
    private func seedData() {
        let calendar = Calendar.current
        let now = Date()
        
        let categoryRequest: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        let category = (try? viewContext.fetch(categoryRequest))?.first
        
        let sourceRequest: NSFetchRequest<SourceTypeEntity> = SourceTypeEntity.fetchRequest()
        let sourceTypes = (try? viewContext.fetch(sourceRequest)) ?? []
        
        let dataPoints = [
            (0, 3, "Current Week"),
            (-7, 3, "Last Week"),
            (-35, 4, "1 Month Ago"),
            (-65, 3, "2 Months Ago"),
            (-95, 3, "3 Months Ago")
        ]
        
        for point in dataPoints {
            let baseDate = calendar.date(byAdding: .day, value: point.0, to: now) ?? now
            
            for i in 1...point.1 {
                let note = NoteEntity(context: viewContext)
                note.id = UUID()
                note.createdDate = calendar.date(byAdding: .minute, value: -i * 30, to: baseDate)
                note.content = "\(point.2) Insight #\(i)\nThis is a sample insight captured for testing the timeline grouping and review flow."
                note.reviewCycle = 0
                note.isArchived = false
                note.category = category
                note.source = "Sample Source \(i)"
                note.sourceType = sourceTypes.randomElement()
            }
        }
        
        save()
        dismiss()
    }
    
    private func resetStatus() {
        executeBatchDelete(entityName: "ReviewActionEntity")
        executeBatchDelete(entityName: "ReviewSessionEntity")
        
        let noteRequest: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        if let notes = try? viewContext.fetch(noteRequest) {
            for note in notes {
                note.reviewCycle = 0
                note.isArchived = false
                note.lastReviewedDate = nil
            }
        }
        
        save()
        dismiss()
    }
    
    private func deleteAllNotes() {
        executeBatchDelete(entityName: "ReviewActionEntity")
        executeBatchDelete(entityName: "ReviewSessionEntity")
        executeBatchDelete(entityName: "NoteEntity")
        
        save()
        dismiss()
    }
    
    private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasSeededOnboarding")
        UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
        deleteAllNotes()
    }
    
    private func executeBatchDelete(entityName: String) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        do {
            let result = try viewContext.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
            }
        } catch {
            print("❌ Failed to batch delete \(entityName): \(error)")
        }
    }
    
    private func save() {
        if viewContext.hasChanges {
            try? viewContext.save()
        }
    }
}

// MARK: - Export Models

struct ExportContainer: Codable {
    let version: String
    let exportDate: Date
    let notes: [ExportNote]
}

struct ExportNote: Codable {
    let id: String?
    let content: String?
    let createdDate: Date?
    let category: String?
    let tags: [String]
    let source: String?
    let sourceType: String?
    let status: ExportStatus
}

struct ExportStatus: Codable {
    let cycle: String
    let isArchived: Bool
    let lastReviewed: Date?
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
