//
//  ContentView.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 14.12.2025.
//

import SwiftUI

struct ContentView: View {
    // MARK: - State
    // @State holds our notes array in memory
    // When notes changes, SwiftUI automatically updates the UI
    @State private var notes: [Note] = [
        // Sample notes so we have something to display
        Note(content: "Welcome to Kuhrate! This is your first note.", createdDate: Date()),
        Note(content: "Tap the + button to add a new note", createdDate: Date().addingTimeInterval(-3600)), // 1 hour ago
        Note(content: "Swipe left on a note to delete it", createdDate: Date().addingTimeInterval(-7200))  // 2 hours ago
    ]

    // Controls whether the Add Note sheet is visible
    @State private var showingAddNote = false

    // MARK: - Body
    var body: some View {
        NavigationStack {
            List {
                ForEach(notes) { note in
                    NavigationLink {
                        // Destination: Note detail view (simple for now)
                        VStack(alignment: .leading, spacing: 12) {
                            Text(note.content)
                                .font(.body)
                            Text(note.createdDate, formatter: dateFormatter)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .navigationTitle("Note Detail")
                    } label: {
                        // What shows in the list
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.content)
                                .font(.body)
                                .lineLimit(2) // Show max 2 lines
                            Text(note.createdDate, formatter: dateFormatter)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .onDelete(perform: deleteNotes)
            }
            .navigationTitle("My Notes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addNote) {
                        Label("Add Note", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddNote) {
            AddNoteView(notes: $notes)
        }
    }

    // MARK: - Functions

    // Shows the Add Note sheet
    private func addNote() {
        showingAddNote = true
    }

    // Delete notes at specific indices
    private func deleteNotes(offsets: IndexSet) {
        withAnimation {
            notes.remove(atOffsets: offsets)
        }
    }
}

// MARK: - Date Formatter
// Formats dates like "12/15/25, 10:30 AM"
private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

// MARK: - Preview
#Preview {
    ContentView()
}
