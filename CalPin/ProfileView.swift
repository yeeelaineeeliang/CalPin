//
//  ProfileView.swift
//  CalPin
//


import SwiftUI
import Alamofire

struct UserStats: Codable {
    let requestsMade: Int
    let peopleHelped: Int
    let communityPoints: Int
    let thisWeek: Int
    let currentStreak: Int?
    let totalConnectionsMade: Int?
    let avgResponseTime: Double?
    let completionRate: Int?
    let joinDate: String?
    let lastActivity: String?
    let weeklyActivity: [WeeklyActivity]?
    
    // Computed properties for display
    var joinDateFormatted: String {
        guard let joinDateString = joinDate,
              let date = ISO8601DateFormatter().date(from: joinDateString) else {
            return "Recently joined"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var lastActivityFormatted: String {
        guard let lastActivityString = lastActivity,
              let date = ISO8601DateFormatter().date(from: lastActivityString) else {
            return "No recent activity"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var safeCurrentStreak: Int {
        return currentStreak ?? 0
    }
    
    var safeTotalConnections: Int {
        return totalConnectionsMade ?? 0
    }
    
    var safeCompletionRate: Int {
        return completionRate ?? 0
    }
    
    var safeWeeklyActivity: [WeeklyActivity] {
        return weeklyActivity ?? []
    }
}

struct WeeklyActivity: Codable {
    let week: String
    let helpsCount: Int
    
    var weekDate: Date {
        return ISO8601DateFormatter().date(from: week) ?? Date()
    }
}

struct Achievement: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let earned: Bool
    let progress: Int
    let target: Int
    let earnedAt: Date?
    
    var progressPercentage: Double {
        return min(Double(progress) / Double(target), 1.0)
    }
}

struct ActivityTimelineItem: Codable, Identifiable {
    let activityType: String
    let timestamp: String
    let requestTitle: String
    let urgencyLevel: String
    let authorName: String?
    let requestId: Int
    let statusChange: String?
    
    var id: String { "\(activityType)-\(requestId)-\(timestamp)" }
    
    var timestampDate: Date {
        return ISO8601DateFormatter().date(from: timestamp) ?? Date()
    }
    
    var displayText: String {
        switch activityType {
        case "help_offered":
            return "Offered help for \"\(requestTitle)\""
        case "request_created":
            return "Created request \"\(requestTitle)\""
        default:
            return "Unknown activity"
        }
    }
    
    var icon: String {
        switch activityType {
        case "help_offered":
            return "hand.raised.fill"
        case "request_created":
            return "plus.circle.fill"
        default:
            return "circle.fill"
        }
    }
    
    var iconColor: Color {
        switch activityType {
        case "help_offered":
            return .green
        case "request_created":
            return .blue
        default:
            return .gray
        }
    }
}

// MARK: - Enhanced Profile View
struct ProfileView: View {
    let userName: String
    let userEmail: String
    let onSignOut: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var userSession: UserSession
    
    // Dynamic data
    @State private var userStats: UserStats?
    @State private var achievements: [Achievement] = []
    @State private var activityTimeline: [ActivityTimelineItem] = []
    @State private var isLoadingStats = true
    @State private var selectedTab = 0
    
    private let berkeleyBlue = Color(red: 0/255, green: 50/255, blue: 98/255)
    private let californiaGold = Color(red: 253/255, green: 181/255, blue: 21/255)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeaderView
                    
                    // Tab Selection
                    tabSelectionView
                    
                    // Content based on selected tab
                    if selectedTab == 0 {
                        statsContentView
                    } else if selectedTab == 1 {
                        achievementsContentView
                    } else {
                        activityContentView
                    }
                    
                    Spacer(minLength: 20)
                    
                    // Sign out button
                    signOutButton
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
        .onAppear {
            fetchUserData()
        }
        .refreshable {
            await refreshUserData()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshProfile"))) { _ in
            fetchUserData()
        }
    }
    
    // MARK: - Profile Header
    private var profileHeaderView: some View {
        VStack(spacing: 16) {
            // Avatar with streak indicator
            ZStack {
                Circle()
                    .fill(berkeleyBlue.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Text(String(userName.prefix(1)).uppercased())
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(berkeleyBlue)
                    )
                
                // Streak indicator
                if let stats = userStats, stats.safeCurrentStreak > 0 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(californiaGold)
                                    .frame(width: 32, height: 32)
                                
                                Text("ðŸ”¥")
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .frame(width: 100, height: 100)
                }
            }
            
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
                
                // Member since
                if let stats = userStats {
                    Text("Member since \(stats.joinDateFormatted)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 8)
    }
    
    // MARK: - Tab Selection
    private var tabSelectionView: some View {
        HStack(spacing: 0) {
            TabButton(title: "Stats", icon: "chart.bar.fill", isSelected: selectedTab == 0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = 0
                }
            }
            
            TabButton(title: "Achievements", icon: "trophy.fill", isSelected: selectedTab == 1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = 1
                }
            }
            
            TabButton(title: "Activity", icon: "clock.fill", isSelected: selectedTab == 2) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = 2
                }
            }
        }
        .padding(4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Stats Content
    private var statsContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoadingStats {
                ProgressView("Loading your impact...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let stats = userStats {
                // Current streak highlight
                if stats.safeCurrentStreak > 0 {
                    streakCardView(streak: stats.safeCurrentStreak)
                }
                
                // Main stats grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    StatCard(
                        title: "Requests Made",
                        value: "\(stats.requestsMade)",
                        icon: "hand.raised.fill",
                        color: .blue,
                        subtitle: "Help requests created"
                    )
                    
                    StatCard(
                        title: "People Helped",
                        value: "\(stats.peopleHelped)",
                        icon: "heart.fill",
                        color: .red,
                        subtitle: "Unique individuals assisted"
                    )
                    
                    StatCard(
                        title: "Community Points",
                        value: "\(stats.communityPoints)",
                        icon: "star.fill",
                        color: californiaGold,
                        subtitle: "Total points earned"
                    )
                    
                    StatCard(
                        title: "This Week",
                        value: "\(stats.thisWeek)",
                        icon: "calendar",
                        color: .green,
                        subtitle: "Recent helping activity"
                    )
                }
                
                // Additional stats
                VStack(spacing: 12) {
                    StatRowView(
                        title: "Total Connections",
                        value: "\(stats.safeTotalConnections)",
                        icon: "person.2.fill",
                        description: "Unique students you've interacted with"
                    )
                    
                    StatRowView(
                        title: "Last Activity",
                        value: stats.lastActivityFormatted,
                        icon: "clock.fill",
                        description: "Most recent help you offered"
                    )
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 4)
                
                if !stats.safeWeeklyActivity.isEmpty {
                    weeklyActivityView(activity: stats.safeWeeklyActivity)
                }
                
            } else {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Unable to load statistics")
                        .font(.headline)
                    Text("Please try again later")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 8)
    }
    
