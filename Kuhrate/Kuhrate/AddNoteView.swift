//
//  AddNoteView.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 15.12.2025.
//

import SwiftUI

struct AddNoteView: View {
    // MARK: - Environment
    // dismiss is provided by SwiftUI to close the sheet
    @Environment(\.dismiss) var dismiss

    // MARK: - Bindings
    // This is a binding to the notes array in ContentView
    // When we add a note here, ContentView's array updates automatically
    @Binding var notes: [Note]

    // MARK: - State
    // Local state for the text being typed
    @State private var noteText: String = ""

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
    }

    // MARK: - Functions

    private func saveNote() {
        // Create new note with the text
        let newNote = Note(
            content: noteText.trimmingCharacters(in: .whitespacesAndNewlines),
            createdDate: Date()
        )

        // Add to the beginning of the array (newest first)
        withAnimation {
            notes.insert(newNote, at: 0)
        }

        // Close the sheet
        dismiss()
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
    // For preview, we need to provide a binding
    // @State creates a temporary notes array for preview
    struct PreviewWrapper: View {
        @State private var notes: [Note] = []

        var body: some View {
            AddNoteView(notes: $notes)
        }
    }

    return PreviewWrapper()
}
