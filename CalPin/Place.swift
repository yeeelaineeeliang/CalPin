//
//  Place.swift
//  CalPin
//
//  Enhanced Place model with urgency levels and timestamps
//

import Foundation
import MapKit

enum UrgencyLevel: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"
    
    var color: UIColor {
        switch self {
        case .low: return .systemGreen
        case .medium: return .systemOrange
        case .high: return .systemRed
        case .urgent: return .systemPurple
        }
    }
    
    var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .urgent: return 4
        }
    }
}

enum RequestStatus: String, CaseIterable {
    case open = "Open"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

struct Place: Identifiable, Codable, Equatable {
    let id = UUID()
    let title: String
    let coordinate: CLLocationCoordinate2D
    let description: String
    let contact: String
    let distance: String
    let duration: String
    let urgencyLevel: UrgencyLevel
    let status: RequestStatus
    let createdAt: Date
    let updatedAt: Date
    let authorId: String
    let authorName: String
    let helpersCount: Int
    
    // Equatable conformance
    static func == (lhs: Place, rhs: Place) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude &&
               lhs.urgencyLevel == rhs.urgencyLevel &&
               lhs.status == rhs.status
    }
    
    // Computed properties
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    var isExpired: Bool {
        // Requests expire after 24 hours
        return Date().timeIntervalSince(createdAt) > 24 * 60 * 60
    }
    
    // Custom coding keys for coordinate
    private enum CodingKeys: String, CodingKey {
        case title, description, contact, distance, duration
        case urgencyLevel, status, createdAt, updatedAt
        case authorId, authorName, helpersCount
        case latitude, longitude
    }
    
    init(title: String,
         coordinate: CLLocationCoordinate2D,
         description: String,
         contact: String,
         distance: String,
         duration: String,
         urgencyLevel: UrgencyLevel = .medium,
         status: RequestStatus = .open,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         authorId: String = "",
         authorName: String = "",
         helpersCount: Int = 0) {
        self.title = title
        self.coordinate = coordinate
        self.description = description
        self.contact = contact
        self.distance = distance
        self.duration = duration
        self.urgencyLevel = urgencyLevel
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.authorId = authorId
        self.authorName = authorName
        self.helpersCount = helpersCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        contact = try container.decode(String.self, forKey: .contact)
        distance = try container.decode(String.self, forKey: .distance)
        duration = try container.decode(String.self, forKey: .duration)
        
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        // Decode enum values from their raw string values
        if let urgencyString = try container.decodeIfPresent(String.self, forKey: .urgencyLevel),
           let urgency = UrgencyLevel(rawValue: urgencyString) {
            urgencyLevel = urgency
        } else {
            urgencyLevel = .medium
        }
        
        if let statusString = try container.decodeIfPresent(String.self, forKey: .status),
           let requestStatus = RequestStatus(rawValue: statusString) {
            status = requestStatus
        } else {
            status = .open
        }
        
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        authorId = try container.decodeIfPresent(String.self, forKey: .authorId) ?? ""
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName) ?? ""
        helpersCount = try container.decodeIfPresent(Int.self, forKey: .helpersCount) ?? 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(contact, forKey: .contact)
        try container.encode(distance, forKey: .distance)
        try container.encode(duration, forKey: .duration)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(urgencyLevel.rawValue, forKey: .urgencyLevel)
        try container.encode(status.rawValue, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(authorName, forKey: .authorName)
        try container.encode(helpersCount, forKey: .helpersCount)
    }
}

// Extension to make CLLocationCoordinate2D Equatable
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return abs(lhs.latitude - rhs.latitude) < 0.000001 &&
               abs(lhs.longitude - rhs.longitude) < 0.000001
    }
}
