//
//  AddNoteView.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 15.12.2025.
//

import SwiftUI
import CoreData

struct AddNoteView: View {
    // MARK: - Environment
    // dismiss is provided by SwiftUI to close the sheet
    @Environment(\.dismiss) var dismiss
    // CoreData managed object context for saving
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - State
    // Local state for the text being typed
    @State private var noteText: String = ""
    // Selected category (optional)
    @State private var selectedCategory: CategoryEntity?
    // Controls whether the category picker sheet is visible
    @State private var showingCategoryPicker = false

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Timestamp display
                Text(Date(), formatter: timestampFormatter)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 8)

                // Text editor for note content with placeholder
                ZStack(alignment: .topLeading) {
                    // TextEditor
                    TextEditor(text: $noteText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .font(.body)

                    // Placeholder text (only shows when noteText is empty)
                    if noteText.isEmpty {
                        Text("Start writing your note...")
                            .foregroundColor(Color(uiColor: .placeholderText))
                            .font(.body)
                            .padding(.horizontal, 20)  // Matches TextEditor's text position
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)  // Let taps pass through to TextEditor
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
                                .foregroundColor(.gray)
                            Text("Category")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(selectedCategory?.name ?? "")
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
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel button (left side)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()  // Close the sheet without saving
                    }
                }

                // Save button (right side)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNote()
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    // ^ Disable if note is empty or just whitespace
                }
            }
        }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerView(selectedCategory: $selectedCategory)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Functions

    private func saveNote() {
        // Trim whitespace from note text
        let trimmedContent = noteText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Don't save if content is empty
        guard !trimmedContent.isEmpty else {
            return
        }

        // Create new NoteEntity in CoreData
        let newNote = NoteEntity(context: viewContext)
        newNote.id = UUID()
        newNote.content = trimmedContent
        newNote.createdDate = Date()
        newNote.category = selectedCategory  // Save the selected category

        // Save to CoreData
        do {
            try viewContext.save()
            // Close the sheet
            dismiss()
        } catch {
            let nsError = error as NSError
            print("Error saving note: \(nsError), \(nsError.userInfo)")
        }
    }
}

// MARK: - Date Formatter
// Shows full timestamp like "Sunday, Dec 15, 2025 at 10:30 AM"
private let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    formatter.timeStyle = .short
    return formatter
}()

// MARK: - Preview
#Preview {
    AddNoteView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
