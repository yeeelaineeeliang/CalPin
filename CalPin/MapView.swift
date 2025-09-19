//
//  MapView.swift
//  CalPin
//
//  Enhanced map view with improved pin visualization and interactions
//

import SwiftUI
import MapKit
import Alamofire
import SwiftyJSON

func createPlace(from json: [String: Any]) -> Place? {
    guard
        let title = json["title"] as? String,
        let latitude = json["latitude"] as? Double,
        let longitude = json["longitude"] as? Double,
        let description = json["description"] as? String,
        let contact = json["contact"] as? String
    else {
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
    @StateObject private var requestObserver: observer // Changed to @StateObject
    @State private var annotations: [Place]
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.87271049717549, longitude: -122.26090632933469),
        latitudinalMeters: 3000,
        longitudinalMeters: 3000
    )
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var showingLocationAlert = false
    
    private let locationManager = CLLocationManager()
    
    // Sample pin for demo purposes
    let samplePin = Place(
        title: "Need Study Buddy for Finals",
        coordinate: CLLocationCoordinate2D(latitude: 37.87271049717549, longitude: -122.26090632933469),
        description: "Looking for someone to study with for upcoming finals. I have reserved a study room at the library.",
        contact: "study@berkeley.edu",
        distance: "0.0mi",
        duration: "0min",
        urgencyLevel: .medium,
        status: .open,
        createdAt: Date().addingTimeInterval(-1800), // 30 minutes ago
        authorName: "Demo User",
        helpersCount: 1
    )

    init(token: Binding<String>, selectedPlace: Binding<Place?>) {
        self._token = token
        self._selectedPlace = selectedPlace
        self._requestObserver = StateObject(wrappedValue: observer(token: token.wrappedValue))
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
                requestObserver.token = token // Update token
                refreshData()
            }
            .onChange(of: token) { newToken in
                // Update observer token when user signs in/out
                requestObserver.token = newToken
                if !newToken.isEmpty {
                    refreshData()
                }
            }
            .onReceive(requestObserver.$datas) { newData in
                // Update annotations when data changes
                updateAnnotations()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshMapData"))) { _ in
                // Listen for refresh notifications from request creation
                refreshData()
            }
            
            // Map controls - 3 buttons (refresh, location, filter)
            VStack(spacing: 12) {
                // Refresh button
                Button(action: refreshData) {
                    Image(systemName: isRefreshing ? "arrow.clockwise" : "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                        .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .disabled(isRefreshing)
                
                // Center on user location button
                Button(action: centerOnUserLocation) {
                    Image(systemName: "location.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                
                // Filter button
                Button(action: {
                    // TODO: Implement filter options
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
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
    
    private func refreshData() {
        guard !token.isEmpty else {
            print("⚠️ No token available for refresh")
            return
        }
        
        isRefreshing = true
        selectedPlace = nil
        
        print("🔄 Refreshing map data...")
        
        requestObserver.fetchData {
            DispatchQueue.main.async {
                self.isRefreshing = false
                self.updateAnnotations()
                print("✅ Map data refreshed, found \(self.requestObserver.datas.count) requests")
            }
        }
    }
    
    private func updateAnnotations() {
        // Always include sample pin for demo + fetched data
        let allPlaces = [samplePin] + requestObserver.datas
        
        // Only update if annotations actually changed to prevent unnecessary re-renders
        if !areAnnotationsEqual(annotations, allPlaces) {
            withAnimation(.easeInOut(duration: 0.3)) {
                annotations = allPlaces
            }
            print("📍 Updated map with \(allPlaces.count) pins")
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

// Enhanced observer class with better state management
class observer: ObservableObject {
    @Published var datas = [Place]()
    @Published var isLoading = false
    @Published var lastRefresh: Date?
    @Published var errorMessage: String?
    
    var token: String {
        didSet {
            if token != oldValue {
                print("🔑 Observer token updated")
            }
        }
    }
    
    init(token: String) {
        self.token = token
    }

    func fetchData(completion: @escaping () -> Void = {}) {
        guard !token.isEmpty else {
            print("⚠️ Cannot fetch data: No token provided")
            completion()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        print("🌐 Fetching data from server...")
        
        AF.request(
            "https://web-production-aaea1.up.railway.app/api/fetch",
            method: .get,
            headers: headers
        )
        .validate()
        .responseJSON { [weak self] response in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    var newRequests: [Place] = []
                    
                    // Handle both array and object responses
                    if json.type == .array {
                        for subJson in json.arrayValue {
                            if let placeData = subJson.dictionaryObject,
                               let place = createPlace(from: placeData) {
                                newRequests.append(place)
                            }
                        }
                    } else {
                        for (_, subJson): (String, JSON) in json {
                            if let placeData = subJson.dictionaryObject,
                               let place = createPlace(from: placeData) {
                                newRequests.append(place)
                            }
                        }
                    }
                    
                    self?.datas = newRequests
                    self?.lastRefresh = Date()
                    self?.errorMessage = nil
                    
                    print("✅ Successfully fetched \(newRequests.count) requests")
                    completion()
                    
                case .failure(let error):
                    let errorMsg = "Failed to fetch requests: \(error.localizedDescription)"
                    self?.errorMessage = errorMsg
                    print("❌ Error fetching data: \(errorMsg)")
                    
                    // Keep existing data on error
                    completion()
                }
            }
        }
    }
    
    // Add method to force refresh
    func forceRefresh() {
        print("🔄 Force refreshing data...")
        fetchData()
    }
}

// Preview
struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(
            token: .constant("sample_token"),
            selectedPlace: .constant(nil)
        )
    }
}
