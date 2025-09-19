//
//  CardView.swift
//  CalPin
//
//  Enhanced card view with urgency indicators and help functionality
//

import Foundation
import SwiftUI
import MapKit

struct CardView: View {
    let place: Place
    @State private var isHelpOffered = false
    @State private var showingHelpConfirmation = false
    
    private var urgencyColor: Color {
        switch place.urgencyLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .urgent: return .purple
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and urgency
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                    
                    Text("by \(place.authorName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Urgency badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(urgencyColor)
                            .frame(width: 8, height: 8)
                        Text(place.urgencyLevel.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(urgencyColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(urgencyColor.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Time stamp
                    Text(place.timeAgo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Description
            Text(place.description)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(3)
            
            // Location and distance info
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text("\(place.distance) away • \(place.duration)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if place.helpersCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("\(place.helpersCount)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                // Help button
                Button(action: {
                    showingHelpConfirmation = true
                }) {
                    HStack {
                        Image(systemName: isHelpOffered ? "checkmark.circle.fill" : "hand.raised.fill")
                        Text(isHelpOffered ? "Help Offered" : "Offer Help")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isHelpOffered ? Color.gray : Color.green)
                    .cornerRadius(8)
                }
                .disabled(isHelpOffered || place.status != .open)
                
                // Contact button
                Button(action: {
                    // Open contact options
                    contactHelper()
                }) {
                    HStack {
                        Image(systemName: "message.fill")
                        Text("Contact")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Status indicator
            if place.status != .open {
                HStack {
                    Image(systemName: statusIcon(for: place.status))
                        .foregroundColor(statusColor(for: place.status))
                    Text(place.status.rawValue)
                        .font(.caption)
                        .foregroundColor(statusColor(for: place.status))
                        .fontWeight(.medium)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(
            // Left border indicating urgency
            Rectangle()
                .fill(urgencyColor)
                .frame(width: 4)
                .cornerRadius(2),
            alignment: .leading
        )
        .alert("Offer Help", isPresented: $showingHelpConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm") {
                offerHelp()
            }
        } message: {
            Text("Are you sure you want to offer help for '\(place.title)'?")
        }
    }
    
    private func statusIcon(for status: RequestStatus) -> String {
        switch status {
        case .open: return "circle"
        case .inProgress: return "clock.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
    
    private func statusColor(for status: RequestStatus) -> Color {
        switch status {
        case .open: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
    
    private func offerHelp() {
        // TODO: Implement API call to offer help
        withAnimation {
            isHelpOffered = true
        }
        
        // Here you would typically make an API call
        // HelpService.shared.offerHelp(for: place.id) { success in
        //     if success {
        //         // Handle success
        //     }
        // }
    }
    
    private func contactHelper() {
        // Open contact options (email, phone, etc.)
        if let url = URL(string: "mailto:\(place.contact)") {
            UIApplication.shared.open(url)
        }
    }
}

// Preview
struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        let samplePlace = Place(
            title: "Need Help with Calculus Homework",
            coordinate: CLLocationCoordinate2D(latitude: 37.8719, longitude: -122.2585),
            description: "I'm struggling with integration by parts and could really use someone to explain the concept. Happy to meet at the library or a coffee shop nearby.",
            contact: "student@berkeley.edu",
            distance: "0.3mi",
            duration: "4min",
            urgencyLevel: .high,
            status: .open,
            authorName: "Alex Chen",
            helpersCount: 2
        )
        
        CardView(place: samplePlace)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
