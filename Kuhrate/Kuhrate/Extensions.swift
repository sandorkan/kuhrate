//
//  Extensions.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 19.12.2025.
//

import SwiftUI

// MARK: - Color Extension
extension Color {
    /// Initialize a Color from a hex string (e.g., "#137fec" or "137fec")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (e.g., "137fec")
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

// MARK: - Calendar Helpers
extension Calendar {
    func isDateInThisWeek(_ date: Date) -> Bool {
        return isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    func isDateInLastWeek(_ date: Date) -> Bool {
        guard let lastWeek = self.date(byAdding: .weekOfYear, value: -1, to: Date()) else { return false }
        return isDate(date, equalTo: lastWeek, toGranularity: .weekOfYear)
    }
    
    func isDateInThisMonth(_ date: Date) -> Bool {
        return isDate(date, equalTo: Date(), toGranularity: .month)
    }
    
    func isDateInLastMonth(_ date: Date) -> Bool {
        guard let lastMonth = self.date(byAdding: .month, value: -1, to: Date()) else { return false }
        return isDate(date, equalTo: lastMonth, toGranularity: .month)
    }
    
    func isDateInThisYear(_ date: Date) -> Bool {
        return isDate(date, equalTo: Date(), toGranularity: .year)
    }
}

extension Date {
    var startOfWeek: Date? {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self))
    }
}