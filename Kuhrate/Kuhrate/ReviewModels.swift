//
//  ReviewModels.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 22.12.2025.
//

import Foundation

// MARK: - Review Cycle
enum ReviewCycle: Int16, CaseIterable, Comparable {
    case daily = 0
    case weekly = 1
    case monthly = 2
    case yearly = 3

    static func < (lhs: ReviewCycle, rhs: ReviewCycle) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var title: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

// MARK: - Review Status
enum ReviewStatus: String, CaseIterable {
    case notStarted
    case inProgress
    case completed
}

// MARK: - Review Type
enum ReviewType: String, CaseIterable {
    case weekly
    case monthly
    case yearly
}

// MARK: - Action Type
enum ActionType: String, CaseIterable {
    case kept
    case archived
}
