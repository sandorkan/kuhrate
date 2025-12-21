//
//  CategoryPickerView.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 19.12.2025.
//

import SwiftUI
import CoreData

struct CategoryPickerView: View {
    // MARK: - Environment
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - Fetch Request
    // Fetch all categories, sorted alphabetically by name
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CategoryEntity.sortOrder, ascending: true)],
        animation: .default)
    private var categories: FetchedResults<CategoryEntity>

    // MARK: - Binding
    // The selected category (passed from parent view)
    @Binding var selectedCategory: CategoryEntity?

    // MARK: - Body
    var body: some View {
        NavigationStack {
            List {
                // "None" option to clear category selection
                Button {
                    selectedCategory = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("None")
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedCategory == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Display all categories
                ForEach(categories) { category in
                    Button {
                        selectedCategory = category
                        dismiss()
                    } label: {
                        HStack {
                            // Colored circle indicator
                            Circle()
                                .fill(Color(hex: category.color ?? "#137fec"))
                                .frame(width: 12, height: 12)

                            Text(category.name ?? "")
                                .foregroundColor(.primary)

                            Spacer()

                            // Show checkmark if this category is selected
                            if selectedCategory?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    CategoryPickerView(selectedCategory: .constant(nil))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

