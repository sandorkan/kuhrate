//
//  ReviewSessionManager.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 26.12.2025.
//

import CoreData
import Foundation

class ReviewSessionManager {
    static let shared = ReviewSessionManager()
    
    private init() {}
    
    // MARK: - Session Management
    
    /// Fetches or creates a review session for a specific period and type
    func startOrResumeSession(for periodIdentifier: String, type: ReviewType, context: NSManagedObjectContext) -> ReviewSessionEntity {
        let request: NSFetchRequest<ReviewSessionEntity> = ReviewSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "periodIdentifier == %@ AND type == %@", periodIdentifier, type.rawValue)
        
        do {
            let results = try context.fetch(request)
            if let existingSession = results.first {
                return existingSession
            }
        } catch {
            print("Error fetching existing session: \(error)")
        }
        
        // Create new session
        let newSession = ReviewSessionEntity(context: context)
        newSession.id = UUID()
        newSession.periodIdentifier = periodIdentifier
        newSession.type = type.rawValue
        newSession.status = ReviewStatus.inProgress.rawValue
        newSession.startedDate = Date()
        
        // Calculate initial total notes
        let eligibleNotes = fetchEligibleNotes(for: periodIdentifier, type: type, context: context)
        newSession.totalNotes = Int32(eligibleNotes.count)
        
        save(context: context)
        return newSession
    }
    
    /// Submits or updates a review decision for a note
    func submitAction(action: ActionType, note: NoteEntity, session: ReviewSessionEntity, context: NSManagedObjectContext) {
        // Check for existing action
        let existingAction = (note.reviewActions?.allObjects as? [ReviewActionEntity])?.first(where: { $0.session?.id == session.id })
        
        if let existingAction = existingAction {
            // Revert previous decision stats
            if let oldActionType = ActionType(rawValue: existingAction.action ?? "") {
                if oldActionType == .kept {
                    session.notesKept -= 1
                    // Revert promotion
                    let prevCycle = max(0, note.reviewCycle - 1)
                    note.reviewCycle = prevCycle
                } else if oldActionType == .archived {
                    session.notesArchived -= 1
                    // Revert archive
                    note.isArchived = false
                }
            }
            
            // Update existing action
            existingAction.action = action.rawValue
            existingAction.actionDate = Date()
            
        } else {
            // Create new action
            let reviewAction = ReviewActionEntity(context: context)
            reviewAction.id = UUID()
            reviewAction.action = action.rawValue
            reviewAction.actionDate = Date()
            reviewAction.note = note
            reviewAction.session = session
            
            // Increment total progress only for new actions
            session.notesReviewed += 1
        }
        
        // Apply new decision effects
        if action == .kept {
            // Promote
            let nextCycle = (ReviewCycle(rawValue: note.reviewCycle) ?? .daily).rawValue + 1
            note.reviewCycle = min(nextCycle, ReviewCycle.yearly.rawValue)
            session.notesKept += 1
            // Ensure not archived
            note.isArchived = false 
        } else {
            // Archive
            note.isArchived = true
            session.notesArchived += 1
        }
        note.lastReviewedDate = Date()
        
        // Check completion
        if session.notesReviewed >= session.totalNotes {
            session.status = ReviewStatus.completed.rawValue
            session.completedDate = Date()
        } else {
            // If we revert decisions, we might go back to inProgress? 
            // For now, let's keep it simple. If we touch 10/10, it's done.
        }
        
        save(context: context)
    }
    
    // MARK: - Note Fetching
    
    /// Fetches ALL eligible notes for this session (both pending and reviewed)
    func fetchAllSessionNotes(for session: ReviewSessionEntity, context: NSManagedObjectContext) -> [NoteEntity] {
        return fetchEligibleNotes(for: session.periodIdentifier ?? "", 
                                type: ReviewType(rawValue: session.type ?? "") ?? .weekly, 
                                context: context)
    }
    
    /// Fetches notes that belong to a period and match the expected review level
    private func fetchEligibleNotes(for periodIdentifier: String, type: ReviewType, context: NSManagedObjectContext) -> [NoteEntity] {
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        
        // Target level logic
        let targetLevel: Int16
        switch type {
        case .weekly: targetLevel = ReviewCycle.daily.rawValue
        case .monthly: targetLevel = ReviewCycle.weekly.rawValue
        case .yearly: targetLevel = ReviewCycle.monthly.rawValue
        }
        
        // We want notes that ARE at this level, OR were promoted from this level during THIS session.
        // But querying "history" in fetch request is hard.
        // Simplified approach: Fetch based on Date Range only, then filter in memory if necessary?
        // No, fetch based on Date Range + (Cycle == Target OR (Cycle > Target AND ReviewedInSession) OR (Archived AND ReviewedInSession))
        // Actually, for simplicity: Fetch by Date Range. Then filter.
        
        if let range = dateRange(for: periodIdentifier, type: type) {
            request.predicate = NSPredicate(format: "createdDate >= %@ AND createdDate <= %@", range.start as NSDate, range.end as NSDate)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NoteEntity.createdDate, ascending: true)]
        
        do {
            let allNotesInRange = try context.fetch(request)
            
            // Post-fetch filter to ensure we only get valid candidates
            // A note is valid if:
            // 1. It is currently at the target level and not archived (Pending)
            // 2. OR it was reviewed in THIS session (Completed)
            
            return allNotesInRange.filter { note in
                let actions = note.reviewActions?.allObjects as? [ReviewActionEntity] ?? []
                let reviewedInThisSession = actions.contains(where: { 
                    $0.session?.periodIdentifier == periodIdentifier && $0.session?.type == type.rawValue 
                })
                
                if reviewedInThisSession {
                    return true
                }
                
                // If not reviewed yet, it must be at the correct level and not archived
                return note.reviewCycle == targetLevel && !note.isArchived
            }
            
        } catch {
            print("Error fetching eligible notes: \(error)")
            return []
        }
    }
    
    // MARK: - Private Helpers
    
    private func dateRange(for identifier: String, type: ReviewType) -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        switch type {
        case .weekly:
            let components = identifier.components(separatedBy: "-W")
            guard components.count == 2, 
                  let year = Int(components[0]), 
                  let week = Int(components[1]) else { return nil }
            
            var searchComponents = DateComponents()
            searchComponents.yearForWeekOfYear = year
            searchComponents.weekOfYear = week
            searchComponents.weekday = calendar.firstWeekday // Start of week (Sunday or Monday)
            
            guard let start = calendar.date(from: searchComponents),
                  let end = calendar.date(byAdding: .day, value: 7, to: start) else { return nil }
            return (start, end)
            
        case .monthly:
            formatter.dateFormat = "yyyy-MM"
            guard let start = formatter.date(from: identifier),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
            return (start, end)
            
        case .yearly:
            formatter.dateFormat = "yyyy"
            guard let start = formatter.date(from: identifier),
                  let end = calendar.date(byAdding: .year, value: 1, to: start) else { return nil }
            return (start, end)
        }
    }
    
    private func save(context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context in ReviewSessionManager: \(error)")
            }
        }
    }
}