//
//  TagPillView.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 21.12.2025.
//

import SwiftUI

struct TagPillView: View {
    // MARK: - Input
    let tagName: String
    let onRemove: () -> Void

    // MARK: - Body
    var body: some View {
        HStack(spacing: 4) {
            Text(tagName)
                .font(.subheadline)
                .foregroundColor(.primary)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 12) {
        TagPillView(tagName: "work") {
            print("Remove work tag")
        }

        TagPillView(tagName: "productivity") {
            print("Remove productivity tag")
        }

        TagPillView(tagName: "ideas") {
            print("Remove ideas tag")
        }
    }
    .padding()
}
