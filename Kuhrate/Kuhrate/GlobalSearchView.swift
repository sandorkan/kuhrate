//
//  GlobalSearchView.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 26.12.2025.
//

import CoreData
import SwiftUI

struct GlobalSearchView: View {
    // MARK: - Environment
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - ViewModel
    @StateObject var viewModel: SearchViewModel
    
    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: SearchViewModel(context: context))
    }
    
    // MARK: - State
    @FocusState private var isSearchFocused: Bool
    @State private var activeFilterSheet: FilterSheetType?
    
    enum FilterSheetType: Identifiable {
        case sourceType
        case category
        case tag
        case date
        
        var id: Int { hashValue }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Area (White background)
                VStack(spacing: 12) {
                    // Search Bar Row
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            
                            TextField("Search all notes...", text: $viewModel.searchText)
                                .focused($isSearchFocused)
                                .submitLabel(.search)
                            
                            if !viewModel.searchText.isEmpty {
                                Button {
                                    viewModel.searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(10)
                        
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    
                    // Filter Chips Row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // Type Filter
                            FilterChip(
                                label: typeLabel,
                                isActive: !viewModel.selectedSourceTypes.isEmpty,
                                action: { activeFilterSheet = .sourceType },
                                clearAction: { viewModel.selectedSourceTypes.removeAll() }
                            )
                            
                            // Category Filter
                            FilterChip(
                                label: categoryLabel,
                                isActive: !viewModel.selectedCategories.isEmpty,
                                action: { activeFilterSheet = .category },
                                clearAction: { viewModel.selectedCategories.removeAll() }
                            )
                            
                            // Tag Filter
                            FilterChip(
                                label: tagLabel,
                                isActive: !viewModel.selectedTags.isEmpty,
                                action: { activeFilterSheet = .tag },
                                clearAction: { viewModel.selectedTags.removeAll() }
                            )
                            
                            // Date Filter
                            FilterChip(
                                label: dateLabel,
                                isActive: viewModel.dateFilter != nil || viewModel.isCustomDateFilterActive,
                                action: { activeFilterSheet = .date },
                                clearAction: { 
                                    viewModel.dateFilter = nil
                                    viewModel.isCustomDateFilterActive = false
                                }
                            )
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 12)
                }
                .background(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 5)
                .zIndex(1) // Keep shadow on top of list
                
                // Results List
                if viewModel.results.isEmpty && viewModel.searchText.isEmpty && 
                    viewModel.selectedSourceTypes.isEmpty && viewModel.selectedCategories.isEmpty && 
                    viewModel.selectedTags.isEmpty && viewModel.dateFilter == nil && !viewModel.isCustomDateFilterActive {
                    // Empty Initial State
                    VStack {
                        Spacer()
                        Image("SearchIllustration")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 240, height: 240)
                            .padding(.bottom, 20)
                        
                        Text("Search your knowledge base")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else if viewModel.results.isEmpty {
                    // No Results
                    VStack {
                        Spacer()
                        Text("No results found")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            Text("\(viewModel.results.count) RESULTS FOUND")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                            
                            ForEach(viewModel.results) { note in
                                NavigationLink(destination: NoteEditorView(note: note)) {
                                    VStack(spacing: 0) {
                                        HomeNoteRowView(note: note)
                                            .padding(.vertical, 12)
                                            .padding(.horizontal)
                                        
                                        Divider()
                                            .padding(.leading, 16)
                                    }
                                    .contentShape(Rectangle()) // Make full row tappable
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear {
                isSearchFocused = true
            }
            .sheet(item: $activeFilterSheet) { type in
                FilterSheetView(type: type, viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    // MARK: - Label Helpers
    private var typeLabel: String {
        if viewModel.selectedSourceTypes.isEmpty {
            return "Type"
        } else if viewModel.selectedSourceTypes.count == 1 {
            return "Type: \(viewModel.selectedSourceTypes.first?.name ?? "")"
        } else {
            return "Type: \(viewModel.selectedSourceTypes.count)"
        }
    }
    
    private var categoryLabel: String {
        if viewModel.selectedCategories.isEmpty {
            return "Category"
        } else if viewModel.selectedCategories.count == 1 {
            return "Category: \(viewModel.selectedCategories.first?.name ?? "")"
        } else {
            return "Category: \(viewModel.selectedCategories.count)"
        }
    }
    
    private var tagLabel: String {
        if viewModel.selectedTags.isEmpty {
            return "Tags"
        } else if viewModel.selectedTags.count == 1 {
            return "Tag: \(viewModel.selectedTags.first?.name ?? "")"
        } else {
            return "Tags: \(viewModel.selectedTags.count)"
        }
    }
    
    private var dateLabel: String {
        if let filter = viewModel.dateFilter {
            return "Date: \(filter.rawValue)"
        } else if viewModel.isCustomDateFilterActive {
            let df = DateFormatter()
            df.dateFormat = "d.M"
            return "Date: \(df.string(from: viewModel.customStartDate)) - \(df.string(from: viewModel.customEndDate))"
        } else {
            return "Date"
        }
    }
}

// MARK: - Subcomponents

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void
    let clearAction: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline)
                
                if isActive {
                    Button {
                        clearAction()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.bold())
                    }
                } else {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? Color.blue : Color(uiColor: .secondarySystemBackground))
            .foregroundColor(isActive ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct FilterSheetView: View {
    let type: GlobalSearchView.FilterSheetType
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.dismiss) var dismiss
    
    @FetchRequest(sortDescriptors: [SortDescriptor(\.name)]) var sourceTypes: FetchedResults<SourceTypeEntity>
    @FetchRequest(sortDescriptors: [SortDescriptor(\.name)]) var categories: FetchedResults<CategoryEntity>
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.name)],
        predicate: NSPredicate(format: "notes.@count > 0")
    ) var tags: FetchedResults<TagEntity>
    
    var body: some View {
        NavigationStack {
            List {
                switch type {
                case .sourceType:
                    ForEach(sourceTypes) { source in
                        Button {
                            toggleSource(source)
                        } label: {
                            HStack {
                                Image(systemName: source.icon ?? "circle")
                                Text(source.name ?? "")
                                Spacer()
                                if viewModel.selectedSourceTypes.contains(source) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                case .category:
                    ForEach(categories) { category in
                        Button {
                            toggleCategory(category)
                        } label: {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(Color(hex: category.color ?? "#808080"))
                                Text(category.name ?? "")
                                Spacer()
                                if viewModel.selectedCategories.contains(category) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                case .tag:
                    ForEach(tags) { tag in
                        Button {
                            toggleTag(tag)
                        } label: {
                            HStack {
                                Image(systemName: "tag")
                                Text(tag.name ?? "")
                                Spacer()
                                if viewModel.selectedTags.contains(tag) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                case .date:
                    Section("Presets") {
                        ForEach(DateFilterOption.allCases) { option in
                            Button {
                                if viewModel.dateFilter == option {
                                    viewModel.dateFilter = nil
                                } else {
                                    viewModel.dateFilter = option
                                }
                                dismiss()
                            } label: {
                                HStack {
                                    Text(option.rawValue)
                                    Spacer()
                                    if viewModel.dateFilter == option {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    
                    Section("Custom Range") {
                        DatePicker("From", selection: $viewModel.customStartDate, displayedComponents: .date)
                        DatePicker("To", selection: $viewModel.customEndDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
    
    var title: String {
        switch type {
        case .sourceType: return "Filter by Type"
        case .category: return "Filter by Category"
        case .tag: return "Filter by Tag"
        case .date: return "Filter by Date"
        }
    }
    
    func toggleSource(_ source: SourceTypeEntity) {
        if viewModel.selectedSourceTypes.contains(source) {
            viewModel.selectedSourceTypes.remove(source)
        } else {
            viewModel.selectedSourceTypes.insert(source)
        }
    }
    
    func toggleCategory(_ category: CategoryEntity) {
        if viewModel.selectedCategories.contains(category) {
            viewModel.selectedCategories.remove(category)
        } else {
            viewModel.selectedCategories.insert(category)
        }
    }
    
    func toggleTag(_ tag: TagEntity) {
        if viewModel.selectedTags.contains(tag) {
            viewModel.selectedTags.remove(tag)
        } else {
            viewModel.selectedTags.insert(tag)
        }
    }
}
