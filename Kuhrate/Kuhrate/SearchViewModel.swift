//
//  SearchViewModel.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 26.12.2025.
//

import Combine
import CoreData
import SwiftUI

enum DateFilterOption: String, CaseIterable, Identifiable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case last3Months = "Last 3 Months"
    case last6Months = "Last 6 Months"
    case lastYear = "Last Year"
    case thisYear = "This Year"
    
    var id: String { rawValue }
    
    func dateRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        // End is technically now (or end of today), but for <= query, let's use now
        // Actually, future notes shouldn't exist, so up to now is fine.
        let end = now
        
        let start: Date
        switch self {
        case .today:
            start = calendar.startOfDay(for: now)
        case .thisWeek:
            // Assuming start of week
            start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        case .thisMonth:
            start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        case .last3Months:
            start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .last6Months:
            start = calendar.date(byAdding: .month, value: -6, to: now) ?? now
        case .lastYear:
            start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .thisYear:
            start = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        }
        return (start, end)
    }
}

class SearchViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var searchText: String = "" {
        didSet { performSearch() }
    }
    
    @Published var selectedSourceTypes: Set<SourceTypeEntity> = [] {
        didSet { performSearch() }
    }
    
    @Published var selectedCategories: Set<CategoryEntity> = [] {
        didSet { performSearch() }
    }
    
    @Published var selectedTags: Set<TagEntity> = [] {
        didSet { performSearch() }
    }
    
    @Published var dateFilter: DateFilterOption? {
        didSet {
            if dateFilter != nil { isCustomDateFilterActive = false }
            performSearch()
        }
    }
    
    @Published var customStartDate: Date = Date() {
        didSet {
            isCustomDateFilterActive = true
            dateFilter = nil
            performSearch()
        }
    }
    
    @Published var customEndDate: Date = Date() {
        didSet {
            isCustomDateFilterActive = true
            dateFilter = nil
            performSearch()
        }
    }
    
    @Published var isCustomDateFilterActive: Bool = false
    
    @Published var results: [NoteEntity] = []
    
    // MARK: - Private Properties
    private let context: NSManagedObjectContext
    
    // MARK: - Initializer
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Search Logic
    
    func performSearch() {
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        // Text Search
        if !searchText.isEmpty {
            let textPredicate = NSPredicate(format: "content CONTAINS[cd] %@ OR source CONTAINS[cd] %@", searchText, searchText)
            predicates.append(textPredicate)
        }
        
        // Source Type Filter
        if !selectedSourceTypes.isEmpty {
            let sourcePredicates = selectedSourceTypes.map { NSPredicate(format: "sourceType == %@", $0) }
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: sourcePredicates))
        }
        
        // Category Filter
        if !selectedCategories.isEmpty {
            let categoryPredicates = selectedCategories.map { NSPredicate(format: "category == %@", $0) }
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: categoryPredicates))
        }
        
        // Tag Filter
        if !selectedTags.isEmpty {
            // Check if note has ANY of the selected tags
            // "tags" is a relationship. "ANY tags == tagObject" works.
            let tagPredicates = selectedTags.map { NSPredicate(format: "ANY tags == %@", $0) }
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: tagPredicates))
        }
        
        // Date Filter
        if let option = dateFilter {
            let range = option.dateRange()
            let datePredicate = NSPredicate(format: "createdDate >= %@", range.start as NSDate)
            predicates.append(datePredicate)
        } else if isCustomDateFilterActive {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: customStartDate)
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEndDate))!
            let datePredicate = NSPredicate(format: "createdDate >= %@ AND createdDate < %@", start as NSDate, end as NSDate)
            predicates.append(datePredicate)
        }
        
        // Only run query if we have criteria
        if predicates.isEmpty {
            results = []
            return
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NoteEntity.createdDate, ascending: false)]
        
        do {
            results = try context.fetch(request)
        } catch {
            print("Search fetch error: \(error)")
            results = []
        }
    }
    
    // MARK: - Filter Management
    
    func clearAllFilters() {
        selectedSourceTypes.removeAll()
        selectedCategories.removeAll()
        selectedTags.removeAll()
        dateFilter = nil
        isCustomDateFilterActive = false
        searchText = ""
    }
}