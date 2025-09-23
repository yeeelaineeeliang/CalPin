//
//  MapView.swift
//  CalPin
//
//  Fixed implementation with exhaustive switches and proper VStack handling
//

import SwiftUI
import MapKit
import Alamofire
import SwiftyJSON
import Foundation

// Helper function to create Place from JSON - keep existing implementation
func createPlace(from json: [String: Any]) -> Place? {
    guard
        let title = json["title"] as? String,
        let latitude = json["latitude"] as? Double,
        let longitude = json["longitude"] as? Double,
        let description = json["description"] as? String,
        let contact = json["contact"] as? String
    else {
        print("❌ Failed to parse place - missing required fields")
        print("📦 JSON: \(json)")
        return nil
    }

    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    
    let id: String
    if let idString = json["id"] as? String {
        id = idString
    } else if let idInt = json["id"] as? Int {
        id = String(idInt)
    } else {
        print("❌ No valid ID found in JSON")
        return nil
    }
    
    let urgencyString = json["urgencyLevel"] as? String ?? "Medium"
    let urgencyLevel = UrgencyLevel(rawValue: urgencyString) ?? .medium
    let statusString = json["status"] as? String ?? "Open"
    let status = RequestStatus(rawValue: statusString) ?? .open
    let authorName = json["authorName"] as? String ?? "Anonymous"
    let helpersCount = json["helpersCount"] as? Int ?? 0
    let isCurrentUserHelping = json["isCurrentUserHelping"] as? Bool ?? false
    
    let createdAt: Date
    if let createdAtString = json["createdAt"] as? String {
        let formatter = ISO8601DateFormatter()
        createdAt = formatter.date(from: createdAtString) ?? Date()
    } else {
        createdAt = Date()
    }
    
    let distance = json["distance"] as? String ?? "0.2mi"
    let duration = json["duration"] as? String ?? "3min"

    return Place(
        id: id,
        title: title,
        coordinate: coordinate,
        description: description,
        contact: contact,
        distance: distance,
        duration: duration,
        urgencyLevel: urgencyLevel,
        status: status,
        createdAt: createdAt,
        authorName: authorName,
        helpersCount: helpersCount,
        isCurrentUserHelping: isCurrentUserHelping
    )
}

extension MKCoordinateRegion: Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        return lhs.center.latitude == rhs.center.latitude &&
               lhs.center.longitude == rhs.center.longitude &&
               lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
               lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
}

