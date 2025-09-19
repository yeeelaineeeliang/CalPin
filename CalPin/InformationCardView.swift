//
//  InformationCardView.swift
//  CalPin
//
//  Enhanced view with sorting and filtering capabilities
//

import Foundation
import SwiftUI
import MapKit

enum SortOption: String, CaseIterable {
    case mostRecent = "Most Recent"
    case mostUrgent = "Most Urgent"
    case nearest = "Nearest"
    
    var icon: String {
        switch self {
        case .mostRecent: return "clock"
        case .mostUrgent: return "exclamationmark.triangle"
        case .nearest: return "location"
        }
    }
}

struct InformationCardView: View {
    let places: [Place]
    @State private var selectedSort: SortOption = .mostRecent
    @State private var showingFilters = false
    @State private var selectedPlace: Place?
    
    private var sortedPlaces: [Place] {
        let openPlaces = places.filter { $0.status == .open && !$0.isExpired }
        
        switch selectedSort {
        case .mostRecent:
            return openPlaces.sorted { $0.createdAt > $1.createdAt }
        case .mostUrgent:
            return openPlaces.sorted { place1, place2 in
                if place1.urgencyLevel.priority != place2.urgencyLevel.priority {
                    return place1.urgencyLevel.priority > place2.urgencyLevel.priority
                }
                return place1.createdAt > place2.createdAt
            }
        case .nearest:
            return openPlaces.sorted { place1, place2 in
                // Extract numeric value from distance string (e.g., "0.5mi" -> 0.5)
                let distance1 = Double(place1.distance.replacingOccurrences(of: "mi", with: "")) ?? Double.infinity
                let distance2 = Double(place2.distance.replacingOccurrences(of: "mi", with: "")) ?? Double.infinity
                return distance1 < distance2
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with sorting options
            headerView
            
            // Request list
            if sortedPlaces.isEmpty {
                emptyStateView
            } else {
                requestListView
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            
            // Title and sort options
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Help Requests")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(sortedPlaces.count) active requests")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Sort picker
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(action: {
                            selectedSort = option
                        }) {
                            HStack {
                                Image(systemName: option.icon)
                                Text(option.rawValue)
                                if selectedSort == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedSort.icon)
                        Text(selectedSort.rawValue)
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Divider()
        }
    }
    
    private var requestListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(sortedPlaces) { place in
                    CardView(place: place)
                        .padding(.horizontal)
                        .onTapGesture {
                            selectedPlace = place
                        }
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Active Requests")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("When students post help requests, they'll appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// Extension for urgency-based visual indicators
extension InformationCardView {
    private func urgencyBadge(for place: Place) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(urgencyColor(for: place.urgencyLevel))
                .frame(width: 6, height: 6)
            
            Text(place.urgencyLevel.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(urgencyColor(for: place.urgencyLevel).opacity(0.15))
        .cornerRadius(10)
    }
    
    private func urgencyColor(for level: UrgencyLevel) -> Color {
        switch level {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .urgent: return .purple
        }
    }
}

// Preview
struct InformationCardView_Previews: PreviewProvider {
    static var previews: some View {
        let samplePlaces = [
            Place(
                title: "Need Help with Physics Lab",
                coordinate: CLLocationCoordinate2D(latitude: 37.8719, longitude: -122.2585),
                description: "Struggling with quantum mechanics experiment setup. Need someone familiar with the equipment.",
                contact: "physics@berkeley.edu",
                distance: "0.2mi",
                duration: "3min",
                urgencyLevel: .urgent,
                status: .open,
                createdAt: Date().addingTimeInterval(-300),
                authorName: "Sarah Kim",
                helpersCount: 0
            ),
            Place(
                title: "Lost Textbook - Organic Chemistry",
                coordinate: CLLocationCoordinate2D(latitude: 37.8690, longitude: -122.2700),
                description: "Left my organic chemistry textbook in the library. If anyone finds it, please let me know!",
                contact: "chem@berkeley.edu",
                distance: "0.8mi",
                duration: "12min",
                urgencyLevel: .medium,
                status: .open,
                createdAt: Date().addingTimeInterval(-1800),
                authorName: "Mike Rodriguez",
                helpersCount: 1
            )
        ]
        
        InformationCardView(places: samplePlaces)
            .previewLayout(.sizeThatFits)
    }
}
