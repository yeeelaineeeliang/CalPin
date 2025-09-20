//
//  ContentView.swift
//  CalPin
//
//  Clean production main view without debug elements
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
    
    // Single observer for data consistency
    @StateObject private var sharedObserver = observer(token: "")
    
    // UI State
    @State private var showingHelp = false
    @State private var isLoading = false
    @State private var cardOffset: CGFloat = 300
    @State private var cardHeight: CGFloat = 300
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
        .onChange(of: token) { newToken in
            print("🔄 Token changed in ContentView")
            sharedObserver.token = newToken
            if !newToken.isEmpty {
                print("✅ New token set, triggering initial fetch...")
                sharedObserver.fetchData {
                    print("✅ Initial data loaded after sign in")
                }
            }
        }
    }
    
    private var mainAppView: some View {
        ZStack {
            // Map view using shared observer
            MapView(token: $token, selectedPlace: $selectedPlace, observer: sharedObserver)
                .ignoresSafeArea(.all)
            
            // Profile button at top-left - cleaned up, no debug button
            VStack {
                HStack {
                    Button(action: { showingProfile.toggle() }) {
                        VStack(spacing: 4) {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(berkeleyBlue)
                            
                            Text(userName.components(separatedBy: " ").first ?? "User")
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
            
            // Add request button in bottom-right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // Data refresh indicator
                        if sharedObserver.isLoading {
                            Button(action: {}) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.8)
                                    .padding(8)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .disabled(true)
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
                        .disabled(token.isEmpty)
                        .opacity(token.isEmpty ? 0.6 : 1.0)
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
                    places: sharedObserver.datas,
                    offset: $cardOffset,
                    isDragging: $isDragging
                )
            }
        }
        .sheet(isPresented: $showingRequestView) {
            RequestView(token: $token) {
                handleRequestCreated()
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
                userName = user.profile?.name ?? "Berkeley Student"
                userEmail = user.profile?.email ?? ""
                token = user.idToken?.tokenString ?? ""
                
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
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isSignedIn = true
                    }
                } else {
                    print("❌ Non-Berkeley email: \(userEmail)")
                }
            }
        }
    }
    
    // Enhanced request creation handler
    private func handleRequestCreated() {
        print("🔄 Request created callback triggered")
        
        // Immediate refresh
        DispatchQueue.main.async {
            print("📱 Triggering immediate data refresh...")
            self.sharedObserver.fetchData {
                print("✅ Data refreshed after request creation")
                print("📊 New data count: \(self.sharedObserver.datas.count)")
            }
        }
        
        // Also schedule a delayed refresh to catch any database delays
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🔄 Triggering delayed refresh...")
            self.sharedObserver.fetchData {
                print("✅ Delayed refresh completed")
                print("📊 Final data count: \(self.sharedObserver.datas.count)")
            }
        }
    }
    
    func handleSignOut() {
        print("👋 Sign out initiated")
        GIDSignIn.sharedInstance.signOut()
        withAnimation(.easeInOut(duration: 0.5)) {
            isSignedIn = false
            token = ""
            userName = ""
            userEmail = ""
            selectedPlace = nil
            sharedObserver.datas = [] // Clear observer data
        }
        print("✅ User signed out successfully")
    }
}

// Feature card component
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

// Enhanced Profile view with better stats
struct ProfileView: View {
    let userName: String
    let userEmail: String
    let onSignOut: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    private let berkeleyBlue = Color(red: 0/255, green: 50/255, blue: 98/255)
    private let californiaGold = Color(red: 253/255, green: 181/255, blue: 21/255)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile header
                    VStack(spacing: 16) {
                        // Avatar
                        Circle()
                            .fill(berkeleyBlue.opacity(0.1))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(String(userName.prefix(1)).uppercased())
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(berkeleyBlue)
                            )
                        
                        VStack(spacing: 4) {
                            Text(userName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(berkeleyBlue)
                            
                            Text(userEmail)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            // Berkeley verification badge
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text("Berkeley Verified")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 8)
                    
                    // Stats section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(californiaGold)
                            Text("Your Impact")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(berkeleyBlue)
                        }
                        
                        HStack(spacing: 16) {
                            StatCard(
                                title: "Requests Made",
                                value: "3",
                                icon: "hand.raised.fill",
                                color: .blue
                            )
                            
                            StatCard(
                                title: "People Helped",
                                value: "7",
                                icon: "heart.fill",
                                color: .red
                            )
                        }
                        
                        HStack(spacing: 16) {
                            StatCard(
                                title: "Community Points",
                                value: "42",
                                icon: "star.fill",
                                color: californiaGold
                            )
                            
                            StatCard(
                                title: "This Week",
                                value: "2",
                                icon: "calendar",
                                color: .green
                            )
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 8)
                    
                    // Settings section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(berkeleyBlue)
                            Text("Settings")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(berkeleyBlue)
                        }
                        
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "bell.fill",
                                title: "Notifications",
                                subtitle: "Manage your alert preferences"
                            )
                            
                            Divider()
                                .padding(.leading, 40)
                            
                            SettingsRow(
                                icon: "location.fill",
                                title: "Privacy",
                                subtitle: "Control your location sharing"
                            )
                            
                            Divider()
                                .padding(.leading, 40)
                            
                            SettingsRow(
                                icon: "questionmark.circle.fill",
                                title: "Help & Support",
                                subtitle: "Get help or report issues"
                            )
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 8)
                    
                    Spacer(minLength: 20)
                    
                    // Sign out button
                    Button(action: onSignOut) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text("Sign Out")
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                        .shadow(color: .red.opacity(0.3), radius: 8, y: 4)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
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

// Enhanced stat card component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
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

// Settings row component
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .contentShape(Rectangle())
        .onTapGesture {
            // Handle settings tap
            print("Settings tapped: \(title)")
        }
    }
}

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
