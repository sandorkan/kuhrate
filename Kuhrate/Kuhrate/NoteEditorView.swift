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

    // MARK: - Fetch Requests

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.sortOrder, order: .forward)]
    ) private var sourceTypes: FetchedResults<SourceTypeEntity>

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
    @State private var showingCategoryPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDiscardAlert = false
    @State private var tagInput: String = ""

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

            // Input Fields
            VStack(spacing: 12) {
                // Source Input
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: editedSourceType?.icon ?? "quote.bubble")
                            .foregroundColor(.gray)

                        TextField("Source (URL, book, podcast...)", text: $editedSource)
                            .font(.body)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.default)
                            .onChange(of: editedSource) { newValue in
                                detectSourceType(for: newValue)
                            }

                        if !editedSource.isEmpty {
                            Button {
                                editedSource = ""
                                editedSourceType = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(10)

                    // Source Type Picker (Pills)
                    if !editedSource.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(sourceTypes) { type in
                                    Button {
                                        if editedSourceType?.id == type.id {
                                            editedSourceType = nil
                                        } else {
                                            editedSourceType = type
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: type.icon ?? "circle")
                                            Text(type.name ?? "")
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            editedSourceType?.id == type.id
                                                ? Color.blue
                                                : Color(uiColor: .tertiarySystemBackground)
                                        )
                                        .foregroundColor(
                                            editedSourceType?.id == type.id
                                                ? .white
                                                : .primary
                                        )
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color(uiColor: .separator), lineWidth: editedSourceType?.id == type.id ? 0 : 0.5)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }

                // Category selector button
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

                // Tag input field
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.gray)
                    TextField("Add tags (space or comma separated)", text: $tagInput)
                        .font(.body)
                        .onSubmit {
                            addTagsFromInput()
                        }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)

                // Tag pills (horizontal scrolling)
                if !editedTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(editedTags).sorted(by: { ($0.name ?? "") < ($1.name ?? "") }), id: \.id) { tag in
                                TagPillView(
                                    tagName: tag.name ?? "",
                                    onRemove: {
                                        removeTag(tag)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
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
        .navigationTitle(isCreating ? "New Note" : "Note Detail")
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
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerView(selectedCategory: $editedCategory)
                .environment(\.managedObjectContext, viewContext)
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

    private func detectSourceType(for text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Auto-detect link
        if trimmed.lowercased().hasPrefix("http") {
            if let linkType = sourceTypes.first(where: { $0.name == "Link" }) {
                // Only set if not already set or if it's "Other"
                if editedSourceType == nil || editedSourceType?.name == "Other" {
                    editedSourceType = linkType
                }
            }
        }

        // If text becomes empty, clear type (already handled by clear button, but good for backspace)
        if trimmed.isEmpty {
            editedSourceType = nil
        } else if editedSourceType == nil {
            // Default to "Other" or "Book" if nothing selected?
            // Maybe better to leave it empty and let user pick, or default to "Other"
            // For now, let's leave nil so user is prompted to pick (since pills appear)
        }
    }

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

    private func addTagsFromInput() {
        // Parse the input string into individual tag names
        let tagNames = parseTagInput(tagInput)

        // Create or find each tag and add to editedTags
        for tagName in tagNames {
            let tag = findOrCreateTag(name: tagName, context: viewContext)
            editedTags.insert(tag)
        }

        // Clear the input field
        tagInput = ""
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
