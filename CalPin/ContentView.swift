//
//  ContentView.swift
//  CalPin
//


import SwiftUI
import GoogleSignInSwift
import GoogleSignIn
import MapKit

struct ContentView: View {
    @State private var isSignedIn = false
    @State private var showingRequestView = false
    @State private var selectedPlace: Place?
    @State private var showingProfile = false
    @State private var refreshID = UUID() // For triggering manual refreshes
    
    // UserSession to manage authentication across the app
    @StateObject private var userSession = UserSession()
    
    // Single observer for data consistency
    @StateObject private var sharedObserver = observer(token: "")
    
    // UI State
    @State private var showingHelp = false
    @State private var isLoading = false
    @State private var cardOffset: CGFloat = 300
    @State private var cardHeight: CGFloat = 300
    @State private var isDragging = false
    
    @State private var selectedCategory: AICategory? = nil
    
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
                
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                
                                Text("Signing in...")
                                    .foregroundColor(.white)
                                    .padding(.top)
                            }
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(12)
                            .shadow(radius: 10)
                        )
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .environmentObject(userSession) // Provide UserSession to all child views
        .onChange(of: userSession.token) { newToken in
            print("🔄 Token changed in ContentView")
            sharedObserver.token = newToken
            if !newToken.isEmpty {
                print("✅ New token set, triggering initial fetch...")
                sharedObserver.fetchData {
                    print("✅ Initial data loaded after sign in")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRequests"))) { _ in
            handleDataRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProfileUpdated"))) { _ in
            handleProfileUpdate()
        }
    }
    
    private var mainAppView: some View {
        let filteredPlaces = selectedCategory == nil
            ? sharedObserver.datas
            : sharedObserver.datas.filter { $0.category == selectedCategory }
        
        return ZStack {
            // Map view with filtered data AND binding to selectedCategory
            MapView(
                token: $userSession.token,
                selectedPlace: $selectedPlace,
                observer: sharedObserver,
                selectedCategory: $selectedCategory
            )
            .ignoresSafeArea(.all)
            
            // Profile button at top-left
            VStack {
                HStack {
                    Button(action: { showingProfile.toggle() }) {
                        VStack(spacing: 4) {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(berkeleyBlue)
                            
                            Text(userSession.userName.components(separatedBy: " ").first ?? "User")
                                .font(.caption2)
                                .foregroundColor(berkeleyBlue)
                        }
                        .padding(8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                
                Spacer()
            }
            
            // Add request button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // Refresh button
                        if !sharedObserver.datas.isEmpty && !sharedObserver.isLoading {
                            Button(action: {
                                handleManualRefresh()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(berkeleyBlue)
                            }
                            .frame(width: 32, height: 32)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                        }
                        
                        // Main add button
                        Button(action: {
                            print("➕ Add request button tapped")
                            showingRequestView.toggle()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .background(californiaGold)
                                .clipShape(Circle())
                                .shadow(radius: 8)
                        }
                        .scaleEffect(1.1)
                        .disabled(userSession.token.isEmpty)
                        .opacity(userSession.token.isEmpty ? 0.6 : 1.0)
                    }
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, cardOffset + 20)
            // Draggable bottom card using shared observer
            VStack {
                Spacer()
                DraggableCardView(
                    selectedPlace: $selectedPlace,
                    places: filteredPlaces,
                    offset: $cardOffset,
                    isDragging: $isDragging,
                    userToken: userSession.token // Pass the token here
                )
            }
        }
        .sheet(isPresented: $showingRequestView) {
            RequestView(
                    token: $userSession.token,
                    userEmail: userSession.userEmail,
                    onRequestCreated: {
                                handleRequestCreated()
                            }
                )
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView(
                userName: userSession.userName,
                userEmail: userSession.userEmail,
                onSignOut: handleSignOut
            )
            .environmentObject(userSession) // Pass the user session to ProfileView
        }
        .navigationBarHidden(true)
        .id(refreshID) // This will force UI updates when refreshID changes
    }
    
    private var signInView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack {
                    // Yellow background with transparency
                    LinearGradient(
                        colors: [lightGold.opacity(0.8), lightBlue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Content in hero section
                    VStack(spacing: 24) {
                        Spacer(minLength: 60)
                        
                        // App title at the top
                        VStack(spacing: 8) {
                            Text("CalPin")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(berkeleyBlue)
                            
                            Text("Connect • Help • Thrive")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        
                        // Large Oski logo below title
                        Image("oski")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 160, height: 160) // Large logo size
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.white.opacity(0.1))
                            )
                        
                        Spacer(minLength: 40)
                    }
                }
                .frame(height: UIScreen.main.bounds.height * 0.38)
                
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
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
                            .padding(.horizontal, 32)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 10)
                    .padding(.horizontal, 20)
                    .padding(.top, -20) // Overlap slightly with hero section
                
                    // Features preview
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
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
                    VStack(spacing: 16) {
                        Text("Sign in to get started:")
                            .font(.headline)
                            .foregroundColor(berkeleyBlue)
                        
                        GoogleSignInButton(action: handleSignInButton)
                            .frame(height: 50)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                        
                        Text("Use your Berkeley email to join the community")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 10)
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
                .background(Color(.systemGroupedBackground)) // Light gray background for content area
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
    
    // MARK: - Enhanced Data Management
    
    // Enhanced data refresh handler
    private func handleDataRefresh() {
        print("🔄 Data refresh triggered by user action")
        
        // Immediate refresh
        DispatchQueue.main.async {
            self.sharedObserver.fetchData {
                print("✅ Data refreshed after user action")
            }
            
            // Update the refresh ID to trigger UI updates
            self.refreshID = UUID()
        }
        
        // Delayed refresh to catch database propagation delays
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.sharedObserver.fetchData {
                print("✅ Delayed refresh completed")
            }
        }
    }
    
    // Profile update handler
    private func handleProfileUpdate() {
        print("📊 Profile update triggered")
        
        // If profile view is visible, it will automatically refresh its data
        // due to the @Published properties in UserSession
        
        // Optional: Post notification to profile view if needed
        NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
    }
    
    // Manual refresh handler
    private func handleManualRefresh() {
        print("🔄 Manual refresh triggered")
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        sharedObserver.fetchData {
            print("✅ Manual refresh completed")
        }
        
        // Update refresh ID for UI updates
        refreshID = UUID()
    }
    
    private func handleRequestCreated() {
        print("📝 Request created callback triggered")
        
        // Immediate data refresh
        DispatchQueue.main.async {
            self.sharedObserver.fetchData {
                print("✅ Data refreshed after request creation")
            }
            
            // Trigger profile refresh since user just created a request
            self.handleProfileUpdate()
            
            // Update refresh ID
            self.refreshID = UUID()
        }
        
        // Additional delayed refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.sharedObserver.fetchData {
                print("✅ Final refresh completed")
            }
        }
    }
    
    // Authentication
    
    // Enhanced sign-in handler
    func handleSignInButton() {
        print("🔐 Sign-in button tapped")
        isLoading = true
        
        guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {
            print("❌ Could not get presenting view controller")
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
                
                let user = result.user
                let userName = user.profile?.name ?? "Berkeley Student"
                let userEmail = user.profile?.email ?? ""
                let token = user.idToken?.tokenString ?? ""
                
                print("✅ Sign-in successful!")
                print("👤 User name: \(userName)")
                print("📧 User email: \(userEmail)")
                print("🔑 Token length: \(token.count)")
                
                // Check if we actually got a token
                if token.isEmpty {
                    print("🚨 WARNING: Token is empty!")
                    return
                } else {
                    print("🔑 Token received successfully")
                }
                
                // Verify Berkeley email
                if userEmail.hasSuffix("@berkeley.edu") || userEmail.hasSuffix("@student.berkeley.edu") {
                    print("✅ Berkeley email verified")
                    
                    // Update UserSession
                    userSession.token = token
                    userSession.userName = userName
                    userSession.userEmail = userEmail
                    
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isSignedIn = true
                    }
                } else {
                    print("❌ Non-Berkeley email: \(userEmail)")
                }
            }
        }
    }
    
    func handleSignOut() {
        print("👋 Sign out initiated")
        GIDSignIn.sharedInstance.signOut()
        
        // Clear UserSession
        userSession.token = ""
        userSession.userName = ""
        userSession.userEmail = ""
        
        withAnimation(.easeInOut(duration: 0.5)) {
            isSignedIn = false
            selectedPlace = nil
            sharedObserver.datas = [] // Clear observer data
            refreshID = UUID() // Reset refresh ID
        }
        print("✅ User signed out successfully")
    }
}

// Supporting Views

// Feature card component - more compact version
struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 100) 
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }
}

// User session to manage authentication state
class UserSession: ObservableObject {
    @Published var token: String = ""
    @Published var userEmail: String = ""
    @Published var userName: String = ""
    
    var isAuthenticated: Bool {
        return !token.isEmpty
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
