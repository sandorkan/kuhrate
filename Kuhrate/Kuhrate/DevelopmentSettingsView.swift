//
//  DevelopmentSettingsView.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 26.12.2025.
//

import SwiftUI
import CoreData

struct DevelopmentSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Testing Tools"), footer: Text("Seed notes from today, last week, and up to 3 months ago to test the timeline grouping and review cycles.")) {
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
                }
                
                Section("Info") {
                    HStack {
                        Text("Environment")
                        Spacer()
                        Text("Development")
                            .foregroundColor(.secondary)
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
    
    private func seedData() {
        let calendar = Calendar.current
        let now = Date()
        
        // We fetch one category and source type to make the notes look real
        let categoryRequest: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        let category = (try? viewContext.fetch(categoryRequest))?.first
        
        let sourceRequest: NSFetchRequest<SourceTypeEntity> = SourceTypeEntity.fetchRequest()
        let sourceTypes = (try? viewContext.fetch(sourceRequest)) ?? []
        
        // Define periods: (daysOffset, count, name)
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
        // 1. Delete all actions and sessions using the helper to notify UI
        executeBatchDelete(entityName: "ReviewActionEntity")
        executeBatchDelete(entityName: "ReviewSessionEntity")
        
        // 2. Reset note status (using fetch because we need to update properties)
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
        // Delete everything using the helper to notify UI
        executeBatchDelete(entityName: "ReviewActionEntity")
        executeBatchDelete(entityName: "ReviewSessionEntity")
        executeBatchDelete(entityName: "NoteEntity")
        
        save()
        dismiss()
    }
    
    private func resetOnboarding() {
        // 1. Clear onboarding flag
        UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
        UserDefaults.standard.set(false, forKey: "hasSeededOnboarding")
        // 2. Wipe everything to allow clean re-seed
        deleteAllNotes()

        // 3. Restart app required to show onboarding again
        // User will need to close and reopen the app
    }
    
    /// Executes a batch delete and merges the changes into the context to update UI
    private func executeBatchDelete(entityName: String) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        // Return object IDs so we can merge changes
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
            do {
                try viewContext.save()
            } catch {
                print("❌ Failed to save context: \(error)")
            }
        }
    }
}

#Preview {
    DevelopmentSettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
