//
//  DraggableCardView.swift
//  CalPin
//

import SwiftUI
import MapKit

struct DraggableCardView: View {
    @Binding var selectedPlace: Place?
    let places: [Place]
    @Binding var offset: CGFloat
    @Binding var isDragging: Bool
    let userToken: String 
    
    // Card position states
    private let minOffset: CGFloat = 100
    private let midOffset: CGFloat = 300
    private let maxOffset: CGFloat = 600
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Draggable handle
                handleView
                
                // Card content
                ScrollView {
                    if let selectedPlace = selectedPlace {
                        // Detailed view for selected place using the enhanced CardView
                        VStack(spacing: 16) {
                            DetailedPlaceCardView(place: selectedPlace, userToken: userToken) {
                                withAnimation(.spring()) {
                                    self.selectedPlace = nil
                                }
                            }
                        }
                        .padding()
                    } else {
                        // List view of all places
                        LazyVStack(spacing: 12) {
                            // Header
                            headerView
                            
                            // Request list using enhanced CardView with token
                            ForEach(sortedPlaces) { place in
                                CardView(place: place, userToken: userToken)
                                    .onTapGesture {
                                        withAnimation(.spring()) {
                                            selectedPlace = place
                                            offset = maxOffset // Expand when selecting
                                        }
                                    }
                                    .padding(.horizontal)
                            }
                            
                            // Empty state
                            if sortedPlaces.isEmpty {
                                emptyStateView
                                    .padding()
                            }
                            
                            // Bottom padding for floating buttons
                            Spacer(minLength: 100)
                        }
                        .padding(.top)
                    }
                }
            }
            .frame(height: offset)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
            )
            .offset(y: geometry.size.height - offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newOffset = offset - value.translation.height
                        offset = max(minOffset, min(maxOffset, newOffset))
                    }
                    .onEnded { value in
                        isDragging = false
                        snapToNearestPosition()
                    }
            )
        }
    }
    
    private var handleView: some View {
        VStack(spacing: 8) {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 6)
                .padding(.top, 8)
            
            // Resize buttons
            HStack(spacing: 20) {
                Button("Mid") {
                    withAnimation(.spring()) {
                        offset = midOffset
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Button("Max") {
                    withAnimation(.spring()) {
                        offset = maxOffset
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.bottom, 8)
            
            // Quick status indicator
            if !isDragging {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text("\(sortedPlaces.count) active requests")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if offset > minOffset + 50 {
                        Text(selectedPlace != nil ? "Request Details" : "Tap requests to view details")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Help Requests Nearby")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Sort indicator
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Recent")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            if offset < midOffset {
                // Compact header for minimized state
                HStack {
                    ForEach(sortedPlaces.prefix(3)) { place in
                        UrgencyDot(level: place.urgencyLevel)
                    }
                    if sortedPlaces.count > 3 {
                        Text("+\(sortedPlaces.count - 3) more")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var sortedPlaces: [Place] {
        places.filter { $0.status == .open && !$0.isExpired }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Active Requests")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("When students post help requests, they'll appear here. Be the first to create one!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func snapToNearestPosition() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            if offset < (minOffset + midOffset) / 2 {
                offset = minOffset
            } else if offset < (midOffset + maxOffset) / 2 {
                offset = midOffset
            } else {
                offset = maxOffset
            }
        }
    }
}

// Detailed card view for selected place - using enhanced CardView with token
struct DetailedPlaceCardView: View {
    let place: Place
    let userToken: String
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with close button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Request")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(place.title)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Use the enhanced CardView for detailed view with token
            CardView(place: place, userToken: userToken)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8)
    }
}

// Small urgency dot for compact view
struct UrgencyDot: View {
    let level: UrgencyLevel
    
    private var color: Color {
        switch level {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .urgent: return .purple
        }
    }
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}

// Urgency badge component
struct UrgencyBadge: View {
    let level: UrgencyLevel
    
    private var urgencyColor: Color {
        switch level {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .urgent: return .purple
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(urgencyColor)
                .frame(width: 8, height: 8)
            
            Text(level.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(urgencyColor.opacity(0.15))
        .cornerRadius(12)
    }
}

// Status badge component
struct StatusBadge: View {
    let status: RequestStatus
    
    private var statusColor: Color {
        switch status {
        case .open: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption2)
            
            Text(status.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(12)
    }
    
    private var statusIcon: String {
        switch status {
        case .open: return "circle"
        case .inProgress: return "clock"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }
}
