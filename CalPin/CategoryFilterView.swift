//
//  CategoryFilterView.swift
//  CalPin
//

import SwiftUI
import Alamofire

import SwiftUI
import Alamofire

// Category with count for display
struct CategoryWithCount: Identifiable {
    let id: String
    let category: AICategory
    let count: Int
    
    var displayName: String { category.displayName }
    var icon: String { category.icon }
    var color: Color { category.color }
}

struct CategoryFilterView: View {
    @Binding var selectedCategory: AICategory?
    let userToken: String
    @State private var categories: [CategoryWithCount] = []
    @State private var isLoading = false
    
    private let berkeleyBlue = Color(red: 0/255, green: 50/255, blue: 98/255)
    
    var body: some View {
        VStack(spacing: 0) {
            // Add safe area padding at top
            Color.clear
                .frame(height: 0)
                .background(Color(.systemBackground))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // "All" category chip
                    CategoryChip(
                        title: "All",
                        icon: "list.bullet",
                        count: categories.reduce(0) { $0 + $1.count },
                        color: berkeleyBlue,
                        isSelected: selectedCategory == nil
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = nil
                        }
                    }
                    
                    // Category chips
                    ForEach(categories) { categoryWithCount in
                        CategoryChip(
                            title: categoryWithCount.displayName,
                            icon: categoryWithCount.icon,
                            count: categoryWithCount.count,
                            color: categoryWithCount.color,
                            isSelected: selectedCategory == categoryWithCount.category
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                if selectedCategory == categoryWithCount.category {
                                    selectedCategory = nil
                                } else {
                                    selectedCategory = categoryWithCount.category
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12) // Increased vertical padding
            }
        }
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .onAppear {
            fetchCategories()
        }
    }
    
    private func fetchCategories() {
        guard !userToken.isEmpty, !isLoading else { return }
        
        isLoading = true
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(userToken)"
        ]
        
        AF.request(
            "\(NetworkConfig.baseURL)/api/ai/categories",
            method: .get,
            headers: headers
        )
        .responseDecodable(of: [CategoryResponse].self) { response in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch response.result {
                case .success(let categoryResponses):
                    // Convert to CategoryWithCount
                    self.categories = categoryResponses.compactMap { response in
                        guard let category = AICategory(rawValue: response.id) else {
                            return nil
                        }
                        return CategoryWithCount(
                            id: response.id,
                            category: category,
                            count: response.count
                        )
                    }
                    .sorted { $0.count > $1.count } // Sort by count descending
                    
                    print("Loaded \(self.categories.count) categories")
                    
                case .failure(let error):
                    print("Failed to load categories: \(error)")
                    // Fallback to default categories with 0 count
                    self.categories = AICategory.allCases.map { category in
                        CategoryWithCount(id: category.rawValue, category: category, count: 0)
                    }
                }
            }
        }
    }
}

// MARK: - Category Chip Component
struct CategoryChip: View {
    let title: String
    let icon: String
    let count: Int
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Icon (emoji or SF Symbol)
                if icon.count == 1 || icon.contains("\\u") {
                    // It's an emoji
                    Text(icon)
                        .font(.title3)
                } else {
                    // It's an SF Symbol
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(isSelected ? .white : color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: isSelected ? 0 : 1.5)
            )
            .shadow(
                color: isSelected ? color.opacity(0.3) : .clear,
                radius: 8,
                y: 4
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Response Model
struct CategoryResponse: Codable {
    let id: String
    let name: String
    let icon: String
    let count: Int
}
