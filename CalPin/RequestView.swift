//
//  RequestView.swift
//  CalPin
//

import SwiftUI
import CoreLocation
import MapKit
import Alamofire
import SwiftyJSON
import Foundation

struct PostDataPayload: Encodable {
    var caption: String
    var description: String
    var address: String
    var contact: String
    var urgencyLevel: String
    var latitude: Double?
    var longitude: Double?
}

struct RequestView: View {
    @ObservedObject var post_obs: post_observer
    @Binding private var token: String
    let onRequestCreated: () -> Void
    
    @State private var caption: String = ""
    @State private var description: String = ""
    @State private var address: String = ""
    
    @State private var contactEmail: String = ""
    @State private var contactPhone: String = ""
    @State private var includePhone: Bool = false
    
    @State private var selectedUrgency: UrgencyLevel = .medium
    @State private var isGettingLocation: Bool = false
    @State private var currentLocation: CLLocationCoordinate2D?
    @State private var showingSuccess = false
    @State private var showingLocationPicker = false
    
    private let locationManager = CLLocationManager()
    @Environment(\.presentationMode) var presentationMode
    
    // Color scheme
    private let berkeleyBlue = Color(red: 0/255, green: 50/255, blue: 98/255)
    private let californiaGold = Color(red: 253/255, green: 181/255, blue: 21/255)
    private let lightBlue = Color(red: 189/255, green: 229/255, blue: 242/255)
    
