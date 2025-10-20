//
//  Place.swift
//  CalPin
//

import Foundation
import MapKit
import SwiftUI

enum UrgencyLevel: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"
    
    var color: Color {
        switch self {
        case .low: return Color(red: 0.2, green: 0.7, blue: 0.9)
        case .medium: return Color(red: 1.0, green: 0.8, blue: 0.0)
        case .high: return Color(red: 1.0, green: 0.5, blue: 0.0)
        case .urgent: return Color(red: 0.9, green: 0.2, blue: 0.2)
        }
    }
    
    var uiColor: UIColor {
        switch self {
        case .low: return UIColor(red: 0.2, green: 0.7, blue: 0.9, alpha: 1.0)
        case .medium: return UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        case .high: return UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
        case .urgent: return UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
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
    
    var timeExpectation: String {
        switch self {
        case .low: return "Within 24 hours"
        case .medium: return "Within few hours"
        case .high: return "Within 1 hour"
        case .urgent: return "ASAP"
        }
    }
    
    var shouldPulse: Bool {
        return self == .urgent
    }
}

enum RequestStatus: String, CaseIterable {
    case open = "Open"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"
    
    var displayName: String {
        switch self {
        case .open: return "Open"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: Color {
        switch self {
        case .open: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

enum AICategory: String, Codable, CaseIterable {
    case academic
    case technical
    case social
    case transportation
    case moving
    case food
    case health
    case emergency
    case other
    
    var displayName: String {
        switch self {
        case .academic: return "Academic"
        case .technical: return "Technical"
        case .social: return "Social"
        case .transportation: return "Transportation"
        case .moving: return "Moving/Carrying"
        case .food: return "Food & Dining"
        case .health: return "Health & Wellness"
        case .emergency: return "Emergency"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .academic: return "📚"
        case .technical: return "💻"
        case .social: return "🤝"
        case .transportation: return "🚗"
        case .moving: return "📦"
        case .food: return "🍕"
        case .health: return "🏥"
        case .emergency: return "🚨"
        case .other: return "📌"
        }
    }
    
    var color: Color {
        switch self {
        case .academic: return Color(red: 0/255, green: 50/255, blue: 98/255)
        case .technical: return .blue
        case .social: return .purple
        case .transportation: return .green
        case .moving: return .brown
        case .food: return .orange
        case .health: return .red
        case .emergency: return Color(red: 139/255, green: 0/255, blue: 0/255)
        case .other: return .gray
        }
    }
}

struct Place: Identifiable, Codable, Equatable {
    let id: String
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
        let isCurrentUserHelping: Bool
        
        // NEW: AI-generated fields
        let aiCategory: AICategory?
        let aiCategoryName: String?
        let aiCategoryIcon: String?
        let aiTags: [String]?
        let aiEstimatedTime: Int?
        let aiDetectedUrgency: String?
        let aiSuggestedTitle: String?
        
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
        var isPendingCompletion: Bool {
            return status.rawValue == "pending_completion"
        }
        
        var canBeCompleted: Bool {
            return status == .inProgress || isPendingCompletion
        }
        
        var timeAgo: String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: createdAt, relativeTo: Date())
        }
        
        var isExpired: Bool {
            return Date().timeIntervalSince(createdAt) > 24 * 60 * 60
        }
        
        // Get category with fallback
        var category: AICategory {
            return aiCategory ?? .other
        }
        
        // Get estimated time with formatting
        var estimatedTimeFormatted: String? {
            guard let time = aiEstimatedTime else { return nil }
            if time < 60 {
                return "~\(time) min"
            } else {
                let hours = time / 60
                let mins = time % 60
                if mins == 0 {
                    return "~\(hours)h"
                } else {
                    return "~\(hours)h \(mins)m"
                }
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case id, title, description, contact, distance, duration
            case urgencyLevel, status, createdAt, updatedAt
            case authorId, authorName, helpersCount, isCurrentUserHelping
            case latitude, longitude
            // AI fields
            case aiCategory = "ai_category"
            case aiCategoryName = "ai_category_name"
            case aiCategoryIcon = "ai_category_icon"
            case aiTags = "ai_tags"
            case aiEstimatedTime = "ai_estimated_time"
            case aiDetectedUrgency = "ai_detected_urgency"
            case aiSuggestedTitle = "ai_suggested_title"
        }
        
        init(id: String,
             title: String,
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
             helpersCount: Int = 0,
             isCurrentUserHelping: Bool = false,
             aiCategory: AICategory? = nil,
             aiCategoryName: String? = nil,
             aiCategoryIcon: String? = nil,
             aiTags: [String]? = nil,
             aiEstimatedTime: Int? = nil,
             aiDetectedUrgency: String? = nil,
             aiSuggestedTitle: String? = nil) {
            self.id = id
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
            self.isCurrentUserHelping = isCurrentUserHelping
            self.aiCategory = aiCategory
            self.aiCategoryName = aiCategoryName
            self.aiCategoryIcon = aiCategoryIcon
            self.aiTags = aiTags
            self.aiEstimatedTime = aiEstimatedTime
            self.aiDetectedUrgency = aiDetectedUrgency
            self.aiSuggestedTitle = aiSuggestedTitle
        }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let idString = try? container.decode(String.self, forKey: .id) {
            id = idString
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            id = UUID().uuidString
        }
        
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        contact = try container.decode(String.self, forKey: .contact)
        distance = try container.decode(String.self, forKey: .distance)
        duration = try container.decode(String.self, forKey: .duration)
        
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
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
        isCurrentUserHelping = try container.decodeIfPresent(Bool.self, forKey: .isCurrentUserHelping) ?? false
        if let categoryString = try container.decodeIfPresent(String.self, forKey: .aiCategory) {
            aiCategory = AICategory(rawValue: categoryString)
        } else {
            aiCategory = nil
        }
        
        aiCategoryName = try container.decodeIfPresent(String.self, forKey: .aiCategoryName)
        aiCategoryIcon = try container.decodeIfPresent(String.self, forKey: .aiCategoryIcon)
        aiTags = try container.decodeIfPresent([String].self, forKey: .aiTags)
        aiEstimatedTime = try container.decodeIfPresent(Int.self, forKey: .aiEstimatedTime)
        aiDetectedUrgency = try container.decodeIfPresent(String.self, forKey: .aiDetectedUrgency)
        aiSuggestedTitle = try container.decodeIfPresent(String.self, forKey: .aiSuggestedTitle)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
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
        try container.encode(isCurrentUserHelping, forKey: .isCurrentUserHelping)
        try container.encodeIfPresent(aiCategory?.rawValue, forKey: .aiCategory)
        try container.encodeIfPresent(aiCategoryName, forKey: .aiCategoryName)
        try container.encodeIfPresent(aiCategoryIcon, forKey: .aiCategoryIcon)
        try container.encodeIfPresent(aiTags, forKey: .aiTags)
        try container.encodeIfPresent(aiEstimatedTime, forKey: .aiEstimatedTime)
        try container.encodeIfPresent(aiDetectedUrgency, forKey: .aiDetectedUrgency)
        try container.encodeIfPresent(aiSuggestedTitle, forKey: .aiSuggestedTitle)
    }
}

// Extension to make CLLocationCoordinate2D Equatable
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return abs(lhs.latitude - rhs.latitude) < 0.000001 &&
               abs(lhs.longitude - rhs.longitude) < 0.000001
    }
}
