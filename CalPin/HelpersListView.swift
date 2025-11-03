//
//  HelpersListView.swift
//  CalPin
//

import SwiftUI
import Alamofire

// MARK: - Helper Model
struct Helper: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
    let status: String
    let offeredAt: Date
    let completedAt: Date?
    
    var statusDisplayName: String {
        switch status {
        case "active", "pending": return "Pending"
        case "accepted": return "Accepted"
        case "rejected": return "Not Selected"
        case "completed": return "Completed"
        case "cancelled": return "Cancelled"
        default: return status.capitalized
        }
    }
    
    var statusColor: Color {
        switch status {
        case "active", "pending": return .blue
        case "accepted": return .green
        case "rejected": return .gray
        case "completed": return .purple
        case "cancelled": return .red
        default: return .secondary
        }
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: offeredAt, relativeTo: Date())
    }
}

// MARK: - Helpers List View
struct HelpersListView: View {
    let place: Place
    let userToken: String
    @Environment(\.presentationMode) var presentationMode
    
    @State private var helpers: [Helper] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    @State private var successMessage = ""
    
    private let berkeleyBlue = Color(red: 0/255, green: 50/255, blue: 98/255)
    private let californiaGold = Color(red: 253/255, green: 181/255, blue: 21/255)
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("Loading helpers...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("Try Again") {
                            fetchHelpers()
                        }
                        .padding()
                        .background(berkeleyBlue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                } else if helpers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No helpers yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("When someone offers to help, they'll appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Request summary
                            requestSummaryCard
                            
                            // Helpers list
                            VStack(spacing: 12) {
                                ForEach(helpers) { helper in
                                    helperCard(helper: helper)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Help Offers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(berkeleyBlue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: fetchHelpers) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(berkeleyBlue)
                    }
                }
            }
        }
        .onAppear {
            fetchHelpers()
        }
        .alert("Success!", isPresented: $showingSuccess) {
            Button("OK") {
                // Refresh after accepting
                fetchHelpers()
                // Post notification to refresh main view
                NotificationCenter.default.post(name: NSNotification.Name("RefreshRequests"), object: nil)
            }
        } message: {
            Text(successMessage)
        }
    }
    
    // MARK: - Request Summary Card
    private var requestSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(berkeleyBlue)
                Text("Your Request")
                    .font(.headline)
                    .foregroundColor(berkeleyBlue)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(place.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(place.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    StatusBadge(status: place.status)
                    
                    Spacer()
                    
                    Text("\(helpers.count) offer\(helpers.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Helper Card
    private func helperCard(helper: Helper) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Helper avatar
                Circle()
                    .fill(berkeleyBlue.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(helper.name.prefix(2).uppercased())
                            .font(.headline)
                            .foregroundColor(berkeleyBlue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(helper.name)
                        .font(.headline)
                    
                    Text(helper.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Offered \(helper.timeAgo)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status badge
                Text(helper.statusDisplayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(helper.statusColor)
                    .cornerRadius(8)
            }
            
            // Accept button (only show if request is still Open and helper is pending)
            if place.status == .open && (helper.status == "active" || helper.status == "pending") {
                Button(action: {
                    acceptHelper(helperId: helper.id)
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Accept Helper")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(californiaGold)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }
    
    // MARK: - Fetch Helpers
    private func fetchHelpers() {
        isLoading = true
        errorMessage = nil
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(userToken)",
            "Content-Type": "application/json"
        ]
        
        let apiURL = NetworkConfig.baseURL
        
        // Create decoder with ISO8601 date strategy
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        AF.request(
            "\(apiURL)/api/requests/\(place.id)/helpers",
            method: .get,
            headers: headers
        )
        .responseDecodable(of: HelpersResponse.self, decoder: decoder) { response in
            DispatchQueue.main.async {
                isLoading = false
                
                switch response.result {
                case .success(let helpersResponse):
                    print("✅ Fetched \(helpersResponse.helpers.count) helpers")
                    self.helpers = helpersResponse.helpers
                    
                case .failure(let error):
                    print("❌ Failed to fetch helpers: \(error)")
                    if let data = response.data,
                       let errorString = String(data: data, encoding: .utf8) {
                        print("❌ Server response: \(errorString)")
                    }
                    errorMessage = "Failed to load helpers. Please try again."
                }
            }
        }
    }
    
    // MARK: - Accept Helper
    private func acceptHelper(helperId: String) {
        isLoading = true
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(userToken)",
            "Content-Type": "application/json"
        ]
        
        let parameters: [String: Any] = [
            "helperId": helperId
        ]
        
        let apiURL = NetworkConfig.baseURL
        
        AF.request(
            "\(apiURL)/api/requests/\(place.id)/accept-helper",
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers
        )
        .responseJSON { response in
            DispatchQueue.main.async {
                isLoading = false
                
                switch response.result {
                case .success:
                    print("✅ Helper accepted successfully")
                    successMessage = "Helper accepted! They'll be notified to coordinate with you."
                    showingSuccess = true
                    
                case .failure(let error):
                    print("❌ Failed to accept helper: \(error)")
                    if let data = response.data,
                       let errorString = String(data: data, encoding: .utf8) {
                        print("❌ Server response: \(errorString)")
                    }
                    errorMessage = "Failed to accept helper. Please try again."
                }
            }
        }
    }
}

// MARK: - Response Models
struct HelpersResponse: Codable {
    let helpers: [Helper]
}
