//
//  ContentView.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 14.12.2025.
//

import SwiftUI
import CoreData

struct ContentView: View {
    // MARK: - Environment
    // CoreData managed object context for saving/deleting
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - Fetch Request
    // @FetchRequest automatically fetches NoteEntity objects from CoreData
    // Sorted by createdDate (newest first)
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \NoteEntity.createdDate, ascending: false)],
        animation: .default)
    private var notes: FetchedResults<NoteEntity>

    // MARK: - State
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
                            Text(note.contentText)
                                .font(.body)
                            Text(note.createdDateSafe, formatter: dateFormatter)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .navigationTitle("Note Detail")
                    } label: {
                        // What shows in the list
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.contentText)
                                .font(.body)
                                .lineLimit(2) // Show max 2 lines
                            Text(note.createdDateSafe, formatter: dateFormatter)
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
            AddNoteView()
                .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Functions

    // Shows the Add Note sheet
    private func addNote() {
        showingAddNote = true
    }

    // Delete notes from CoreData
    private func deleteNotes(offsets: IndexSet) {
        withAnimation {
            // Marks the notes in the offsets for deletion
            // short-version of code: offsets.map { notes[$0] }.forEach(viewContext.delete)
            for index in offsets {
                 let note = notes[index]
                 viewContext.delete(note)
             }

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting note: \(nsError), \(nsError.userInfo)")
            }
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
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
