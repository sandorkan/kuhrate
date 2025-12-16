//
//  Note.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 15.12.2025.
//

import Foundation

struct Note: Identifiable {
    let id = UUID()          // Unique identifier for each note
    var content: String      // The note's text content
    var createdDate: Date    // When the note was created (date + time)
}
