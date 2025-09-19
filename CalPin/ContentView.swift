//
//  ContentView.swift
//  CalPin
//
//  Enhanced main view with improved state management and user experience
//

import SwiftUI
import GoogleSignInSwift
import GoogleSignIn
import MapKit

struct ContentView: View {
    @State private var isSignedIn = false
    @State private var token = ""
    @State private var showingRequestView = false
    @State private var selectedPlace: Place?
    @State private var showingProfile = false
    @State private var userName = ""
    @State private var userEmail = ""
    
    // Shared observer for data consistency
    @StateObject private var sharedObserver = observer(token: "")
    
    // UI State
    @State private var showingHelp = false
    @State private var isLoading = false
    @State private var cardOffset: CGFloat = 300 // How far up the card is pulled
    @State private var cardHeight: CGFloat = 300 // Current card height
    @State private var isDragging = false
    
    // Color scheme
    private let berkeleyBlue = Color(red: 0/255, green: 50/255, blue: 98/255)
    private let californiaGold = Color(red: 253/255, green: 181/255, blue: 21/255)
    private let lightBlue = Color(red: 189/255, green: 229/255, blue: 242/255)
    private let lightGold = Color(red: 255/255, green: 249/255, blue: 191/255)

    var body: some View {
        NavigationView {
            ZStack {
                if isSignedIn {
                    mainAppView
                } else {
                    signInView
                }
                
                // Loading overlay
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(
                            ProgressView("Signing in...")
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(radius: 10)
                        )
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onChange(of: token) { newToken in
            // Update shared observer token when user signs in
            sharedObserver.token = newToken
            if !newToken.isEmpty {
                // Fetch initial data when user signs in
                sharedObserver.fetchData()
            }
        }
    }
    
    private var mainAppView: some View {
        ZStack {
            // Map view using shared observer
            SharedMapView(
                token: $token,
                selectedPlace: $selectedPlace,
                observer: sharedObserver
            )
            .ignoresSafeArea(.all)
            
            // Profile button at top-left
            VStack {
                HStack {
                    Button(action: { showingProfile.toggle() }) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(berkeleyBlue)
                            .padding(12)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                
                Spacer()
            }
            
            // Add request button in bottom-right
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button(action: { showingRequestView.toggle() }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .background(californiaGold)
                            .clipShape(Circle())
                            .shadow(radius: 8)
                    }
                    .scaleEffect(1.1)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, cardOffset + 20)
            
            // Draggable bottom card using shared observer
            VStack {
                Spacer()
                
                DraggableCardView(
                    selectedPlace: $selectedPlace,
                    places: sharedObserver.datas,
                    offset: $cardOffset,
                    isDragging: $isDragging
                )
            }
        }
        .sheet(isPresented: $showingRequestView) {
            RequestView(token: $token) {
                // Refresh shared observer when new request is created
                print("🔄 Request created, refreshing data...")
                sharedObserver.forceRefresh()
                
                // Also post notification for any other observers
                NotificationCenter.default.post(
                    name: NSNotification.Name("RefreshMapData"),
                    object: nil
                )
            }
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView(
                userName: userName,
                userEmail: userEmail,
                onSignOut: handleSignOut
            )
        }
        .navigationBarHidden(true)
    }
    
    private var signInView: some View {
        ScrollView {
            VStack(spacing: 30) {
                Spacer(minLength: 60)
                
                // App logo and title
                VStack(spacing: 20) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 80))
                        .foregroundColor(californiaGold)
                    
                    Text("CalPin")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(berkeleyBlue)
                    
                    Text("Connect • Help • Thrive")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                // Welcome message
                VStack(spacing: 12) {
                    Text("Welcome to UC Berkeley's")
                        .font(.title2)
                        .foregroundColor(berkeleyBlue)
                    
                    Text("Student Support Network")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(californiaGold)
                    
                    Text("Request help, offer support, and build community with fellow Bears")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.1), radius: 10)
                .padding(.horizontal, 20)
                
                // Features preview
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    FeatureCard(
                        icon: "map.circle.fill",
                        title: "Find Help Nearby",
                        description: "See requests from students around campus"
                    )
                    
                    FeatureCard(
                        icon: "hand.raised.circle.fill",
                        title: "Offer Support",
                        description: "Help fellow students when you can"
                    )
                    
                    FeatureCard(
                        icon: "clock.circle.fill",
                        title: "Real-time Updates",
                        description: "Get notified when help is available"
                    )
                    
                    FeatureCard(
                        icon: "shield.circle.fill",
                        title: "Safe & Secure",
                        description: "Berkeley-verified accounts only"
                    )
                }
                .padding(.horizontal, 20)
                
                // Sign in section
                VStack(spacing: 20) {
                    Text("Sign in to get started:")
                        .font(.headline)
                        .foregroundColor(berkeleyBlue)
                    
                    GoogleSignInButton(action: handleSignInButton)
                        .frame(height: 55)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                    
                    Text("Use your Berkeley email to join the community")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.1), radius: 10)
                .padding(.horizontal, 20)
                
