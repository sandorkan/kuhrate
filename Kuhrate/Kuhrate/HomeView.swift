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

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ReviewSessionEntity.startedDate, ascending: false)],
        animation: .default
    )
    private var reviewSessions: FetchedResults<ReviewSessionEntity>

    // MARK: - State

    @State private var selectedTab: ReviewCycle = .daily
    @State private var showingAddNote = false
    @State private var showingSettings = false
    @State private var showingSearch = false
    @State private var searchText = ""

    // Review State
    @State private var activeReviewSession: ReviewSessionEntity?

    // MARK: - Computed Properties

    /// Groups the notes based on the selected tab and time periods
    /// Returns: (Title, Notes, PeriodIdentifier)
    private var groupedTimeline: [(title: String, notes: [NoteEntity], id: String)] {
        let filtered = allNotes.filter { note in
            // Visibility logic: show if note has reached this cycle level or higher
            note.reviewCycle >= selectedTab.rawValue
        }

        let calendar = Calendar.current

        // Grouping key is the Period Identifier (e.g. "2025-W01")
        let groups = Dictionary(grouping: filtered) { (note: NoteEntity) -> String in
            let date = note.createdDate ?? Date()
            switch selectedTab {
            case .daily: return date.weekIdentifier
            case .weekly: return date.monthIdentifier
            case .monthly: return date.yearIdentifier
            case .yearly: return "Evergreen"
            }
        }

        // Map to display models
        let result = groups.map { (key: String, notes: [NoteEntity]) -> (title: String, notes: [NoteEntity], id: String) in
            // Determine display title based on the date of the first note (representative)
            let date = notes.first?.createdDate ?? Date()
            let title: String

            switch selectedTab {
            case .daily:
                if calendar.isDateInThisWeek(date) { title = "This Week" }
                else if calendar.isDateInLastWeek(date) { title = "Last Week" }
                else {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "'Week of' MMM d"
                    let start = date.startOfWeek ?? date
                    title = formatter.string(from: start)
                }
            case .weekly:
                if calendar.isDateInThisMonth(date) { title = "This Month" }
                else if calendar.isDateInLastMonth(date) { title = "Last Month" }
                else {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMMM yyyy"
                    title = formatter.string(from: date)
                }
            case .monthly, .yearly:
                if calendar.isDateInThisYear(date) { title = "This Year" }
                else {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy"
                    title = formatter.string(from: date)
                }
            }

            return (title: title, notes: notes, id: key)
        }

        return result.sorted { group1, group2 -> Bool in
            let date1 = group1.notes.first?.createdDate ?? Date.distantPast
            let date2 = group2.notes.first?.createdDate ?? Date.distantPast
            return date1 > date2
        }
    }

    // Finds the oldest period that is actionable (in the past and incomplete)
    private var heroTarget: (title: String, id: String, progress: Double, noteCount: Int)? {
        // Iterate oldest to newest (reversed)
        for group in groupedTimeline.reversed() {
            if canStartReview(for: group.id) {
                let progress = calculateProgress(for: group.id, notes: group.notes)
                if progress < 1.0 {
                    return (group.title, group.id, progress, group.notes.count)
                }
            }
        }
        return nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection

                        heroCard

                        tabPicker

                        timelineContent

                        // Spacing for Bottom Bar
                        Spacer(minLength: 100)
                    }
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure ScrollView fills screen

                // Floating Bottom Bar (Search + FAB)
                floatingBottomBar
            }
            .sheet(isPresented: $showingAddNote) {
                NavigationStack {
                    NoteEditorView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .sheet(isPresented: $showingSettings) {
                DevelopmentSettingsView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .fullScreenCover(item: $activeReviewSession) { session in
                ReviewViewContainer(session: session, context: viewContext)
            }
            .fullScreenCover(isPresented: $showingSearch) {
                GlobalSearchView(context: viewContext)
            }
        }
    }

    // MARK: - UI Components

    private var headerSection: some View {
        HStack {
            Text("Home")
                .font(.system(size: 34, weight: .bold))

            Spacer()

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }

    @ViewBuilder
    private var heroCard: some View {
        if let target = heroTarget {
            Button {
                startReview(for: target.id)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(target.progress == 0 ? "Ready for Review" : "Continue Review")
                            .font(.subheadline.weight(.bold))
                            .textCase(.uppercase)
                            .opacity(0.8)

                        Text(target.title)
                            .font(.title2.bold())

                        HStack(spacing: 4) {
                            Image(systemName: "note.text")
                            Text("\(target.noteCount) Notes")
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.85)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(24)
                .shadow(color: Color.blue.opacity(0.25), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal)
            .buttonStyle(.plain)
        }
    }

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ReviewCycle.allCases, id: \.self) { cycle in
                    let count = pendingReviewCount(for: cycle)

                    Button {
                        selectedTab = cycle
                    } label: {
                        HStack(spacing: 6) {
                            Text(cycle.title)

                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
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
            if groupedTimeline.isEmpty {
                emptyStateView
            } else {
                ForEach(groupedTimeline, id: \.id) { group in
                    timelineSection(title: group.title, notes: group.notes, periodIdentifier: group.id)
                }
            }
        }
        .padding(.horizontal)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image("kuhrate-waiting-sm")
                .resizable()
                .scaledToFit()
                .frame(width: 180)

            Text(emptyStateTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            Text(emptyStateSubtitle)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyStateTitle: String {
        switch selectedTab {
        case .daily: return "Start Capturing Ideas"
        case .weekly: return "No Monthly Notes Yet"
        case .monthly: return "No Yearly Notes Yet"
        case .yearly: return "No Evergreen Notes Yet"
        }
    }

    private var emptyStateSubtitle: String {
        switch selectedTab {
        case .daily: return "Tap the + button to create your first note"
        case .weekly: return "Keep notes during your weekly reviews to see them here"
        case .monthly: return "Keep notes during your monthly reviews to see them here"
        case .yearly: return "Your most valuable insights will appear here after yearly reviews"
        }
    }

    private func timelineSection(title: String, notes: [NoteEntity], periodIdentifier: String) -> some View {
        let progress = calculateProgress(for: periodIdentifier, notes: notes)
        let isReviewable = canStartReview(for: periodIdentifier)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.bold())

                    if isReviewable {
                        HStack(spacing: 6) {
                            ProgressCircle(progress: progress)
                                .frame(width: 16, height: 16)

                            Text(progress == 1.0 ? "All Reviewed" : "\(Int(progress * 100))% Reviewed")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Collecting...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isReviewable {
                    if progress < 1.0 {
                        Button {
                            startReview(for: periodIdentifier)
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
                        Button {
                            startReview(for: periodIdentifier)
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                    }
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

                Text("Search notes")
                    .foregroundColor(.gray)

                Spacer()
            }
            .padding(12)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(30)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            .onTapGesture {
                showingSearch = true
            }

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

    private func pendingReviewCount(for cycle: ReviewCycle) -> Int {
        let relevantNotes = allNotes.filter { $0.reviewCycle >= cycle.rawValue }

        let groups = Dictionary(grouping: relevantNotes) { (note: NoteEntity) -> String in
            let date = note.createdDate ?? Date()
            switch cycle {
            case .daily: return date.weekIdentifier
            case .weekly: return date.monthIdentifier
            case .monthly: return date.yearIdentifier
            case .yearly: return "Evergreen"
            }
        }

        var pendingCount = 0
        let now = Date()
        let currentIdentifier: String

        switch cycle {
        case .daily: currentIdentifier = now.weekIdentifier
        case .weekly: currentIdentifier = now.monthIdentifier
        case .monthly: currentIdentifier = now.yearIdentifier
        case .yearly: return 0
        }

        for (periodIdentifier, notes) in groups {
            if periodIdentifier < currentIdentifier {
                let progress = calculateProgress(for: periodIdentifier, notes: notes, cycle: cycle)
                if progress < 1.0 {
                    pendingCount += 1
                }
            }
        }

        return pendingCount
    }

    private func canStartReview(for periodIdentifier: String) -> Bool {
        let now = Date()
        let currentIdentifier: String

        switch selectedTab {
        case .daily:
            currentIdentifier = now.weekIdentifier
        case .weekly:
            currentIdentifier = now.monthIdentifier
        case .monthly:
            currentIdentifier = now.yearIdentifier
        case .yearly:
            return false // Evergreen notes don't have a "past" cycle in the same way
        }

        return periodIdentifier < currentIdentifier
    }

    // Overloaded helper for internal calculations (uses current selectedTab)
    private func calculateProgress(for periodIdentifier: String, notes: [NoteEntity]) -> Double {
        return calculateProgress(for: periodIdentifier, notes: notes, cycle: selectedTab)
    }

    // Core calculation
    private func calculateProgress(for periodIdentifier: String, notes _: [NoteEntity], cycle: ReviewCycle) -> Double {
        let targetType: ReviewType
        switch cycle {
        case .daily: targetType = .weekly
        case .weekly: targetType = .monthly
        case .monthly: targetType = .yearly
        case .yearly: return 0
        }

        if let session = reviewSessions.first(where: { $0.periodIdentifier == periodIdentifier && $0.type == targetType.rawValue }) {
            guard session.totalNotes > 0 else { return 1.0 }
            return Double(session.notesReviewed) / Double(session.totalNotes)
        }

        // 2. Fallback: No session started yet, so progress is 0
        return 0.0
    }

    private func startReview(for periodIdentifier: String) {
        let reviewType: ReviewType
        switch selectedTab {
        case .daily: reviewType = .weekly
        case .weekly: reviewType = .monthly
        case .monthly: reviewType = .yearly
        case .yearly: return
        }

        do {
            let session = try ReviewSessionManager.shared.startOrResumeSession(
                for: periodIdentifier,
                type: reviewType,
                context: viewContext
            )
            activeReviewSession = session
        } catch {
            print("❌ Failed to start review session: \(error)")
        }
    }
}

// MARK: - Row View

struct HomeNoteRowView: View {
    @ObservedObject var note: NoteEntity
    var showChevron: Bool = false

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
                // Header with Title and Date
                HStack(alignment: .firstTextBaseline) {
                    Text(note.content?.components(separatedBy: .newlines).first ?? "Untitled")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    if let date = note.createdDate {
                        Text(date, formatter: itemDateFormatter)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                // Rest as preview
                Text(note.content?.components(separatedBy: .newlines).dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.gray.opacity(0.4))
            }
        }
    }
}

private let itemDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy"
    return formatter
}()

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
