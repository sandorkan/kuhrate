//
//  NoteContentView.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 26.12.2025.
//

import CoreData
import SwiftUI

struct NoteContentView: View {
    // MARK: - Environment
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - Parameters
    @Binding var content: String
    @Binding var category: CategoryEntity?
    @Binding var tags: Set<TagEntity>
    @Binding var source: String
    @Binding var sourceType: SourceTypeEntity?
    
    // Configuration
    let isEditable: Bool
    
    // Callbacks
    var onTagAdd: ((String) -> Void)?
    var onTagRemove: ((TagEntity) -> Void)?
    
    // MARK: - Fetch Requests (Only relevant for editing)
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.sortOrder, order: .forward)]
    ) private var sourceTypes: FetchedResults<SourceTypeEntity>
    
    // MARK: - State
    @State private var tagInput: String = ""
    @State private var showingCategoryPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Note Content
            ZStack(alignment: .topLeading) {
                if isEditable {
                    TextEditor(text: $content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .font(.body)
                    
                    if content.isEmpty {
                        Text("Start writing your note...")
                            .foregroundColor(Color(uiColor: .placeholderText))
                            .font(.body)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                } else {
                    // Read-only mode
                    ScrollView {
                        Text(content)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                // Source Field
                sourceSection
                
                // Category
                if isEditable {
                    categoryPickerButton
                } else if let category = category {
                    // Read-only Category Badge
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(Color(hex: category.color ?? "#808080"))
                        Text(category.name ?? "")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(10)
                }
                
                // Tags
                tagsSection
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerView(selectedCategory: $category)
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    // MARK: - Subviews
    
    private var sourceSection: some View {
        VStack(spacing: 8) {
            // If read-only and no source, hide section
            if !isEditable && source.isEmpty {
                EmptyView()
            } else {
                HStack {
                    Image(systemName: sourceType?.icon ?? "quote.bubble")
                        .foregroundColor(.gray)
                    
                    if isEditable {
                        TextField("Source (URL, book, podcast...)", text: $source)
                            .font(.body)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.default)
                            .onChange(of: source) { newValue in
                                detectSourceType(for: newValue)
                            }
                        
                        if !source.isEmpty {
                            Button {
                                source = ""
                                sourceType = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    } else {
                        // Read-only Source
                        if let url = URL(string: source), UIApplication.shared.canOpenURL(url) {
                            Link(source, destination: url)
                                .font(.body)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                        } else {
                            Text(source)
                                .font(.body)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)
                
                // Source Type Picker (Only Editable)
                if isEditable && !source.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sourceTypes) { type in
                                Button {
                                    if sourceType?.id == type.id {
                                        sourceType = nil
                                    } else {
                                        sourceType = type
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: type.icon ?? "circle")
                                        Text(type.name ?? "")
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        sourceType?.id == type.id
                                        ? Color.blue
                                        : Color(uiColor: .tertiarySystemBackground)
                                    )
                                    .foregroundColor(
                                        sourceType?.id == type.id
                                        ? .white
                                        : .primary
                                    )
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color(uiColor: .separator), lineWidth: sourceType?.id == type.id ? 0 : 0.5)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tag Input (Only Editable)
            if isEditable {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.gray)
                    TextField("Add tags (space or comma separated)", text: $tagInput)
                        .font(.body)
                        .onSubmit {
                            onTagAdd?(tagInput)
                            tagInput = ""
                        }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)
            }
            
            // Tag Pills
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(tags).sorted(by: { ($0.name ?? "") < ($1.name ?? "") }), id: \.id) { tag in
                            TagPillView(
                                tagName: tag.name ?? "",
                                onRemove: isEditable ? {
                                    onTagRemove?(tag)
                                } : nil // No remove action in read-only
                            )
                        }
                    }
                    .padding(.horizontal, 4) // Visual padding
                }
            }
        }
    }
    
    private var categoryPickerButton: some View {
        Button {
            showingCategoryPicker = true
        } label: {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(category?.color != nil ? Color(hex: category!.color!) : .gray)
                Text("Category")
                    .foregroundColor(.primary)
                Spacer()
                Text(category?.name ?? "")
                    .foregroundColor(.gray)
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Logic
    
    private func detectSourceType(for text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("http") {
             if let linkType = sourceTypes.first(where: { $0.name == "Link" }) {
                 if sourceType == nil || sourceType?.name == "Other" {
                     sourceType = linkType
                 }
             }
        }
        if trimmed.isEmpty {
            sourceType = nil
        }
    }
}