                Spacer(minLength: 40)
            }
        }
        .background(
            LinearGradient(
                colors: [lightGold, lightBlue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
    
    func handleSignInButton() {
        isLoading = true
        
        guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {
            isLoading = false
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { signInResult, error in
            DispatchQueue.main.async {
                isLoading = false
                
                guard let result = signInResult, error == nil else {
                    print("❌ Sign in error: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Extract user information
                let user = result.user
                userName = user.profile?.name ?? "Berkeley Student"
                userEmail = user.profile?.email ?? ""
                token = user.idToken?.tokenString ?? ""
                
                // Verify it's a Berkeley email
                if userEmail.hasSuffix("@berkeley.edu") || userEmail.hasSuffix("@student.berkeley.edu") {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isSignedIn = true
                    }
                    print("✅ Successfully signed in: \(userName)")
                } else {
                    // Handle non-Berkeley email
                    print("⚠️ Non-Berkeley email detected: \(userEmail)")
                    // You might want to show an alert here
                }
            }
        }
    }
    
    func handleSignOut() {
        GIDSignIn.sharedInstance.signOut()
        withAnimation(.easeInOut(duration: 0.5)) {
            isSignedIn = false
            token = ""
            userName = ""
            userEmail = ""
            selectedPlace = nil
            sharedObserver.datas = [] // Clear observer data
        }
        print("👋 User signed out")
    }
}

// Shared MapView component that uses the passed observer
struct SharedMapView: View {
    @Binding var token: String
    @Binding var selectedPlace: Place?
    @ObservedObject var observer: observer
    
    @State private var isRefreshing = false
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
    
    private var allAnnotations: [Place] {
        [samplePin] + observer.datas
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(coordinateRegion: $region,
                showsUserLocation: true,
                annotationItems: allAnnotations) { place in
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
            }
            .onChange(of: token) { newToken in
                if !newToken.isEmpty {
                    refreshData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshMapData"))) { _ in
                refreshData()
            }
            
            // Map controls
            VStack(spacing: 12) {
                // Refresh button
                Button(action: refreshData) {
                    Image(systemName: "arrow.clockwise")
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
        
        observer.fetchData {
            DispatchQueue.main.async {
                self.isRefreshing = false
                print("✅ Map data refreshed, found \(self.observer.datas.count) requests")
            }
        }
    }
}

// Feature card component (same as before)
struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }
}

// Profile view and other components remain the same...
struct ProfileView: View {
    let userName: String
    let userEmail: String
    let onSignOut: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Profile header
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text(userName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(userEmail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(20)
                
                // Stats section (placeholder)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Impact")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    HStack {
                        StatCard(title: "Requests Made", value: "3", icon: "hand.raised")
                        StatCard(title: "People Helped", value: "7", icon: "heart.fill")
                    }
                }
                
                Spacer()
                
                // Sign out button
                Button(action: onSignOut) {
                    Text("Sign Out")
                        .font(.headline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.bottom)
            }
            .padding()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// Stat card component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
