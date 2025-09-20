//
//  MapView.swift
//  CalPin
//
//  Clean production map view without debug elements
//

import SwiftUI
import MapKit
import Alamofire
import SwiftyJSON
import Foundation

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
    
    // Parse additional fields with defaults
    let urgencyString = json["urgencyLevel"] as? String ?? "Medium"
    let urgencyLevel = UrgencyLevel(rawValue: urgencyString) ?? .medium
    let statusString = json["status"] as? String ?? "Open"
    let status = RequestStatus(rawValue: statusString) ?? .open
    let authorName = json["authorName"] as? String ?? "Anonymous"
    let helpersCount = json["helpersCount"] as? Int ?? 0
    
    // Parse dates
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
        helpersCount: helpersCount
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
    @State private var refreshTimer: Timer?
    
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
                startAutoRefresh()
            }
            .onDisappear {
                stopAutoRefresh()
            }
            .onChange(of: token) { newToken in
                print("🔄 Token changed, refreshing data...")
                if !newToken.isEmpty {
                    refreshData()
                }
            }
            
            // Map controls - cleaned up, no debug button
            VStack(spacing: 12) {
                // Refresh button with status indicator
                Button(action: refreshData) {
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
    
    private func setupLocationServices() {
        locationManager.requestWhenInUseAuthorization()
        
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if let location = locationManager.location {
                userLocation = location.coordinate
                // Center map on user location
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
    
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            if !token.isEmpty && !isRefreshing {
                print("⏰ Auto-refreshing data...")
                refreshData()
            }
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func refreshData() {
        guard !token.isEmpty else {
            print("⚠️ Cannot refresh - no token available")
            return
        }
        
        isRefreshing = true
        selectedPlace = nil
        lastRefreshTime = Date()
        
        print("🔄 Manual refresh initiated...")
        
        obs.fetchData {
            DispatchQueue.main.async {
                self.isRefreshing = false
                self.updateAnnotations()
                print("✅ Refresh completed - \(self.annotations.count) total pins")
            }
        }
    }
    
    private func updateAnnotations() {
        // Only use fetched data - no sample pin
        let allPlaces = obs.datas
        
        // Only update if annotations actually changed to prevent unnecessary re-renders
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

// Enhanced pin view with urgency indicators
struct EnhancedPinView: View {
    let place: Place
    let isSelected: Bool
    
    private var urgencyColor: Color {
        switch place.urgencyLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .urgent: return .purple
        }
    }
    
    private var pinSize: CGFloat {
        isSelected ? 50 : 35
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Outer ring for selection
                if isSelected {
                    Circle()
                        .stroke(urgencyColor, lineWidth: 3)
                        .frame(width: pinSize + 10, height: pinSize + 10)
                        .scaleEffect(isSelected ? 1.2 : 1.0)
                        .opacity(0.6)
                        .animation(.easeInOut(duration: 0.3), value: isSelected)
                }
                
                // Main pin
                Circle()
                    .fill(urgencyColor)
                    .frame(width: pinSize, height: pinSize)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .overlay(
                        VStack(spacing: 1) {
                            Image(systemName: iconForPlace(place))
                                .font(.system(size: pinSize * 0.4, weight: .bold))
                                .foregroundColor(.white)
                            
                            if place.helpersCount > 0 {
                                Text("\(place.helpersCount)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // Urgency indicator for urgent requests
                if place.urgencyLevel == .urgent {
                    Circle()
                        .stroke(urgencyColor, lineWidth: 2)
                        .frame(width: pinSize + 20, height: pinSize + 20)
                        .scaleEffect(1.0)
                        .opacity(0.0)
                        .animation(
                            .easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true),
                            value: true
                        )
                        .onAppear {
                            // This creates the pulsing effect for urgent requests
                        }
                }
            }
            
            // Title label (only show when selected)
            if isSelected {
                Text(place.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 120)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
    
    private func iconForPlace(_ place: Place) -> String {
        // You could categorize requests and show different icons
        // For now, use urgency-based icons
        switch place.urgencyLevel {
        case .low: return "hand.raised"
        case .medium: return "hand.raised.fill"
        case .high: return "exclamationmark"
        case .urgent: return "exclamationmark.triangle.fill"
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
                    // Auto-fetch when token is set
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
                        
                        // Process each request only once
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
                            
                            // Extract database status from response if available
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
    
    // Test method to verify connectivity
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
