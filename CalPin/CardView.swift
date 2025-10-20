//
//  CardView.swift
//  CalPin
//


import SwiftUI
import Alamofire

struct CardView: View {
    let place: Place
    let userToken: String
    @State private var isOfferingHelp = false
    @State private var showingContactInfo = false
    @State private var showingSuccess = false
    @State private var successMessage = ""
    
    @EnvironmentObject var userSession: UserSession
    
    // Color scheme
    private let berkeleyBlue = Color(red: 0/255, green: 50/255, blue: 98/255)
    private let californiaGold = Color(red: 253/255, green: 181/255, blue: 21/255)
    
    // Check if current user is the author of this request
    private var isOwnRequest: Bool {
        // We need to get the current user's ID from the backend
        return place.authorName == userSession.userName
    }
    
    // Check if user can offer help (combines all restrictions)
    private var canOfferHelp: Bool {
        return place.status == .open &&
               !place.isCurrentUserHelping &&
               !isOwnRequest
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // AI Category Header
            categoryHeaderView
            
            // Header with title and urgency
            headerView
            
            // Description
            descriptionView
            
            // AI Metadata (Time Estimate, Detected Urgency)
            aiMetadataView
            
            // Location and timing info
            locationInfoView
            
            // Status and helper info
            statusInfoView
            
            // Action buttons
            actionButtonsView
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8)
        .alert("Success!", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            Text(successMessage)
        }
        .sheet(isPresented: $showingContactInfo) {
            ContactInfoView(place: place)
        }
    }
    
    // AI Category Header
    private var categoryHeaderView: some View {
            HStack(spacing: 8) {
                // Category icon and name
                HStack(spacing: 6) {
                    Text(place.aiCategoryIcon ?? place.category.icon)
                        .font(.title3)
                    
                    Text(place.aiCategoryName ?? place.category.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(place.category.color)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(place.category.color.opacity(0.15))
                )
                
                Spacer()
                
                // Time ago
                Text(place.timeAgo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    
    // AI Tags View
        private func tagsView(tags: [String]) -> some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(place.category.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(place.category.color.opacity(0.1))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(place.category.color.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
        }
    
    // AI Metadata View
        private var aiMetadataView: some View {
            HStack(spacing: 16) {
                // Estimated time
                if let timeEstimate = place.estimatedTimeFormatted {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(timeEstimate)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                
                // AI detected urgency (if different from user selected)
                if let detectedUrgency = place.aiDetectedUrgency,
                   detectedUrgency != place.urgencyLevel.rawValue {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("AI: \(detectedUrgency)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
    
    //  Header View
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack {
                    Text("by \(place.authorName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Show "You" indicator for own requests
                    if isOwnRequest {
                        Text("(You)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(berkeleyBlue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(berkeleyBlue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                // Urgency badge
                UrgencyBadge(level: place.urgencyLevel)
                
                // Status badge
                StatusBadge(status: place.status)
            }
        }
    }
    
    // Description View
    private var descriptionView: some View {
        Text(place.description)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(3)
            .padding(.vertical, 4)
    }
    
    // Location Info View
    private var locationInfoView: some View {
        HStack {
            // Distance and time
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .foregroundColor(berkeleyBlue)
                        .font(.caption)
                    Text(place.distance)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundColor(berkeleyBlue)
                        .font(.caption)
                    Text(place.duration)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            // Time ago
            Text(place.timeAgo)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // Status Info View
    private var statusInfoView: some View {
        HStack {
            // Helpers count
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(place.helpersCount > 0 ? .green : .gray)
                    .font(.caption)
                
                Text("\(place.helpersCount) helper\(place.helpersCount == 1 ? "" : "s")")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(place.helpersCount > 0 ? .green : .gray)
            }
            
            // Current user helping status
            if place.isCurrentUserHelping {
                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(californiaGold)
                        .font(.caption)
                    
                    Text("You're helping!")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(californiaGold)
                }
            }
            
            // Own request indicator
            if isOwnRequest {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(berkeleyBlue)
                        .font(.caption)
                    
                    Text("Your request")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(berkeleyBlue)
                }
            }
            
            Spacer()
            
            // Completion indicator
            if place.canBeCompleted && place.isCurrentUserHelping {
                Text("Ready to complete")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    // Action Buttons View
    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            // Contact info button
            Button(action: {
                showingContactInfo = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "envelope")
                        .font(.caption)
                    Text("Contact")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(berkeleyBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(berkeleyBlue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Main action button (dynamic based on state)
            if place.isCurrentUserHelping {
                if place.canBeCompleted {
                    // Complete help button
                    Button(action: completeHelp) {
                        HStack(spacing: 6) {
                            if isOfferingHelp {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                Text("Complete")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .disabled(isOfferingHelp)
                } else {
                    // Already helping indicator
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("Helping")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(californiaGold)
                    .cornerRadius(12)
                }
            } else if isOwnRequest {
                // Own request - cannot offer help
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .font(.caption)
                    Text("Your Request")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            } else if canOfferHelp {
                // Offer help button for other users' open requests
                Button(action: offerHelp) {
                    HStack(spacing: 6) {
                        if isOfferingHelp {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "hand.raised.fill")
                                .font(.caption)
                            Text("Offer Help")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(californiaGold)
                    .cornerRadius(12)
                }
                .disabled(isOfferingHelp)
            } else {
                // Status indicator for non-open requests
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.caption)
                    Text(place.status.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(place.status.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(place.status.color.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // Helper Properties
    
    private var statusIcon: String {
        switch place.status {
        case .open: return "circle"
        case .inProgress: return "clock"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }
    
    // Actions
    
    private func offerHelp() {
        guard !userToken.isEmpty else {
            print("❌ No token available for offering help")
            return
        }
        
        // Double-check restrictions before making the request
        guard canOfferHelp else {
            successMessage = "You cannot offer help on this request."
            showingSuccess = true
            return
        }
        
        isOfferingHelp = true
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(userToken)",
            "Content-Type": "application/json"
        ]
        
        AF.request(
            NetworkConfig.offerHelpURL(for: place.id),
            method: .post,
            headers: headers
        )
        .responseJSON { response in
            DispatchQueue.main.async {
                self.isOfferingHelp = false
                
                switch response.result {
                case .success:
                    print("✅ Successfully offered help for request: \(place.id)")
                    successMessage = "Help offered successfully! The requester will be notified."
                    showingSuccess = true
                    
                    // Trigger a refresh of the data
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshRequests"), object: nil)
                    
                case .failure(let error):
                    print("❌ Failed to offer help: \(error)")
                    if let data = response.data,
                       let errorString = String(data: data, encoding: .utf8) {
                        print("❌ Server response: \(errorString)")
                        
                        // Handle specific error messages from backend
                        if errorString.contains("cannot offer help on your own request") {
                            successMessage = "You cannot offer help on your own request."
                        } else if errorString.contains("already helping") {
                            successMessage = "You are already helping with this request."
                        } else {
                            successMessage = "Failed to offer help. Please try again."
                        }
                    } else {
                        successMessage = "Failed to offer help. Please try again."
                    }
                    showingSuccess = true
                }
            }
        }
    }
    
    private func completeHelp() {
        guard !userToken.isEmpty else {
            print("❌ No token available for completing help")
            return
        }
        
        isOfferingHelp = true
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(userToken)",
            "Content-Type": "application/json"
        ]
        
        AF.request(
            NetworkConfig.completeHelpURL(for: place.id),
            method: .post,
            headers: headers
        )
        .responseJSON { response in
            DispatchQueue.main.async {
                self.isOfferingHelp = false
                
                switch response.result {
                case .success:
                    print("✅ Successfully completed help for request: \(place.id)")
                    successMessage = "Help marked as complete! Thank you for helping a fellow student."
                    showingSuccess = true
                    
                    // Trigger a refresh of the data
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshRequests"), object: nil)
                    
                case .failure(let error):
                    print("❌ Failed to complete help: \(error)")
                    if let data = response.data,
                       let errorString = String(data: data, encoding: .utf8) {
                        print("❌ Server response: \(errorString)")
                    }
                    
                    successMessage = "Failed to complete help. Please try again."
                    showingSuccess = true
                }
            }
        }
    }
}

// Contact Info View
struct ContactInfoView: View {
    let place: Place
    @Environment(\.presentationMode) var presentationMode
    
    private let berkeleyBlue = Color(red: 0/255, green: 50/255, blue: 98/255)
    private let californiaGold = Color(red: 253/255, green: 181/255, blue: 21/255)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(californiaGold)
                        
                        Text("Contact Information")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(berkeleyBlue)
                        
                        Text("Reach out to coordinate help")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    // Request details
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(berkeleyBlue)
                            Text("Request Details")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(berkeleyBlue)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(place.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(place.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                UrgencyBadge(level: place.urgencyLevel)
                                Spacer()
                                Text("Posted \(place.timeAgo)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Contact information
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(berkeleyBlue)
                            Text("Contact Info")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(berkeleyBlue)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Requester name
                            HStack {
                                Image(systemName: "person.circle")
                                    .foregroundColor(.secondary)
                                Text("Requester:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(place.authorName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            // Contact method
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.secondary)
                                Text("Contact:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(place.contact)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(berkeleyBlue)
                            }
                            
                            // Copy contact button
                            Button(action: {
                                UIPasteboard.general.string = place.contact
                                // Could add a toast notification here
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy Contact Info")
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(berkeleyBlue)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Safety reminder
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "shield.fill")
                                .foregroundColor(.green)
                            Text("Safety Reminder")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Meet in public places on campus")
                            Text("• Trust your instincts")
                            Text("• Let someone know where you're going")
                            Text("• Use Berkeley email for verification")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Contact")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(berkeleyBlue)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}



