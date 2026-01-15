//
//  Persistence.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 14.12.2025.
//

import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Seed predefined categories
        seedCategoriesIfNeeded(context: viewContext)
        // Seed predefined source types
        seedSourceTypesIfNeeded(context: viewContext)

        let category = CategoryEntity(context: viewContext)
        category.id = UUID()
        category.name = "Saluton"
        category.color = "#06b6d4"
        category.isCustom = false
        category.sortOrder = 0
        
        // Create sample notes for preview
        for i in 0..<3 {
            let newNote = NoteEntity(context: viewContext)
            newNote.id = UUID()
            newNote.content = "Sample note \(i + 1)"
            newNote.createdDate = Date().addingTimeInterval(TimeInterval(-i * 3600))
            
            if i == 0 {
                newNote.category = category
            }
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Kuhrate")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let url = storeDescription.url {
                print("Core Data database file path: \(url.path)")
            }
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Seed predefined categories on first launch
        PersistenceController.seedCategoriesIfNeeded(context: container.viewContext)
        // Seed predefined source types on first launch
        PersistenceController.seedSourceTypesIfNeeded(context: container.viewContext)
        // Seed onboarding content on first launch
        PersistenceController.seedOnboardingNotes(context: container.viewContext)
    }

    // MARK: - Category Seeding

    /// Seeds the predefined categories if they don't exist yet
    static func seedCategoriesIfNeeded(context: NSManagedObjectContext) {
        // Check if categories already exist
        let fetchRequest: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()

        do {
            let count = try context.count(for: fetchRequest)
            if count > 0 {
                return
            }
        } catch {
            print("Error checking for existing categories: \(error)")
            return
        }

        // Define predefined categories (name, color, sortOrder)
        // Ordered alphabetically
        let predefinedCategories = [
            ("Career", "#06b6d4", 1),
            ("Communication", "#84cc16", 2),
            ("Finance", "#f59e0b", 3),
            ("Health", "#10b981", 4),
            ("Leadership", "#8b5cf6", 5),
            ("Learning", "#fb923c", 6),
            ("Mindset", "#ef4444", 7),
            ("Productivity", "#137fec", 8),
            ("Relationships", "#ec4899", 9)
        ]

        // Create each category
        for (name, color, order) in predefinedCategories {
            let category = CategoryEntity(context: context)
            category.id = UUID()
            category.name = name
            category.color = color
            category.isCustom = false  // These are predefined
            category.sortOrder = Int16(order)
        }

        // Save the categories
        do {
            try context.save()
            print("✅ Seeded \(predefinedCategories.count) predefined categories")
        } catch {
            let nsError = error as NSError
            print("❌ Error seeding categories: \(nsError), \(nsError.userInfo)")
        }
    }

    // MARK: - SourceType Seeding

    /// Seeds the predefined source types if they don't exist yet
    static func seedSourceTypesIfNeeded(context: NSManagedObjectContext) {
        // Check if source types already exist
        let fetchRequest: NSFetchRequest<SourceTypeEntity> = SourceTypeEntity.fetchRequest()

        do {
            let count = try context.count(for: fetchRequest)
            if count > 0 {
                return
            }
        } catch {
            print("Error checking for existing source types: \(error)")
            return
        }

        // Define predefined source types (name, icon, sortOrder)
        // Ordered logically or alphabetically
        let predefinedSourceTypes = [
            ("Link", "link", 1),
            ("Book", "book.closed", 2),
            ("Video", "film", 3),
            ("Podcast", "mic", 4),
            ("Article", "newspaper", 5),
            ("Person", "person", 6),
            ("Other", "asterisk", 7)
        ]

        // Create each source type
        for (name, icon, order) in predefinedSourceTypes {
            let sourceType = SourceTypeEntity(context: context)
            sourceType.id = UUID()
            sourceType.name = name
            sourceType.icon = icon
            sourceType.isCustom = false
            sourceType.sortOrder = Int16(order)
        }

        // Save the source types
        do {
            try context.save()
            print("✅ Seeded \(predefinedSourceTypes.count) predefined source types")
        } catch {
            let nsError = error as NSError
            print("❌ Error seeding source types: \(nsError), \(nsError.userInfo)")
        }
    }
    
    // MARK: - Onboarding Seeding
    
    /// Seeds tutorial notes on first launch
    static func seedOnboardingNotes(context: NSManagedObjectContext) {
        let hasSeededKey = "hasSeededOnboarding"
        if UserDefaults.standard.bool(forKey: hasSeededKey) {
            return
        }
        
        // Date: 8 days ago (Last Week) so they are ready for review immediately
        let pastDate = Calendar.current.date(byAdding: .day, value: -8, to: Date()) ?? Date()
        
        let notesData = [
            (
                "Welcome to Kuhrate! 👋",
                "This is your Inbox. Capture thoughts, quotes, and ideas here freely. Don't worry about organization yet."
            ),
            (
                "The Review System 🔄",
                "Every week, you'll review your notes. You decide: **Keep** what resonates, **Archive** the noise. This note is ready for review now!"
            ),
            (
                "Long Term Wisdom 🧠",
                "Notes you Keep move to Monthly, then Yearly cycles. Kuhrate helps you build a library of your best thinking."
            )
        ]
        
        // Iterate with offset to ensure correct sorting (Reverse order of creation = Display order)
        for (index, data) in notesData.enumerated() {
            let note = NoteEntity(context: context)
            note.id = UUID()
            note.content = "\(data.0)\n\n\(data.1)"
            
            // To make Welcome (#0) appear at the TOP (newest), it needs the LATEST date.
            // Wisdom (#2) needs the EARLIEST date.
            let minuteOffset = -(index * 5) // Welcome: 0, System: -5, Wisdom: -10
            note.createdDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: pastDate)
            
            note.reviewCycle = 0
            note.isArchived = false
        }
        
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: hasSeededKey)
            print("✅ Seeded onboarding notes with correct ordering")
        } catch {
            print("❌ Error seeding onboarding notes: \(error)")
        }
    }
}