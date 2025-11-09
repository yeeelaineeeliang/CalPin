
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
    
    // offer help URL
    static func offerHelpURL(for requestId: String) -> String {
        return "\(baseURL)\(String(format: endpoints.offerHelp, requestId))"
    }
    
    // update status URL
    static func updateStatusURL(for requestId: String) -> String {
        return "\(baseURL)\(String(format: endpoints.updateStatus, requestId))"
    }
    
    // complete help URL
    static func completeHelpURL(for requestId: String) -> String {
        return "\(baseURL)\(String(format: endpoints.completeHelp, requestId))"
    }
    
    //  confirm completion URL
    static func confirmCompletionURL(for requestId: String) -> String {
        return "\(baseURL)\(String(format: endpoints.confirmCompletion, requestId))"
    }
}
