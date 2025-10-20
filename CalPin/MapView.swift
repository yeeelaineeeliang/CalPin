//
//  MapView.swift
//  CalPin
//

import SwiftUI
import MapKit
import Alamofire
import SwiftyJSON
import Foundation
import CoreLocation

// Location Manager for iPhone Maps-like behavior
class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    private var locationCompletion: ((Result<CLLocationCoordinate2D, Error>) -> Void)?
    private var hasRequestedLocation = false
    
    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
    }
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("Location access denied")
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        @unknown default:
            break
        }
    }
    
    func requestCurrentLocation(completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        self.locationCompletion = completion
        
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            completion(.failure(CLError(.denied)))
            return
        }
        
        // Request a one-time location update
        locationManager.requestLocation()
    }
    
    private func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        
        locationManager.startUpdatingLocation()
    }
    
    private func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
}

// CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        print("📍 Location updated: \(location.coordinate)")
        
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
        }
        
        // If we have a completion handler (from requestCurrentLocation), call it
        if let completion = locationCompletion {
            completion(.success(location.coordinate))
            locationCompletion = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager failed with error: \(error.localizedDescription)")
        
        if let completion = locationCompletion {
            completion(.failure(error))
            locationCompletion = nil
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("📍 Location authorization changed to: \(manager.authorizationStatus.rawValue)")
        
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            stopLocationUpdates()
            userLocation = nil
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}

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
        print("JSON: \(json)")
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
    @State private var isLocating = false // Track if we're currently getting location
    @State private var selectedCategory: AICategory? = nil
    @State private var showCategoryFilter = true
    
    @StateObject private var locationManager = LocationManager()
    

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
                setupNotificationObservers()
            }
            .onDisappear {
                removeNotificationObservers()
            }
            .onChange(of: token) { newToken in
                print("🔄 Token changed, refreshing data...")
                if !newToken.isEmpty {
                    refreshData()
                }
            }
            .onChange(of: locationManager.userLocation) { newLocation in
                if let location = newLocation {
                    userLocation = location
                }
            }
            
            // NEW: Category Filter Bar (top of screen)
            VStack(spacing: 0) {
                if showCategoryFilter {
                    CategoryFilterView(
                        selectedCategory: $selectedCategory,
                        userToken: token
                    )
                    .background(
                        Color(.systemBackground)
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            
            VStack {
                HStack {
                    Spacer()
                        
                    VStack(spacing: 12) {
                        // NEW: Toggle category filter button
                        Button(action: {
                            withAnimation(.spring()) {
                                showCategoryFilter.toggle()
                            }
                        }) {
                            Image(systemName: showCategoryFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.title2)
                                .foregroundColor(Color(red: 0/255, green: 50/255, blue: 98/255))
                                .padding(12)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                            
                            // Location button
                            Button(action: {
                                centerOnUserLocation()
                            }) {
                                Image(systemName: locationButtonIcon)
                                    .font(.title2)
                                    .foregroundColor(Color(red: 0/255, green: 50/255, blue: 98/255))
                                    .padding(12)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                            .disabled(isLocating)
                        }
                        .padding(.trailing, 16)
                        .padding(.top, showCategoryFilter ? 120 : 60)
                    }
                    
                    Spacer()
                }
            }
            .onAppear {
                updateAnnotations()
                // Set up notification observer for refresh
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("RefreshRequests"),
                    object: nil,
                    queue: .main
                ) { _ in
                    self.refreshData()
                }
            }
            .alert("Location Access Required", isPresented: $showingLocationAlert) {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable location access in Settings to see nearby help requests.")
            }
        }
    private var locationButtonIcon: String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "location"
        case .denied, .restricted:
            return "location.slash"
        case .authorizedWhenInUse, .authorizedAlways:
            if userLocation != nil {
                return "location.fill"
            } else {
                return "location"
            }
        @unknown default:
            return "location"
        }
    }

    
    // Setup notification observers for refresh triggers from ContentView
    private func setupNotificationObservers() {
        // Listen for refresh requests from ContentView or other components
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshRequests"),
            object: nil,
            queue: .main
        ) { _ in
            print("📍 MapView: Refresh requested via notification")
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
                print("📍 MapView: App became active, refreshing data")
                self.refreshData()
            }
        }
    }
    
    // Remove notification observers
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RefreshRequests"), object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    private func setupLocationServices() {
        // The LocationManager will handle requesting permissions
        locationManager.requestLocationPermission()
    }
    
    // location centering
    private func centerOnUserLocation() {
        print("📍 Location button tapped")
        
        // Check current authorization status
        switch locationManager.authorizationStatus {
        case .notDetermined:
            // Request permission first
            locationManager.requestLocationPermission()
            return
            
        case .denied, .restricted:
            // Show settings alert
            showingLocationAlert = true
            return
            
        case .authorizedWhenInUse, .authorizedAlways:
            // We have permission, get current location
            break
            
        @unknown default:
            print("⚠️ Unknown location authorization status")
            return
        }
        
        // Start location acquisition with loading state
        isLocating = true
        
        locationManager.requestCurrentLocation { [self] result in
            DispatchQueue.main.async {
                self.isLocating = false
                
                switch result {
                case .success(let location):
                    print("✅ Got current location: \(location)")
                    
                    // Update stored user location
                    self.userLocation = location
                    
                    // Animate to user location like iPhone Maps
                    withAnimation(.easeInOut(duration: 1.2)) {
                        self.region = MKCoordinateRegion(
                            center: location,
                            latitudinalMeters: 1500,  // Closer zoom like Maps app
                            longitudinalMeters: 1500
                        )
                    }
                    
                    // Optional: Add haptic feedback like Maps app
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                case .failure(let error):
                    print("❌ Failed to get current location: \(error.localizedDescription)")
                    
                    // Show appropriate error message
                    switch error {
                    case is CLError:
                        if let clError = error as? CLError {
                            switch clError.code {
                            case .locationUnknown:
                                // Location service was unable to determine location
                                print("⚠️ Location unknown - GPS might be having issues")
                            case .denied:
                                // Permission denied
                                self.showingLocationAlert = true
                            default:
                                print("⚠️ Location error: \(clError.localizedDescription)")
                            }
                        }
                    default:
                        print("⚠️ Unknown location error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    
    // Only called by notifications, no manual button
    private func refreshData() {
        guard !token.isEmpty else {
            print("⚠️ Cannot refresh - no token available")
            return
        }
        
        selectedPlace = nil
        lastRefreshTime = Date()
        
        print("📍 MapView: Refreshing data...")
        
        obs.fetchData {
            DispatchQueue.main.async {
                self.updateAnnotations()
                print("📍 MapView: Refresh completed - \(self.annotations.count) total pins")
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

// Enhanced pin view with proper status handling
struct EnhancedPinView: View {
    let place: Place
    let isSelected: Bool
    
    private var urgencyColor: Color {
        place.urgencyLevel.color
    }
    
    // Status-aware pin color with exhaustive switch
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
                
                // Status indicators with proper VStack structure
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
    
    // Separate status indicator overlay to avoid VStack issues
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
    
    // Separate selected pin label to avoid VStack issues
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
    
    // Helper functions with exhaustive switches
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
