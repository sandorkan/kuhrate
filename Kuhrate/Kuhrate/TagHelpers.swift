//
//  TagHelpers.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 21.12.2025.
//

import CoreData

// MARK: - Tag Helper Functions

/// Finds an existing tag by name (case-insensitive) or creates a new one
/// - Parameters:
///   - name: The tag name to find or create
///   - context: The managed object context to use
/// - Returns: Existing or newly created TagEntity (not yet saved to disk)
func findOrCreateTag(name: String, context: NSManagedObjectContext) -> TagEntity {
    // Normalize the tag name (lowercase, trimmed)
    let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

    // Search for existing tag with this name
    let fetchRequest: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "name ==[c] %@", normalizedName)
    fetchRequest.fetchLimit = 1

    do {
        let results = try context.fetch(fetchRequest)
        if let existingTag = results.first {
            // Tag already exists, return it
            return existingTag
        }
    } catch {
        print("Error fetching tag: \(error)")
    }

    // Tag doesn't exist, create new one
    let newTag = TagEntity(context: context)
    newTag.id = UUID()
    newTag.name = normalizedName
    return newTag
}

/// Parses a string into individual tag names (splits by comma or space)
/// - Parameter input: Raw string from user (e.g., "work, ideas health")
/// - Returns: Array of trimmed, non-empty tag names
func parseTagInput(_ input: String) -> [String] {
    // Split by comma or space, filter out empty strings
    let separators = CharacterSet(charactersIn: ", ")
    return input.components(separatedBy: separators)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

/// Converts a Note's tags (NSSet) to a sorted array of tag names
/// - Parameter note: The note entity
/// - Returns: Alphabetically sorted array of tag names
func getTagNames(from note: NoteEntity) -> [String] {
    guard let tagsSet = note.tags as? Set<TagEntity> else {
        return []
    }

    return tagsSet
        .compactMap { $0.name }
        .sorted()
}
