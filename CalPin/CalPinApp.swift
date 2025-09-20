//
//  CalPinApp.swift
//  CalPin
//
//  Final Google Sign-In configuration using GoogleService-Info.plist
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

@main
struct CalPinApp: App {
    
    init() {
        // Configure Google Sign-In using GoogleService-Info.plist
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            fatalError("GoogleService-Info.plist file not found or CLIENT_ID missing")
        }
        
        print("✅ Configuring Google Sign-In with client ID from plist: \(clientId)")
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        
        // Optional: Print the reversed client ID for URL scheme verification
        if let reversedClientId = plist["REVERSED_CLIENT_ID"] as? String {
            print("🔗 URL Scheme should be: \(reversedClientId)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    print("📱 Received URL: \(url)")
                    let handled = GIDSignIn.sharedInstance.handle(url)
                    print("🔄 URL handled by Google Sign-In: \(handled)")
                }
                .onAppear {
                    // Check if user is already signed in
                    if let user = GIDSignIn.sharedInstance.currentUser {
                        print("👤 User already signed in: \(user.profile?.email ?? "Unknown")")
                    } else {
                        print("👤 No user currently signed in")
                    }
                }
        }
    }
}
