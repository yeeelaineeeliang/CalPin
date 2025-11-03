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
    var title: String
    var description: String
    var latitude: Double
    var longitude: Double
    var contact: String
    var urgencyLevel: String
}

struct RequestView: View {
    @Binding var token: String
    let userEmail: String
    let onRequestCreated: () -> Void
    
    @State private var caption: String = ""
    @State private var description: String = ""
    @State private var contactEmail: String = ""
    @State private var contactPhone: String = ""
    @State private var includePhone: Bool = false
    @State private var selectedUrgency: UrgencyLevel = .medium
    @State private var isGettingLocation: Bool = false
    @State private var currentLocation: CLLocationCoordinate2D?
    @State private var showingSuccess = false
    @State private var showingLocationPicker = false
    @State private var isRephrasing = false
    @State private var showRephraseSuccess = false
    @State private var originalDescription = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showAlert = false
    
    @Environment(\.presentationMode) var presentationMode
    
    private let berkeleyBlue = Color(red: 0/255, green: 50/255, blue: 98/255)
    private let californiaGold = Color(red: 253/255, green: 181/255, blue: 21/255)
    private let lightBlue = Color(red: 189/255, green: 229/255, blue: 242/255)
    
    init(token: Binding<String>,
         userEmail: String = "",
         onRequestCreated: @escaping () -> Void = {}) {
        _token = token
        self.userEmail = userEmail
        self.onRequestCreated = onRequestCreated
        _contactEmail = State(initialValue: userEmail)
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                        headerView
                        formContent
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
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred")
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
                selectedLocation: $currentLocation
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
            titleField
            descriptionField
            urgencyPicker
            contactField
            locationPicker
        }
    }
    
    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title *")
                .font(.headline)
                .foregroundColor(berkeleyBlue)
            
            TextField("What do you need help with?", text: $caption)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description *")
                .font(.headline)
                .foregroundColor(berkeleyBlue)
            
            ZStack(alignment: .topLeading) {
                if description.isEmpty {
                    Text("Describe what you need help with...")
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }
                
                TextEditor(text: $description)
                    .frame(height: 120)
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            if !description.isEmpty && description.count > 20 {
                HStack {
                    if !originalDescription.isEmpty && originalDescription != description {
                        Button(action: undoRephrase) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Undo")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: rephraseDescription) {
                        HStack(spacing: 6) {
                            if isRephrasing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "wand.and.stars")
                            }
                            Text(isRephrasing ? "Rephrasing..." : "Improve with AI")
                                .font(.subheadline)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(californiaGold)
                        .cornerRadius(20)
                    }
                    .disabled(isRephrasing)
                }
                .padding(.top, 4)
            }
            
            if showRephraseSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Description improved!")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
            }
            
            Text("\(description.count)/500 characters")
                .font(.caption)
                .foregroundColor(description.count > 500 ? .red : .gray)
        }
        .padding(.horizontal)
    }
    
    private var urgencyPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Urgency Level *")
                .font(.headline)
                .foregroundColor(berkeleyBlue)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(UrgencyLevel.allCases, id: \.self) { urgency in
                    UrgencyOptionView(
                        urgency: urgency,
                        isSelected: selectedUrgency == urgency,
                        action: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedUrgency = urgency
                            }
                        }
                    )
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var contactField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contact Information *")
                .font(.headline)
                .foregroundColor(berkeleyBlue)
            
            TextField("Email", text: $contactEmail)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            Toggle(isOn: $includePhone) {
                Text("Include phone number (optional)")
                    .font(.subheadline)
            }
            .tint(berkeleyBlue)
            
            if includePhone {
                TextField("Phone Number", text: $contactPhone)
                    .keyboardType(.phonePad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal)
    }
    
    private var locationPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location *")
                .font(.headline)
                .foregroundColor(berkeleyBlue)
            
            Button(action: {
                showingLocationPicker = true
            }) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(berkeleyBlue)
                    
                    if let location = currentLocation {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Location Selected")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Select Location on Map")
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            
            if isGettingLocation {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Getting your location...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var submitButton: some View {
        Button(action: {
            print("Submit button tapped")
            print("Form valid:", isFormValid)
            print("Caption:", caption)
            print("Description:", description)
            print("Contact:", contactEmail)
            print("Location:", currentLocation as Any)
            
            submitRequest()
        }) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                Text(isSubmitting ? "Creating..." : "Post Request")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isFormValid ? berkeleyBlue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: isFormValid ? berkeleyBlue.opacity(0.3) : .clear, radius: 8, y: 4)
        }
        .disabled(!isFormValid || isSubmitting)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var isFormValid: Bool {
        return !caption.isEmpty &&
               !description.isEmpty &&
               !contactEmail.isEmpty &&
//               currentLocation != nil &&
               description.count <= 500
    }
    
    private func rephraseDescription() {
        guard !description.isEmpty else { return }
        
        isRephrasing = true
        showRephraseSuccess = false
        originalDescription = description
        
        let url = URL(string: "\(NetworkConfig.baseURL)/api/rephrase")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "title": caption,
            "description": description
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isRephrasing = false
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let improvedDesc = json["improvedDescription"] as? String else {
                    return
                }
                
                withAnimation {
                    description = improvedDesc
                    showRephraseSuccess = true
                }
                
                if let improvedTitle = json["improvedTitle"] as? String,
                   improvedTitle.count > caption.count {
                    caption = improvedTitle
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showRephraseSuccess = false
                    }
                }
            }
        }.resume()
    }
    
    private func undoRephrase() {
        withAnimation {
            description = originalDescription
            originalDescription = ""
        }
    }
    
    private func submitRequest() {
        print("submitRequest() called")
        
        guard isFormValid else {
            print("Form invalid, aborting")
            return
        }
        
        print("Creating URL request...")
        
        isSubmitting = true
        errorMessage = nil
        
        let url = URL(string: "\(NetworkConfig.baseURL)/api/create")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var contactInfo = contactEmail
        if includePhone && !contactPhone.isEmpty {
            contactInfo += " | \(contactPhone)"
        }
        
        let body: [String: Any] = [
            "title": caption,
            "description": description,
            "latitude": currentLocation?.latitude ?? 37.8719,
            "longitude": currentLocation?.longitude ?? -122.2585,
            "contact": contactInfo,
            "urgencyLevel": selectedUrgency.rawValue
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let bodyString = String(data: request.httpBody!, encoding: .utf8)!
            print("REQUEST BODY:", bodyString)
        } catch {
            print("Failed to serialize JSON:", error)
            isSubmitting = false
            return
        }
        
        print("Sending network request to:", url.absoluteString)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            print("Network response received")
            
            DispatchQueue.main.async {
                isSubmitting = false
                
                if let error = error {
                    print("NETWORK ERROR:", error.localizedDescription)
                    errorMessage = "Network error: \(error.localizedDescription)"
                    showAlert = true
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("STATUS CODE:", httpResponse.statusCode)
                    
                    if let data = data,
                       let responseString = String(data: data, encoding: .utf8) {
                        print("RESPONSE:", responseString)
                    }
                    
                    if httpResponse.statusCode == 400,
                       let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        if let flagged = json["flagged"] as? Bool, flagged == true {
                            if let reason = json["reason"] as? String {
                                errorMessage = reason
                            } else {
                                errorMessage = "This request cannot be posted due to safety concerns."
                            }
                            showAlert = true
                            return
                        }
                        
                        if let errorMsg = json["error"] as? String {
                            errorMessage = errorMsg
                            showAlert = true
                            return
                        }
                    }
                    
                    if httpResponse.statusCode == 201 {
                        print("SUCCESS!")
                        showingSuccess = true
                        onRequestCreated()
                        return
                    }
                }
                
                errorMessage = "Failed to create request (no valid response)"
                showAlert = true
            }
        }.resume()
        
        print("Network request started")
    }
}

