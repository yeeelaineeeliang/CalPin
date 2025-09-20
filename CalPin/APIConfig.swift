// NetworkConfig.swift - Alternative name to avoid conflicts
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
        offerHelp: "/api/requests/%@/offer-help",
        updateStatus: "/api/requests/%@/status",
        userStats: "/api/user/stats"
    )
}