    // Achievements Content
    private var achievementsContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(californiaGold)
                Text("Achievements")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(berkeleyBlue)
                Spacer()
            }
            
            if achievements.isEmpty {
                VStack {
                    Image(systemName: "trophy")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No achievements yet")
                        .font(.headline)
                    Text("Start helping others to earn your first achievement!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 12) {
                    ForEach(achievements) { achievement in
                        AchievementRowView(achievement: achievement)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 8)
    }
    
    // Activity Content
    private var activityContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(berkeleyBlue)
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(berkeleyBlue)
                Spacer()
            }
            
            if activityTimeline.isEmpty {
                VStack {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No recent activity")
                        .font(.headline)
                    Text("Your help requests and offers will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(activityTimeline) { item in
                        ActivityRowView(item: item)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 8)
    }
    
    // Sign Out Button
    private var signOutButton: some View {
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
    
    // Helper Views
    
    private func streakCardView(streak: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("ðŸ”¥")
                        .font(.title)
                    Text("\(streak) Week\(streak == 1 ? "" : "s")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(californiaGold)
                }
                Text("Current helping streak!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Keep helping others to maintain your streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "flame.fill")
                .font(.largeTitle)
                .foregroundColor(californiaGold)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [californiaGold.opacity(0.1), californiaGold.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(californiaGold.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func weeklyActivityView(activity: [WeeklyActivity]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(berkeleyBlue)
                Text("Weekly Activity")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(berkeleyBlue)
                Spacer()
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(activity.indices, id: \.self) { index in
                    let item = activity[index]
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(berkeleyBlue.opacity(0.7))
                            .frame(width: 30, height: max(CGFloat(item.helpsCount) * 10, 4))
                            .cornerRadius(4)
                        
                        Text("\(item.helpsCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
    
    
    private func fetchUserData() {
        isLoadingStats = true
        
        // Fetch user stats
        fetchUserStats()
        fetchAchievements()
        fetchActivityTimeline()
    }
    
    @MainActor
    private func refreshUserData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchUserStatsAsync() }
            group.addTask { await self.fetchAchievementsAsync() }
            group.addTask { await self.fetchActivityTimelineAsync() }
        }
    }
    
    private func fetchUserStats() {
        guard !userSession.token.isEmpty else {
            print("âŒ No token available for stats fetch")
            isLoadingStats = false
            return
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(userSession.token)",
            "Content-Type": "application/json"
        ]
        
        AF.request(
            "\(NetworkConfig.baseURL)\(NetworkConfig.endpoints.userStats)",
            method: .get,
            headers: headers
        )
        .responseDecodable(of: UserStats.self) { response in
            DispatchQueue.main.async {
                self.isLoadingStats = false
                
                switch response.result {
                case .success(let stats):
                    print("âœ… User stats fetched successfully")
                    self.userStats = stats
                case .failure(let error):
                    print("âŒ Failed to fetch user stats: \(error)")
                    print("âŒ Response data: \(String(data: response.data ?? Data(), encoding: .utf8) ?? "No data")")
                }
            }
        }
    }
    
    @MainActor
    private func fetchUserStatsAsync() async {
        guard !userSession.token.isEmpty else {
            print("âŒ No token available for stats fetch")
            isLoadingStats = false
            return
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(userSession.token)",
            "Content-Type": "application/json"
        ]
        
        do {
            let stats = try await AF.request(
                "\(NetworkConfig.baseURL)\(NetworkConfig.endpoints.userStats)",
                method: .get,
                headers: headers
            ).serializingDecodable(UserStats.self).value
            
            self.userStats = stats
            self.isLoadingStats = false
            print("âœ… User stats fetched successfully")
            
        } catch {
            print("âŒ Failed to fetch user stats: \(error)")
            isLoadingStats = false
        }
    }
    
    private func fetchAchievements() {
        guard !userSession.token.isEmpty else { return }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(userSession.token)",
            "Content-Type": "application/json"
        ]
        
        // Create decoder with ISO8601 date strategy
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        AF.request(
            "\(NetworkConfig.baseURL)/api/user/achievements",
            method: .get,
            headers: headers
        )
        .responseDecodable(of: [Achievement].self, decoder: decoder) { response in
            DispatchQueue.main.async {
                switch response.result {
                case .success(let achievements):
                    print("âœ… Achievements fetched successfully: \(achievements.count)")
                    self.achievements = achievements
                case .failure(let error):
                    print("âŒ Failed to fetch achievements: \(error)")
                }
            }
        }
    }
    
    @MainActor
    private func fetchAchievementsAsync() async {
        guard !userSession.token.isEmpty else { return }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(userSession.token)",
            "Content-Type": "application/json"
        ]
        
        // Create decoder with ISO8601 date strategy
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let achievements = try await AF.request(
                "\(NetworkConfig.baseURL)/api/user/achievements",
                method: .get,
                headers: headers
            ).serializingDecodable([Achievement].self, decoder: decoder).value
            
            self.achievements = achievements
            print("âœ… Achievements fetched successfully: \(achievements.count)")
            
        } catch {
            print("âŒ Failed to fetch achievements: \(error)")
        }
    }
    
    private func fetchActivityTimeline() {
        guard !userSession.token.isEmpty else { return }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(userSession.token)",
            "Content-Type": "application/json"
        ]
        
        AF.request(
            "\(NetworkConfig.baseURL)/api/user/activity-timeline?limit=10",
            method: .get,
            headers: headers
        )
        .responseDecodable(of: [ActivityTimelineItem].self) { response in
            DispatchQueue.main.async {
                switch response.result {
                case .success(let timeline):
                    print("âœ… Activity timeline fetched successfully: \(timeline.count) items")
                    self.activityTimeline = timeline
                case .failure(let error):
                    print("âŒ Failed to fetch activity timeline: \(error)")
                }
            }
        }
    }
    
    @MainActor
    private func fetchActivityTimelineAsync() async {
        guard !userSession.token.isEmpty else { return }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(userSession.token)",
            "Content-Type": "application/json"
        ]
        
        do {
            let timeline = try await AF.request(
                "\(NetworkConfig.baseURL)/api/user/activity-timeline?limit=10",
                method: .get,
                headers: headers
            ).serializingDecodable([ActivityTimelineItem].self).value
            
            self.activityTimeline = timeline
            print("âœ… Activity timeline fetched successfully: \(timeline.count) items")
            
        } catch {
            print("âŒ Failed to fetch activity timeline: \(error)")
        }
    }
}

//  Supporting Views

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    private let berkeleyBlue = Color(red: 0/255, green: 50/255, blue: 98/255)
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : berkeleyBlue)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? berkeleyBlue : Color.clear)
            )
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String?
    
    init(title: String, value: String, icon: String, color: Color, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
    }
    
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
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatRowView: View {
    let title: String
    let value: String
    let icon: String
    let description: String
    
    private let berkeleyBlue = Color(red: 0/255, green: 50/255, blue: 98/255)
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(berkeleyBlue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(berkeleyBlue)
        }
        .padding(.vertical, 4)
    }
}

