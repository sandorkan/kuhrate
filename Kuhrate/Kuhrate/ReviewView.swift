//
//  ReviewView.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 26.12.2025.
//

import CoreData
import SwiftUI

struct ReviewView: View {
    // MARK: - Environment
    @Environment(\.dismiss) var dismiss
    
    // MARK: - State Object
    @StateObject var viewModel: ReviewViewModel
    
    init(viewModel: ReviewViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Content
            if viewModel.isFinished && viewModel.progress == 1.0 {
                if viewModel.currentNote != nil {
                    cardView(for: viewModel.currentNote!)
                } else {
                    completionView
                }
            } else if let note = viewModel.currentNote {
                cardView(for: note)
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
        .background(Color(uiColor: .systemGroupedBackground)) // Light gray background
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                
                Spacer()
                
                Text("Review Session")
                    .font(.headline)
                
                Spacer()
                
                // Placeholder
                Color.clear.frame(width: 32, height: 32)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Progress Bar
            VStack(spacing: 8) {
                Text(viewModel.progressText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                GeometryReader {
                    geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * viewModel.progress, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 8)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    private func cardView(for note: NoteEntity) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            // The White Card
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text(note.content?.components(separatedBy: .newlines).first ?? "Untitled")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Date
                if let date = note.createdDate {
                    Text(date, formatter: itemDateFormatter)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Divider
                Divider().padding(.vertical, 4)
                
                // Body
                ScrollView {
                    Text(note.content?.components(separatedBy: .newlines).dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                }
                
                Spacer()
                
                // Metadata Footer (Source & Category)
                VStack(alignment: .leading, spacing: 12) {
                    if let source = note.source, !source.isEmpty {
                        HStack {
                            Image(systemName: note.sourceType?.icon ?? "quote.bubble")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            Text(source)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    if let category = note.category {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(Color(hex: category.color ?? "#808080"))
                                .frame(width: 20)
                            Text(category.name ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 12)
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(borderColor, lineWidth: 4)
            )
            .padding(.horizontal, 20)
            
            // Action Buttons
            HStack(spacing: 60) {
                actionButton(
                    icon: "archivebox",
                    label: "Archive",
                    color: .red,
                    isSelected: viewModel.currentActionType == .archived,
                    action: viewModel.archive
                )
                
                actionButton(
                    icon: "arrow.up",
                    label: "Keep",
                    color: .blue,
                    isSelected: viewModel.currentActionType == .kept,
                    action: viewModel.keep
                )
            }
            
            Spacer()
            
            // Bottom Navigation
            HStack {
                Button(action: viewModel.previous) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .foregroundColor(viewModel.canGoBack ? .gray : .gray.opacity(0.3))
                }
                .disabled(!viewModel.canGoBack)
                
                Spacer()
                
                if !viewModel.canGoForward {
                    if viewModel.progress == 1.0 {
                        Button(action: { dismiss() }) {
                            Text("Finish")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    } else {
                        Button(action: {}) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.gray.opacity(0.3))
                        }
                        .disabled(true)
                    }
                } else {
                    Button(action: viewModel.next) {
                        HStack {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(viewModel.canGoForward ? .gray : .gray.opacity(0.3))
                    }
                    .disabled(!viewModel.canGoForward)
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 40)
            .padding(.bottom, 10)
        }
    }
    
    private func actionButton(icon: String, label: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color : color.opacity(0.1))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : color)
                }
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(isSelected ? color : .gray)
            }
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Session Complete!")
                .font(.title.bold())
            
            Text("You reviewed \(viewModel.session.notesReviewed) notes.")
                .foregroundColor(.secondary)
            
            Button {
                dismiss()
            } label: {
                Text("Back to Home")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(24)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private var borderColor: Color {
        switch viewModel.currentActionType {
        case .kept: return .blue.opacity(0.5)
        case .archived: return .red.opacity(0.5)
        case nil: return .clear
        }
    }
    
    private let itemDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}
