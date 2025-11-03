
import Foundation

struct NetworkConfig {
    #if DEBUG
    static let baseURL = "https://calpin-production.up.railway.app" // For local development
    #else
    static let baseURL = "https://calpin-production.up.railway.app" // Your Railway URL
    #endif
    
    static let endpoints = (
        fetch: "/api/fetch",
        create: "/api/create",
        rephrase: "/api/rephrase",
        offerHelp: "/api/requests/%@/offer-help",
        completeHelp: "/api/requests/%@/complete-help",
        confirmCompletion: "/api/requests/%@/confirm-completion",
        updateStatus: "/api/requests/%@/status",
        userStats: "/api/user/stats",
        userAchievements: "/api/user/achievements",
        userActivityTimeline: "/api/user/activity-timeline",
        userHistory: "/api/user/history",
        health: "/health",
    )
    
    // Helper method to construct offer help URL
    static func offerHelpURL(for requestId: String) -> String {
        return "\(baseURL)\(String(format: endpoints.offerHelp, requestId))"
    }
    
    // Helper method to construct update status URL
    static func updateStatusURL(for requestId: String) -> String {
        return "\(baseURL)\(String(format: endpoints.updateStatus, requestId))"
    }
    
    // Helper method to construct complete help URL
    static func completeHelpURL(for requestId: String) -> String {
        return "\(baseURL)\(String(format: endpoints.completeHelp, requestId))"
    }
    
    // Helper method to construct confirm completion URL
    static func confirmCompletionURL(for requestId: String) -> String {
        return "\(baseURL)\(String(format: endpoints.confirmCompletion, requestId))"
    }
}
