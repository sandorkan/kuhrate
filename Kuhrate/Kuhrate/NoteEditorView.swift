//
//  NoteEditorView.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 21.12.2025.
//

import CoreData
import SwiftUI

struct NoteEditorView: View {
    // MARK: - Environment

    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - Input

    // The note being edited (nil = creating new note)
    let note: NoteEntity?

    // MARK: - State

    // Working copies (editable)
    @State private var editedContent: String
    @State private var editedCategory: CategoryEntity?
    @State private var editedTags: Set<TagEntity> = []
    @State private var editedSource: String = ""
    @State private var editedSourceType: SourceTypeEntity?

    // UI state
    @State private var showingDeleteConfirmation = false
    @State private var showingDiscardAlert = false

    // MARK: - Computed Properties

    // Is this creating a new note or editing existing?
    private var isCreating: Bool {
        note == nil
    }

    // Dynamic title for the navigation bar
    private var navigationTitle: String {
        if isCreating {
            return "New Note"
        } else {
            return timestampFormatter.string(from: note?.createdDate ?? Date())
        }
    }

    // Has user made any changes?
    private var hasChanges: Bool {
        if isCreating {
            // For new notes, check if user has typed anything
            return !editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            // For existing notes, compare with original
            let contentChanged = editedContent.trimmingCharacters(in: .whitespacesAndNewlines) != (note?.content ?? "")
            let categoryChanged = editedCategory?.id != note?.category?.id
            let tagsChanged = editedTags != (note?.tags as? Set<TagEntity> ?? [])
            let sourceChanged = editedSource.trimmingCharacters(in: .whitespacesAndNewlines) != (note?.source ?? "")
            let sourceTypeChanged = editedSourceType?.id != note?.sourceType?.id

            return contentChanged || categoryChanged || tagsChanged || sourceChanged || sourceTypeChanged
        }
    }

    // MARK: - Initializer

    init(note: NoteEntity? = nil) {
        self.note = note
        // Initialize @State with note's current values (or empty for new note)
        _editedContent = State(initialValue: note?.content ?? "")
        _editedCategory = State(initialValue: note?.category)
        _editedTags = State(initialValue: note?.tags as? Set<TagEntity> ?? [])
        _editedSource = State(initialValue: note?.source ?? "")
        _editedSourceType = State(initialValue: note?.sourceType)
    }

    // MARK: - Body

    var body: some View {
        NoteContentView(
            content: $editedContent,
            category: $editedCategory,
            tags: $editedTags,
            source: $editedSource,
            sourceType: $editedSourceType,
            isEditable: true,
            onTagAdd: { text in
                addTags(from: text)
            },
            onTagRemove: { tag in
                removeTag(tag)
            }
        )
        .onAppear {
            // Ensure state is synchronized with the note when the view appears
            if let note = note {
                editedContent = note.content ?? ""
                editedCategory = note.category
                editedTags = note.tags as? Set<TagEntity> ?? []
                editedSource = note.source ?? ""
                editedSourceType = note.sourceType
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!isCreating) // Hide back button only when editing
        .toolbar {
            if isCreating {
                // Creating mode: Back chevron and conditional Save checkmark
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.blue)
                    }
                }

                // Only show save checkmark if user has typed content
                if hasChanges {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            saveNote()
                        } label: {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            } else {
                // Editing mode: Custom back, delete, and conditional save
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if hasChanges {
                            showingDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.blue)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }

                if hasChanges {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            saveNote()
                        } label: {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .alert("Delete Note?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteNote()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Unsaved Changes", isPresented: $showingDiscardAlert) {
            Button("Save Changes", role: .none) {
                saveNote()
            }
            Button("Discard Changes", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You have unsaved changes. Do you want to discard them?")
        }
    }

    // MARK: - Functions

    private func saveNote() {
        let trimmedContent = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = editedSource.trimmingCharacters(in: .whitespacesAndNewlines)

        // Don't save if content is empty
        guard !trimmedContent.isEmpty else {
            return
        }

        if isCreating {
            // Create new note
            let newNote = NoteEntity(context: viewContext)
            newNote.id = UUID()
            newNote.content = trimmedContent
            newNote.createdDate = Date()
            newNote.category = editedCategory
            newNote.tags = editedTags as NSSet
            newNote.source = trimmedSource.isEmpty ? nil : trimmedSource
            newNote.sourceType = trimmedSource.isEmpty ? nil : editedSourceType
        } else {
            // Update existing note
            note?.content = trimmedContent
            note?.category = editedCategory
            note?.tags = editedTags as NSSet
            note?.source = trimmedSource.isEmpty ? nil : trimmedSource
            note?.sourceType = trimmedSource.isEmpty ? nil : editedSourceType
        }

        // Save to CoreData
        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            print("Error saving note: \(nsError), \(nsError.userInfo)")
        }
    }

    private func addTags(from text: String) {
        // Parse the input string into individual tag names
        let tagNames = parseTagInput(text)

        // Create or find each tag and add to editedTags
        for tagName in tagNames {
            let tag = findOrCreateTag(name: tagName, context: viewContext)
            editedTags.insert(tag)
        }
    }

    private func removeTag(_ tag: TagEntity) {
        editedTags.remove(tag)
    }

    private func deleteNote() {
        guard let note = note else { return }
        viewContext.delete(note)

        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            print("Error deleting note: \(nsError), \(nsError.userInfo)")
        }
    }
}

// MARK: - Date Formatter

private let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy"
    return formatter
}()

// MARK: - Preview

#Preview("Create New Note") {
    NavigationStack {
        NoteEditorView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

#Preview("Edit Existing Note") {
    let context = PersistenceController.preview.container.viewContext
    let sampleNote = {
        let note = NoteEntity(context: context)
        note.id = UUID()
        note.content = "Sample note for editing"
        note.createdDate = Date()
        return note
    }()

    return NavigationStack {
        NoteEditorView(note: sampleNote)
            .environment(\.managedObjectContext, context)
    }
}