struct AchievementRowView: View {
    let achievement: Achievement
    
    private let californiaGold = Color(red: 253/255, green: 181/255, blue: 21/255)
    
    var body: some View {
        HStack(spacing: 12) {
            // Achievement icon
            ZStack {
                Circle()
                    .fill(achievement.earned ? californiaGold.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Text(achievement.icon)
                    .font(.title2)
                    .opacity(achievement.earned ? 1.0 : 0.5)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(achievement.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(achievement.earned ? .primary : .secondary)
                    
                    if achievement.earned {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Progress bar
                if !achievement.earned && achievement.progress > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        ProgressView(value: achievement.progressPercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: californiaGold))
                            .frame(height: 4)
                        
                        Text("\(achievement.progress) / \(achievement.target)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    achievement.earned ? californiaGold.opacity(0.3) : Color.gray.opacity(0.2),
                    lineWidth: 1
                )
        )
    }
}

struct ActivityRowView: View {
    let item: ActivityTimelineItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Activity icon
            Image(systemName: item.icon)
                .foregroundColor(item.iconColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(RelativeDateTimeFormatter().localizedString(for: item.timestampDate, relativeTo: Date()))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let authorName = item.authorName {
                    Text("by \(authorName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(0.8)
                }
            }
            
            Spacer()
            
            if let urgencyLevel = UrgencyLevel(rawValue: item.urgencyLevel) {
                UrgencyDot(level: urgencyLevel)
            }
        }
        .padding(.vertical, 8)
    }
}