struct LocationPickerView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.8719, longitude: -122.2585),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var isGeocodingAddress = false
    @State private var addressPreview = "Move map to select location"
    
    @Environment(\.presentationMode) var presentationMode
    
    private let berkeleyBlue = Color(red: 0/255, green: 50/255, blue: 98/255)
    
    var body: some View {
        NavigationView {
            ZStack {
                Map(coordinateRegion: $region, interactionModes: .all)
                    .frame(minHeight: 400)
                    .onChange(of: region.center.latitude) { _ in
                        updateSelection()
                    }
                    .onChange(of: region.center.longitude) { _ in
                        updateSelection()
                    }
                
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                    .shadow(radius: 5)
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        if isGeocodingAddress {
                            ProgressView()
                        } else {
                            Text(addressPreview)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button("Confirm Location") {
                            selectedLocation = region.center
                            presentationMode.wrappedValue.dismiss()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(berkeleyBlue)
                        .cornerRadius(12)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .padding()
                }
                
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let existingLocation = selectedLocation {
                region.center = existingLocation
                updateAddressForLocation(existingLocation)
            }
        }
    }
    
    private func updateSelection() {
        updateAddressForLocation(region.center)
    }
    
    private func centerOnCurrentLocation() {
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
        
        if let location = locationManager.location {
            withAnimation {
                region.center = location.coordinate
            }
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

struct RequestView_Previews: PreviewProvider {
    static var previews: some View {
        RequestView(token: .constant("sample_token"), userEmail: "test@berkeley.edu")
    }
}