struct MapView: View {
    @State private var isRefreshing = false
    @Binding var token: String
    @Binding var selectedPlace: Place?
    @ObservedObject var obs: observer
    @State private var annotations: [Place]
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.87271049717549, longitude: -122.26090632933469),
        latitudinalMeters: 3000,
        longitudinalMeters: 3000
    )
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var showingLocationAlert = false
    @State private var lastRefreshTime = Date()
    // @State private var refreshTimer: Timer? // 🔥 REMOVED: No more auto-refresh timer
    
    private let locationManager = CLLocationManager()

    init(token: Binding<String>, selectedPlace: Binding<Place?>, observer: observer) {
        self._token = token
        self._selectedPlace = selectedPlace
        self.obs = observer
        _annotations = State(initialValue: [])
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(coordinateRegion: $region,
                showsUserLocation: true,
                annotationItems: annotations) { place in
                MapAnnotation(coordinate: place.coordinate) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.selectedPlace = place
                        }
                    }) {
                        EnhancedPinView(
                            place: place,
                            isSelected: selectedPlace?.id == place.id
                        )
                    }
                }
            }
            .onAppear {
                setupLocationServices()
                refreshData()
                setupNotificationObservers() // 🔥 NEW: Setup observers for manual refresh
            }
            .onDisappear {
                // stopAutoRefresh() // 🔥 REMOVED: No auto-refresh to stop
                removeNotificationObservers() // 🔥 NEW: Clean up observers
            }
            .onChange(of: token) { newToken in
                print("🔄 Token changed, refreshing data...")
                if !newToken.isEmpty {
                    refreshData()
                }
            }
            
            // Map controls
            VStack(spacing: 12) {
                // 🔥 ENHANCED: Manual refresh button with better visual feedback
                Button(action: manualRefresh) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                        
                        Text("\(annotations.count)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    .padding(8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 4)
                }
                .disabled(isRefreshing)
                .opacity(isRefreshing ? 0.6 : 1.0)
                
                Button(action: centerOnUserLocation) {
                    Image(systemName: "location.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
            }
            .padding(.trailing, 16)
            .padding(.top, 60)
        }
        .alert("Location Access", isPresented: $showingLocationAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("CalPin needs location access to show nearby help requests and your current position.")
        }
    }
    
    // 🔥 NEW: Setup notification observers for manual refresh triggers
    private func setupNotificationObservers() {
        // Listen for manual refresh requests (from new request creation, help offers, etc.)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshMapData"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔄 Manual refresh requested via notification")
            self.refreshData()
        }
        
        // Listen for app becoming active (user returns to app)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Only refresh if it's been more than 1 minute since last refresh
            if Date().timeIntervalSince(self.lastRefreshTime) > 60 {
                print("🔄 App became active, refreshing data")
                self.refreshData()
            }
        }
    }
    
    // 🔥 NEW: Remove notification observers
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RefreshMapData"), object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    private func setupLocationServices() {
        locationManager.requestWhenInUseAuthorization()
        
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if let location = locationManager.location {
                userLocation = location.coordinate
                withAnimation {
                    region.center = location.coordinate
                }
            }
        case .denied, .restricted:
            showingLocationAlert = true
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
    
    private func centerOnUserLocation() {
        guard let userLocation = userLocation else {
            setupLocationServices()
            return
        }
        
        withAnimation(.easeInOut(duration: 1.0)) {
            region.center = userLocation
        }
    }
    
    
    // 🔥 NEW: Manual refresh function (called by button or notifications)
    private func manualRefresh() {
        print("👆 Manual refresh button tapped")
        refreshData()
    }
    
    private func refreshData() {
        guard !token.isEmpty else {
            print("⚠️ Cannot refresh - no token available")
            return
        }
        
        isRefreshing = true
        selectedPlace = nil
        lastRefreshTime = Date()
        
        print("🔄 Refreshing data...")
        
        obs.fetchData {
            DispatchQueue.main.async {
                self.isRefreshing = false
                self.updateAnnotations()
                print("✅ Refresh completed - \(self.annotations.count) total pins")
            }
        }
    }
    
    private func updateAnnotations() {
        let allPlaces = obs.datas
        
        if !areAnnotationsEqual(annotations, allPlaces) {
            withAnimation(.easeInOut(duration: 0.3)) {
                annotations = allPlaces
            }
            print("📍 Updated map with \(allPlaces.count) pins from server")
        } else {
            print("📍 No changes in annotations")
        }
    }
    
    private func areAnnotationsEqual(_ lhs: [Place], _ rhs: [Place]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return lhs.allSatisfy { leftPlace in
            rhs.contains { rightPlace in
                leftPlace.id == rightPlace.id &&
                leftPlace.title == rightPlace.title &&
                leftPlace.coordinate.latitude == rightPlace.coordinate.latitude &&
                leftPlace.coordinate.longitude == rightPlace.coordinate.longitude
            }
        }
    }
}

// 🔥 FIXED: Enhanced pin view with proper status handling
struct EnhancedPinView: View {
    let place: Place
    let isSelected: Bool
    
    private var urgencyColor: Color {
        place.urgencyLevel.color
    }
    
    // 🔥 FIXED: Status-aware pin color with exhaustive switch
    private var pinColor: Color {
        switch place.status {
        case .open:
            return urgencyColor
        case .inProgress:
            return Color.orange
        case .completed:
            return Color.green
        case .cancelled:
            return Color.gray
        }
    }
    
