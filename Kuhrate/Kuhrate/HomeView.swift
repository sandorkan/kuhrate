//
//  HomeView.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 22.12.2025.
//

import CoreData
import SwiftUI

struct HomeView: View {
    // MARK: - Environment

    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - Fetch Requests

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \NoteEntity.createdDate, ascending: false)],
        animation: .default
    )
    private var allNotes: FetchedResults<NoteEntity>

    // MARK: - State

    @State private var selectedTab: ReviewCycle = .daily
    @State private var showingAddNote = false
    @State private var searchText = ""

    // MARK: - Computed Properties

    /// Groups the notes based on the selected tab and time periods
    private var groupedTimeline: [(String, [NoteEntity])] {
        let filtered = allNotes.filter { note in
            // Visibility logic: show if note has reached this cycle level or higher
            note.reviewCycle >= selectedTab.rawValue
        }

        let calendar = Calendar.current
        let groups = Dictionary(grouping: filtered) { (note: NoteEntity) -> String in
            let date = note.createdDate ?? Date()

            switch selectedTab {
            case .daily:
                // Daily notes -> Group by Week
                if calendar.isDateInThisWeek(date) { return "This Week" }
                if calendar.isDateInLastWeek(date) { return "Last Week" }
                let formatter = DateFormatter()
                formatter.dateFormat = "'Week of' MMM d"
                let start = date.startOfWeek ?? date
                return formatter.string(from: start)

            case .weekly:
                // Weekly notes -> Group by Month
                if calendar.isDateInThisMonth(date) { return "This Month" }
                if calendar.isDateInLastMonth(date) { return "Last Month" }
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: date)

            case .monthly, .yearly:
                // Monthly/Yearly notes -> Group by Year
                if calendar.isDateInThisYear(date) { return "This Year" }
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy"
                return formatter.string(from: date)
            }
        }

        return groups.sorted { group1, group2 -> Bool in
            let date1 = group1.value.first?.createdDate ?? Date.distantPast
            let date2 = group2.value.first?.createdDate ?? Date.distantPast
            return date1 > date2
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        tabPicker

                        timelineContent

                        // Spacing for Bottom Bar
                        Spacer(minLength: 100)
                    }
                    .padding(.top)
                }

                // Floating Bottom Bar (Search + FAB)
                floatingBottomBar
            }
            .sheet(isPresented: $showingAddNote) {
                NavigationStack {
                    NoteEditorView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
        }
    }

    // MARK: - UI Components

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ReviewCycle.allCases, id: \.self) { cycle in
                    Button {
                        selectedTab = cycle
                    } label: {
                        Text(cycle.title)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedTab == cycle ? Color.blue : Color.gray.opacity(0.1))
                            .foregroundColor(selectedTab == cycle ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var timelineContent: some View {
        VStack(alignment: .leading, spacing: 32) {
            ForEach(groupedTimeline, id: \.0) { groupName, notes in
                timelineSection(title: groupName, notes: notes)
            }
        }
        .padding(.horizontal)
    }

    private func timelineSection(title: String, notes: [NoteEntity]) -> some View {
        let progress = calculateProgress(for: notes)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.bold())

                    HStack(spacing: 6) {
                        ProgressCircle(progress: progress)
                            .frame(width: 16, height: 16)

                        Text(progress == 1.0 ? "All Reviewed" : "\(Int(progress * 100))% Reviewed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if progress < 1.0 {
                    Button {
                        // Start/Continue review for this section
                    } label: {
                        Text(progress > 0 ? "Continue" : "Start Review")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(20)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }

            VStack(spacing: 16) {
                ForEach(notes) { note in
                    NavigationLink(destination: NoteEditorView(note: note)) {
                        HomeNoteRowView(note: note)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var floatingBottomBar: some View {
        HStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search notes", text: $searchText)

                Button {
                    // Voice search
                } label: {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.gray)
                }
            }
            .padding(12)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(30)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)

            // Add Note Button (FAB)
            Button {
                showingAddNote = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    // MARK: - Logic Helpers

        private func calculateProgress(for notes: [NoteEntity]) -> Double {
            guard !notes.isEmpty else { return 0 }
            
            // A note is considered reviewed for the current level if:
            // 1. It has been promoted to a higher cycle (e.g., from Daily to Weekly)
            // 2. OR it has been archived (meaning a decision was made to not promote it)
            let reviewedCount = notes.filter { note in
                note.reviewCycle > selectedTab.rawValue || note.isArchived
            }.count
            
            return Double(reviewedCount) / Double(notes.count)
        }}

// MARK: - Row View

struct HomeNoteRowView: View {
    @ObservedObject var note: NoteEntity

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: note.sourceType?.icon ?? "quote.bubble")
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                // First line as title
                Text(note.content?.components(separatedBy: .newlines).first ?? "Untitled")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // Rest as preview
                Text(note.content?.components(separatedBy: .newlines).dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundColor(.gray.opacity(0.4))
        }
    }
}

// MARK: - Progress View

struct ProgressCircle: View {
    var progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(progress == 1.0 ? Color.green : (progress > 0 ? Color.orange : Color.gray), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
