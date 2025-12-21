//
//  Persistence.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 14.12.2025.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Seed predefined categories
        seedCategoriesIfNeeded(context: viewContext)

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

        // Seed predefined categories on first launch
        PersistenceController.seedCategoriesIfNeeded(context: container.viewContext)
    }

    // MARK: - Category Seeding

    /// Seeds the predefined categories if they don't exist yet
    static func seedCategoriesIfNeeded(context: NSManagedObjectContext) {
        // Check if categories already exist
        let fetchRequest: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()

        do {
            let count = try context.count(for: fetchRequest)
            if count > 0 {
                // Categories already exist, skip seeding
                print("Categories already exist, skip seeding")
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
}