    private var pinSize: CGFloat {
        isSelected ? 50 : 35
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Pulsing ring for urgent requests (only if still open)
                if place.urgencyLevel.shouldPulse && place.status == .open {
                    Circle()
                        .stroke(urgencyColor, lineWidth: 2)
                        .frame(width: pinSize + 20, height: pinSize + 20)
                        .scaleEffect(1.0)
                        .opacity(0.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                            value: true
                        )
                }
                
                // Selection ring
                if isSelected {
                    Circle()
                        .stroke(pinColor.opacity(0.4), lineWidth: 4)
                        .frame(width: pinSize + 12, height: pinSize + 12)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 0.3), value: isSelected)
                }
                
                // Main pin with status-aware color
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [pinColor, pinColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: pinSize, height: pinSize)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .overlay(
                        VStack(spacing: 1) {
                            // Main icon - same for consistency
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: pinSize * 0.4, weight: .bold))
                                .foregroundColor(.white)
                            
                            // Show helper count prominently
                            if place.helpersCount > 0 {
                                Text("\(place.helpersCount)")
                                    .font(.system(size: pinSize * 0.25, weight: .bold))
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.3))
                                            .frame(width: pinSize * 0.4, height: pinSize * 0.4)
                                    )
                            }
                        }
                    )
                    .shadow(color: pinColor.opacity(0.4), radius: 6, x: 0, y: 3)
                
                // 🔥 FIXED: Status indicators with proper VStack structure
                statusIndicatorOverlay
            }
            
            // Enhanced label when selected
            if isSelected {
                selectedPinLabel
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
    
    // 🔥 FIXED: Separate status indicator overlay to avoid VStack issues
    private var statusIndicatorOverlay: some View {
        VStack {
            HStack {
                Spacer()
                
                // Status indicator dot
                if place.status != .open {
                    Circle()
                        .fill(statusIndicatorColor())
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .overlay(
                            Image(systemName: statusIcon())
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 2, y: -2)
                }
            }
            Spacer()
        }
        .frame(width: pinSize, height: pinSize)
    }
    
    // 🔥 FIXED: Separate selected pin label to avoid VStack issues
    private var selectedPinLabel: some View {
        VStack(spacing: 3) {
            Text(place.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Show status for in-progress requests
            if place.status == .inProgress {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("In Progress")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                    
                    if place.helpersCount > 0 {
                        Text("(\(place.helpersCount) helping)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)
            } else {
                Text(place.urgencyLevel.timeExpectation ?? "")
                    .font(.caption2)
                    .foregroundColor(urgencyColor)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(urgencyColor.opacity(0.15))
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.95))
        .cornerRadius(12)
        .shadow(radius: 4)
        .frame(maxWidth: 140)
        .transition(.opacity.combined(with: .scale))
    }
    
    // 🔥 FIXED: Helper functions with exhaustive switches
    private func statusIndicatorColor() -> Color {
        switch place.status {
        case .open:
            return .blue
        case .inProgress:
            return .orange
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
    
    private func statusIcon() -> String {
        switch place.status {
        case .open:
            return ""
        case .inProgress:
            return "clock"
        case .completed:
            return "checkmark"
        case .cancelled:
            return "xmark"
        }
    }
}

// Enhanced observer class with better state management and debugging
class observer: ObservableObject {
    @Published var datas = [Place]()
    @Published var isLoading = false
    @Published var lastRefresh: Date?
    @Published var errorMessage: String?
    @Published var lastDatabaseStatus: String = "unknown"
    
    var token: String {
        didSet {
            if token != oldValue {
                print("🔑 Observer token updated (length: \(token.count))")
                if !token.isEmpty {
                    fetchData {}
                }
            }
        }
    }
    
    init(token: String) {
        self.token = token
    }
    
    func fetchData(completion: @escaping () -> Void) {
        guard !token.isEmpty else {
            print("❌ Cannot fetch data - token is empty")
            completion()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Clear the array at the start
        self.datas.removeAll()
        
        let fullURL = "\(NetworkConfig.baseURL)\(NetworkConfig.endpoints.fetch)"
        print("🌐 Attempting to fetch from: \(fullURL)")
        print("🔑 Using token length: \(token.count)")
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        AF.request(fullURL, method: .get, headers: headers)
            .validate()
            .responseJSON { [weak self] response in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.lastRefresh = Date()
                    
                    print("📊 Response status: \(response.response?.statusCode ?? 0)")
                    
                    switch response.result {
                    case .success(let value):
                        let json = JSON(value)
                        print("📊 Raw response: \(json)")
                        
                        if let requestsArray = json.array {
                            var newPlaces: [Place] = []
                            for requestJson in requestsArray {
                                if let placeData = requestJson.dictionaryObject,
                                   let place = createPlace(from: placeData) {
                                    newPlaces.append(place)
                                }
                            }
                            
                            self?.datas = newPlaces
                            print("✅ Fetched \(newPlaces.count) requests")
                            
                            if let responseData = response.data,
                               let responseString = String(data: responseData, encoding: .utf8) {
                                if responseString.contains("database_used") {
                                    self?.lastDatabaseStatus = "connected"
                                } else {
                                    self?.lastDatabaseStatus = "fallback"
                                }
                            }
                        } else {
                            print("⚠️ Response is not an array")
                            self?.errorMessage = "Invalid response format"
                        }
                        
                        completion()
                        
                    case .failure(let error):
                        print("❌ Network error: \(error.localizedDescription)")
                        if let data = response.data, let errorString = String(data: data, encoding: .utf8) {
                            print("❌ Server response: \(errorString)")
                        }
                        self?.errorMessage = error.localizedDescription
                        completion()
                    }
                }
            }
    }
    
    func testConnection() {
        let testURL = "\(NetworkConfig.baseURL)/health"
        print("🧪 Testing connection to: \(testURL)")
        
        AF.request(testURL, method: .get)
            .responseJSON { response in
                print("\n🧪 === CONNECTION TEST ===")
                print("📊 Status: \(response.response?.statusCode ?? 0)")
                if let data = response.data, let string = String(data: data, encoding: .utf8) {
                    print("📊 Response: \(string)")
                }
                print("🧪 === END TEST ===\n")
            }
    }
}

// Preview
struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(
            token: .constant("sample_token"),
            selectedPlace: .constant(nil),
            observer: observer(token: "sample_token")
        )
    }
}
