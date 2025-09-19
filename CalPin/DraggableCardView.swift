//
//  DraggableCardView.swift
//  CalPin
//
//  Draggable and resizable bottom card for displaying help requests
//

import SwiftUI
import MapKit

struct DraggableCardView: View {
    @Binding var selectedPlace: Place?
    let places: [Place]
    @Binding var offset: CGFloat
    @Binding var isDragging: Bool
    
    // Card position states
    private let minOffset: CGFloat = 100   // Minimized card height
    private let midOffset: CGFloat = 300   // Default height
    private let maxOffset: CGFloat = 600   // Maximum height
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Draggable handle
                handleView
                
                // Card content
                ScrollView {
                    if let selectedPlace = selectedPlace {
                        // Detailed view for selected place
                        VStack(spacing: 16) {
                            DetailedPlaceCardView(place: selectedPlace) {
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
                            
                            // Request list
                            ForEach(sortedPlaces) { place in
                                CompactCardView(place: place) {
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
                        // Use value.translation.y (not gesture.translation.y)
                        // Negative translation means dragging up, which should increase offset
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
            
            // Test buttons for resizing (temporary)
            HStack(spacing: 20) {
//                Button("Min") {
//                    withAnimation(.spring()) {
//                        offset = minOffset
//                    }
//                }
//                .font(.caption)
//                .foregroundColor(.blue)
                
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
                        Text(selectedPlace != nil ? "Request Details" : "Tap buttons to resize")
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
                
                // Sort indicator (simplified for space)
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
            
            Text("When students post help requests, they'll appear here.")
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

// Compact card view for the list
struct CompactCardView: View {
    let place: Place
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Urgency indicator
                Circle()
                    .fill(urgencyColor)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack {
                        Text(place.timeAgo)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(place.distance)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if place.helpersCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "person.2.fill")
                                    .font(.caption2)
                                Text("\(place.helpersCount)")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var urgencyColor: Color {
        switch place.urgencyLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .urgent: return .purple
        }
    }
}


// Detailed card view for selected place
struct DetailedPlaceCardView: View {
    let place: Place
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with close button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("by \(place.authorName) • \(place.timeAgo)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Urgency and status
            HStack {
                UrgencyBadge(level: place.urgencyLevel)
                StatusBadge(status: place.status)
                Spacer()
            }
            
            // Description
            Text(place.description)
                .font(.body)
                .lineSpacing(2)
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                        Text("Offer Help")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "message.fill")
                        Text("Contact")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
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