    init(token: Binding<String>,
         userEmail: String = "",
         onRequestCreated: @escaping () -> Void = {}) {
        _token = token
        self.onRequestCreated = onRequestCreated
        post_obs = post_observer(token: self._token.wrappedValue)
        _contactEmail = State(initialValue: userEmail)
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerView
                        
                        // Form content
                        formContent
                        
                        // Submit button
                        submitButton
                    }
                    .padding()
                }
            }
            .background(lightBlue.opacity(0.3).ignoresSafeArea())
            .navigationTitle("New Request")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(berkeleyBlue)
                }
            }
        }
        .alert("Request Submitted!", isPresented: $showingSuccess) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Your help request has been posted and nearby students will be notified.")
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(
                selectedLocation: $currentLocation,
                selectedAddress: $address
            )
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40))
                .foregroundColor(californiaGold)
            
            Text("Request Help")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(berkeleyBlue)
            
            Text("Connect with fellow Berkeley students who can help")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
    
    private var formContent: some View {
        VStack(spacing: 20) {
            // Title field
            VStack(alignment: .leading, spacing: 8) {
                Label("Request Title", systemImage: "text.cursor")
                    .font(.headline)
                    .foregroundColor(berkeleyBlue)
                
                TextField("e.g., Need help with calculus homework", text: $caption)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            // Description field
            VStack(alignment: .leading, spacing: 8) {
                Label("Description", systemImage: "text.alignleft")
                    .font(.headline)
                    .foregroundColor(berkeleyBlue)
                
                ZStack(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("Provide more details about what kind of help you need...")
                            .foregroundColor(.gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
            // Urgency level picker
            VStack(alignment: .leading, spacing: 8) {
                Label("Urgency Level", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundColor(berkeleyBlue)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(UrgencyLevel.allCases, id: \.self) { urgency in
                        UrgencyOptionView(
                            urgency: urgency,
                            isSelected: selectedUrgency == urgency
                        ) {
                            selectedUrgency = urgency
                        }
                    }
                }
            }
            
            // Location field with enhanced picker
            VStack(alignment: .leading, spacing: 8) {
                Label("Location", systemImage: "location")
                    .font(.headline)
                    .foregroundColor(berkeleyBlue)
                
                VStack(spacing: 12) {
                    // Address display/input
                    HStack {
                        TextField("Enter address or select on map", text: $address)
                            .textFieldStyle(CustomTextFieldStyle())
                        
                        Button(action: getCurrentLocation) {
                            Image(systemName: isGettingLocation ? "location.circle" : "location.circle.fill")
                                .foregroundColor(isGettingLocation ? .gray : berkeleyBlue)
                                .font(.title2)
                                .rotationEffect(isGettingLocation ? .degrees(360) : .degrees(0))
                                .animation(isGettingLocation ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isGettingLocation)
                        }
                        .disabled(isGettingLocation)
                    }
                    
                    // Map picker button
                    Button(action: {
                        showingLocationPicker = true
                    }) {
                        HStack {
                            Image(systemName: "map")
                            Text("Select on Map")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(berkeleyBlue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(berkeleyBlue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            
            // Contact field
            contactSection
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
    
    private var submitButton: some View {
        Button(action: submitRequest) {
            HStack {
                if post_obs.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Submit Request")
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isFormValid ? californiaGold : Color.gray)
            .cornerRadius(12)
            .shadow(color: isFormValid ? californiaGold.opacity(0.3) : .clear, radius: 8, y: 4)
        }
        .disabled(!isFormValid || post_obs.isLoading)
        .padding(.horizontal)
    }
    private func formatPhoneNumber(_ number: String) -> String {
        let cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let limited = String(cleaned.prefix(10))
        
        var formatted = ""
        for (index, character) in limited.enumerated() {
            if index == 0 {
                formatted += "("
            } else if index == 3 {
                formatted += ") "
            } else if index == 6 {
                formatted += "-"
            }
            formatted.append(character)
        }
        
        return formatted
    }

    // Combine email and phone for submission
    private var finalContactInfo: String {
        if includePhone && !contactPhone.isEmpty {
            return "\(contactEmail) | \(contactPhone)"
        } else {
            return contactEmail
        }
    }
    
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with security icon
            HStack {
                Label("Contact Information", systemImage: "person.text.rectangle")
                    .font(.headline)
                    .foregroundColor(berkeleyBlue)
                
                Spacer()
                
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
            // Email field (pre-filled, disabled)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(berkeleyBlue)
                        .font(.caption)
                    Text("Email")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("(Required)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                TextField("Your Berkeley email", text: $contactEmail)
                    .textFieldStyle(CustomTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disabled(true)  // Locked
                    .foregroundColor(.primary)
                    .opacity(0.8)  // Slightly dimmed to show it's locked
            }
            
            // Phone number toggle
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $includePhone.animation(.spring())) {
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(berkeleyBlue)
                            .font(.caption)
                        Text("Phone Number")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("(Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(berkeleyBlue)
                
                // Phone field (conditionally shown)
                if includePhone {
                    TextField("(123) 456-7890", text: $contactPhone)
                        .textFieldStyle(CustomTextFieldStyle())
                        .keyboardType(.phonePad)
                        .onChange(of: contactPhone) { newValue in
                            contactPhone = formatPhoneNumber(newValue)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            
            // Privacy note
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text("Your contact info will only be visible to students who want to help.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
    
    private var isFormValid: Bool {
        !caption.isEmpty &&
        !description.isEmpty &&
        !address.isEmpty &&
        !contactEmail.isEmpty &&
        contactEmail.contains("@") &&
        contactEmail.contains(".") &&
        currentLocation != nil
    }
    
    private func getCurrentLocation() {
        isGettingLocation = true
        
        // Check if location services are available
        guard CLLocationManager.locationServicesEnabled() else {
            print("❌ Location services not enabled")
            isGettingLocation = false
            return
        }
        
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
        
        // Check authorization status
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Get location
            if let location = manager.location {
                currentLocation = location.coordinate
                print("✅ Got location: \(location.coordinate)")
                
                // Reverse geocode to get readable address
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    DispatchQueue.main.async {
                        if let placemark = placemarks?.first {
                            let addressComponents = [
                                placemark.subThoroughfare,
                                placemark.thoroughfare,
                                placemark.locality,
                                placemark.administrativeArea
                            ].compactMap { $0 }
                            
                            self.address = addressComponents.isEmpty ? "Current Location" : addressComponents.joined(separator: ", ")
                        } else {
                            self.address = "Current Location"
                        }
                        self.isGettingLocation = false
                    }
                }
            } else {
                print("❌ Could not get current location")
                self.address = "Current Location"
                // Set a default Berkeley location for testing
                self.currentLocation = CLLocationCoordinate2D(latitude: 37.8719, longitude: -122.2585)
                self.isGettingLocation = false
            }
            
        case .denied, .restricted:
            print("❌ Location access denied")
            // Set a default Berkeley location
            self.address = "UC Berkeley Campus"
            self.currentLocation = CLLocationCoordinate2D(latitude: 37.8719, longitude: -122.2585)
            self.isGettingLocation = false
            
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // Set a default Berkeley location for now
            self.address = "UC Berkeley Campus"
            self.currentLocation = CLLocationCoordinate2D(latitude: 37.8719, longitude: -122.2585)
            self.isGettingLocation = false
            
        @unknown default:
            self.isGettingLocation = false
        }
    }
    
    private func submitRequest() {
        // If we don't have coordinates, use a default Berkeley location
        let finalCoordinates = currentLocation ?? CLLocationCoordinate2D(latitude: 37.8719, longitude: -122.2585)
        
        let payload = PostDataPayload(
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            contact: finalContactInfo, 
            urgencyLevel: selectedUrgency.rawValue,
            latitude: finalCoordinates.latitude,
            longitude: finalCoordinates.longitude
        )
        
        print("📍 Debug - Final coordinates: \(finalCoordinates)")
        
        post_obs.post(payload: payload) {
            DispatchQueue.main.async {
                showingSuccess = true
                onRequestCreated()
            }
        }
    }
}

// Location Picker View (Simplified version)
struct LocationPickerView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var selectedAddress: String
    @Environment(\.presentationMode) var presentationMode
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.8719, longitude: -122.2585),
        latitudinalMeters: 2000,
        longitudinalMeters: 2000
    )
    @State private var isGeocodingAddress = false
    @State private var addressPreview = "Tap and drag to select location"
    
    private let berkeleyBlue = Color(red: 0/255, green: 50/255, blue: 98/255)
    private let californiaGold = Color(red: 253/255, green: 181/255, blue: 21/255)
    
    var body: some View {
        NavigationView {
            ZStack {
                // Map with center pin
                Map(coordinateRegion: $region)
                    .ignoresSafeArea()
                
                // Center pin indicator
                VStack {
                    Spacer()
                    
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(californiaGold)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 20, height: 20)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Spacer()
                    
                    // Address preview card
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: isGeocodingAddress ? "location.circle" : "location.circle.fill")
                                    .foregroundColor(berkeleyBlue)
                                
                                Text("Selected Location")
                                    .font(.headline)
                                    .foregroundColor(berkeleyBlue)
                                
                                Spacer()
                            }
                            
                            Text(addressPreview)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(2)
                        }
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            Button("Cancel") {
                                presentationMode.wrappedValue.dismiss()
                            }
                            .font(.subheadline)
                            .foregroundColor(berkeleyBlue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(berkeleyBlue, lineWidth: 1)
                            )
                            
                            Button("Confirm Location") {
                                selectedLocation = region.center
                                selectedAddress = addressPreview == "Tap and drag to select location" ? "Selected Location" : addressPreview
                                updateAddressForLocation(region.center)
                                presentationMode.wrappedValue.dismiss()
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(californiaGold)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 10)
                    .padding()
                }
                
                // Current location button
                VStack {
                    HStack {
                        Spacer()
                        
                        Button(action: centerOnCurrentLocation) {
                            Image(systemName: "location.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(berkeleyBlue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 100)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
        .onAppear {
            // Set initial location if available
            if let existingLocation = selectedLocation {
                region.center = existingLocation
                updateAddressForLocation(existingLocation)
            }
        }
    }
    
    private func centerOnCurrentLocation() {
        let locationManager = CLLocationManager()
        
        guard CLLocationManager.locationServicesEnabled() else { return }
        
        if let location = locationManager.location {
            withAnimation(.easeInOut(duration: 1.0)) {
                region.center = location.coordinate
            }
            updateAddressForLocation(location.coordinate)
        }
    }
    
    private func updateAddressForLocation(_ coordinate: CLLocationCoordinate2D) {
        isGeocodingAddress = true
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                isGeocodingAddress = false
                
                if let placemark = placemarks?.first {
                    let addressComponents = [
                        placemark.subThoroughfare,
                        placemark.thoroughfare,
                        placemark.locality,
                        placemark.administrativeArea
                    ].compactMap { $0 }
                    
                    addressPreview = addressComponents.isEmpty ? "Unknown Location" : addressComponents.joined(separator: ", ")
                } else {
                    addressPreview = "Unknown Location"
                }
            }
        }
    }
}

// Custom text field style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

// Urgency option view
struct UrgencyOptionView: View {
    let urgency: UrgencyLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(urgency.color.opacity(isSelected ? 0.3 : 0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(urgency.color.opacity(isSelected ? 0.6 : 0.3), lineWidth: 2)
                        )
                    
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(urgency.color)
                }
                
                VStack(spacing: 4) {
                    Text(urgency.rawValue)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(.primary)
                    
                    // Show time expectation to help users choose
                    Text(urgency.timeExpectation)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? urgency.color : Color.gray.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .shadow(
                color: isSelected ? urgency.color.opacity(0.2) : .clear,
                radius: isSelected ? 8 : 0,
                y: isSelected ? 4 : 0
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// Enhanced post observer with better error handling and debugging
class post_observer: ObservableObject {
    @Published var isLoading = false
    @Published var lastError: String?
    var token: String
    
    init(token: String) {
        self.token = token
    }

    func post(payload: PostDataPayload, completion: @escaping () -> Void) {
        isLoading = true
        
        print("🔍 Debug - Token: \(token)")
        print("🔍 Debug - Payload: \(payload)")
        print("🔍 Debug - Posting to: \(NetworkConfig.baseURL)\(NetworkConfig.endpoints.create)")
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]

        // ✅ Using NetworkConfig instead of APIConfig
        AF.request(
            "\(NetworkConfig.baseURL)\(NetworkConfig.endpoints.create)",
            method: .post,
            parameters: payload,
            encoder: JSONParameterEncoder.default,
            headers: headers
        )
        .validate()
        .responseData { [weak self] response in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                print("🔍 Debug - Response status: \(response.response?.statusCode ?? 0)")
                
                switch response.result {
                case .success(let data):
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("✅ Success response: \(responseString)")
                    }
                    completion()
                case .failure(let error):
                    print("❌ Error: \(error)")
                    print("❌ Error description: \(error.localizedDescription)")
                    if let data = response.data, let errorString = String(data: data, encoding: .utf8) {
                        print("❌ Server error: \(errorString)")
                    }
                    completion()
                }
            }
        }
    }
    
    // Test method to verify connectivity
    func testConnection() {
        let testURL = "https://calpin-production.up.railway.app/health"
        
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
struct RequestView_Previews: PreviewProvider {
    static var previews: some View {
        RequestView(token: .constant("sample_token"))
    }
}
