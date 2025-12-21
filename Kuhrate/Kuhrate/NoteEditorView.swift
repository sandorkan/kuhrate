//
//  NoteEditorView.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 21.12.2025.
//

import SwiftUI
import CoreData

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

    // UI state
    @State private var showingCategoryPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDiscardAlert = false

    // MARK: - Computed Properties

    // Is this creating a new note or editing existing?
    private var isCreating: Bool {
        note == nil
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
            return contentChanged || categoryChanged
        }
    }

    // MARK: - Initializer

    init(note: NoteEntity? = nil) {
        self.note = note
        // Initialize @State with note's current values (or empty for new note)
        _editedContent = State(initialValue: note?.content ?? "")
        _editedCategory = State(initialValue: note?.category)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Timestamp display
            Text(note?.createdDate ?? Date(), formatter: timestampFormatter)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 8)

            // Text editor for note content with placeholder
            ZStack(alignment: .topLeading) {
                TextEditor(text: $editedContent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .font(.body)

                // Placeholder text (only shows when content is empty)
                if editedContent.isEmpty {
                    Text("Start writing your note...")
                        .foregroundColor(Color(uiColor: .placeholderText))
                        .font(.body)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }

            Spacer()

            // Category selector button (at bottom)
            VStack(spacing: 12) {
                Button {
                    showingCategoryPicker = true
                } label: {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(editedCategory?.color != nil ? Color(hex: editedCategory!.color!) : .gray)
                        Text("Category")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(editedCategory?.name ?? "")
                            .foregroundColor(.gray)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle(isCreating ? "New Note" : "Note Detail")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!isCreating)  // Hide back button only when editing
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
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerView(selectedCategory: $editedCategory)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Note?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteNote()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Unsaved Changes", isPresented: $showingDiscardAlert) {
            Button("Discard Changes", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Do you want to discard them?")
        }
    }

    // MARK: - Functions

    private func saveNote() {
        let trimmedContent = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)

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
        } else {
            // Update existing note
            note?.content = trimmedContent
            note?.category = editedCategory
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
    formatter.dateStyle = .full
    formatter.timeStyle = .short
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
    let note = NoteEntity(context: context)
    note.id = UUID()
    note.content = "Sample note for editing"
    note.createdDate = Date()

    return NavigationStack {
        NoteEditorView(note: note)
            .environment(\.managedObjectContext, context)
    }
}

