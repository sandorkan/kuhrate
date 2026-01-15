//
//  ReviewViewModel.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 26.12.2025.
//

import Combine
import CoreData
import Foundation
import SwiftUI

class ReviewViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var session: ReviewSessionEntity
    @Published var currentNote: NoteEntity?
    @Published var isFinished = false

    // MARK: - Private Properties

    private let context: NSManagedObjectContext
    private var allNotes: [NoteEntity] = []
    private var currentIndex: Int = 0
    private var pendingNavigation: DispatchWorkItem?
    private var hasInitializedPosition = false

    // MARK: - Computed Properties

    var progress: Double {
        guard session.totalNotes > 0 else { return 0.0 }
        return Double(session.notesReviewed) / Double(session.totalNotes)
    }

    var progressText: String {
        guard !allNotes.isEmpty else { return "0 of 0" }
        return "\(currentIndex + 1) of \(allNotes.count)"
    }

    var canGoBack: Bool {
        return currentIndex > 0
    }

    var canGoForward: Bool {
        return currentIndex < allNotes.count - 1
    }

    var currentActionType: ActionType? {
        guard let note = currentNote else { return nil }
        let action = (note.reviewActions?.allObjects as? [ReviewActionEntity])?.first(where: { $0.session?.id == session.id })
        guard let rawType = action?.action else { return nil }
        return ActionType(rawValue: rawType)
    }

    // MARK: - Initializer

    init(session: ReviewSessionEntity, context: NSManagedObjectContext) {
        self.session = session
        self.context = context
        loadNotes()
    }

    // MARK: - Loading

    func loadNotes() {
        allNotes = ReviewSessionManager.shared.fetchAllSessionNotes(for: session, context: context)

        if allNotes.isEmpty {
            isFinished = true
            return
        }

        // If position was already initialized and is still valid, preserve it
        if hasInitializedPosition && currentIndex >= 0 && currentIndex < allNotes.count {
            currentNote = allNotes[currentIndex]
            return
        }

        // First time loading - find the starting position
        hasInitializedPosition = true

        // Start at the first unreviewed note
        if let firstUnreviewedIndex = allNotes.firstIndex(where: { note in
            let actions = note.reviewActions?.allObjects as? [ReviewActionEntity] ?? []
            return !actions.contains(where: { $0.session?.id == session.id })
        }) {
            currentIndex = firstUnreviewedIndex
        } else {
            // All notes have been reviewed - stay at the last note
            currentIndex = allNotes.count - 1
        }
        currentNote = allNotes[currentIndex]
    }

    // MARK: - Actions

    func next() {
        pendingNavigation?.cancel()
        if canGoForward {
            withAnimation {
                currentIndex += 1
                currentNote = allNotes[currentIndex]
            }
        }
    }

    func previous() {
        pendingNavigation?.cancel()
        if canGoBack {
            withAnimation {
                currentIndex -= 1
                currentNote = allNotes[currentIndex]
            }
        }
    }

    func keep() {
        performAction(.kept)
    }

    func archive() {
        performAction(.archived)
    }

    private func performAction(_ action: ActionType) {
        guard let note = currentNote else { return }

        // Cancel any existing pending navigation to prevent double-skips if user taps fast
        pendingNavigation?.cancel()

        ReviewSessionManager.shared.submitAction(
            action: action,
            note: note,
            session: session,
            context: context
        )

        // Force UI update - CoreData changes don't automatically trigger SwiftUI re-renders
        // because @Published only fires when the reference changes, not when object properties change
        objectWillChange.send()

        // Auto-advance if this was a new decision on the current card
        if canGoForward {
            let workItem = DispatchWorkItem { [weak self] in
                self?.next()
            }
            pendingNavigation = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
        }
    }
}
