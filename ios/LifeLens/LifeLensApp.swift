import SwiftUI

// MARK: - App Entry Point

@main
struct LifeLensApp: App {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var callManager = CallManager.shared
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
                .environmentObject(locationManager)
                .environmentObject(callManager)
                .environmentObject(notificationManager)
        }
        .onAppear {
            setupBackgroundTasks()
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @EnvironmentObject private var locationManager: LocationManager

    var body: some View {
        Group {
            if healthKitManager.isAuthorized {
                MainTabView()
            } else {
                AuthorizationView()
            }
        }
        .tint(.red)
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @EnvironmentObject private var locationManager: LocationManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)

            HealthDataView()
                .tabItem {
                    Label("Health", systemImage: "heart.fill")
                }
                .tag(1)

            LocationView()
                .tabItem {
                    Label("Location", systemImage: "location.fill")
                }
                .tag(2)

            CommunicationView()
                .tabItem {
                    Label("Communication", systemImage: "message.fill")
                }
                .tag(3)

            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(.red)
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            List {
                // Sync Status Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Sync")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let lastSync = healthKitManager.lastSync {
                                Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                    .font(.headline)
                            } else {
                                Text("Never")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button("Sync Now") {
                            manualSync()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRefreshing)
                    }
                } header: {
                    Text("Sync Status")
                } footer: {
                    if healthKitManager.pendingRecords > 0 {
                        Text("\(healthKitManager.pendingRecords) records pending upload")
                            .foregroundStyle(.orange)
                    }
                }

                // Authorization Status
                Section {
                    HStack {
                        Image(systemName: healthKitManager.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(healthKitManager.isAuthorized ? .green : .red)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("HealthKit")
                                .font(.headline)

                            Text(healthKitManager.isAuthorized ? "Authorized" : "Not Authorized")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Permissions")
                }

                // Data Types Section
                Section {
                    ForEach(HealthDataType.allCases, id: \.self) { dataType in
                        HStack {
                            Image(systemName: iconForDataType(dataType))
                                .foregroundStyle(.red)
                                .frame(width: 32)

                            Text(dataType.rawValue.capitalized)
                                .font(.subheadline)

                            Spacer()

                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text("Tracked Data Types")
                }
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await manualSync()
            }
        }
    }

    private func manualSync() {
        isRefreshing = true

        Task {
            await healthKitManager.manualSync()

            await MainActor.run {
                isRefreshing = false
            }
        }
    }

    private func iconForDataType(_ dataType: HealthDataType) -> String {
        switch dataType {
        case .steps:
            return "figure.walk"
        case .heartRate:
            return "heart.fill"
        case .heartRateVariability:
            return "waveform.path"
        case .activeEnergy:
            return "flame.fill"
        case .restingHeartRate:
            return "heart.slash"
        case .sleepAnalysis:
            return "bed.double.fill"
        case .workout:
            return "figure.strengthtraining.traditional"
        case .distance:
            return "location.fill"
        }
    }
}

// MARK: - Health Data View

struct HealthDataView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red.gradient)

                Text("Health Data")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Detailed health metrics will be available in the web dashboard")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("Health")
        }
    }
}

// MARK: - Communication View

struct CommunicationView: View {
    @EnvironmentObject private var callManager: CallManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            List {
                // Sync Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Sync")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let lastSync = callManager.lastSync {
                                Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                    .font(.headline)
                            } else {
                                Text("Never")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button("Sync Now") {
                            syncCommunicationData()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRefreshing)
                    }
                } header: {
                    Text("Sync Status")
                } footer: {
                    Text("Communication data syncs automatically in the background. Pull to refresh to force sync.")
                        .font(.caption)
                }

                // Call Stats
                Section {
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(.green)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Calls Detected")
                                .font(.headline)

                            Text("\(callManager.incomingCallsDetected) calls logged")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Call Tracking")
                }

                // Notification Stats
                Section {
                    if !notificationManager.notificationCounts.isEmpty {
                        ForEach(Array(notificationManager.notificationCounts.keys.sorted()), id: \.self) { app in
                            HStack {
                                Image(systemName: "app.badge.fill")
                                    .foregroundStyle(.blue)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(app.capitalized)
                                        .font(.subheadline)

                                    Text("\(notificationManager.notificationCounts[app] ?? 0) notifications")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "app.dashed")
                                .foregroundStyle(.gray)
                            Text("No notifications logged yet")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Notification Activity")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("⚠️ Limited by iOS Privacy")
                        Text("iOS only allows tracking notifications while LifeLens is running. Historical notification data is not accessible.")
                        Text("For accurate tracking, keep LifeLens in background.")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoItem(
                            icon: "checkmark.shield.fill",
                            title: "Metadata Only",
                            description: "Only tracks caller ID, timestamp, and duration. No call content or recordings."
                        )

                        InfoItem(
                            icon: "arrow.down.circle",
                            title: "Incoming Calls",
                            description: "Automatically detected in real-time via CallKit"
                        )

                        InfoItem(
                            icon: "arrow.up.circle",
                            title: "Outgoing Calls",
                            description: "Fetched from call history periodically (requires iOS 14+)"
                        )

                        InfoItem(
                            icon: "exclamationmark.bubble.fill",
                            title: "SMS Not Available",
                            description: "iOS prevents access to message content. Call history is available."
                        )
                    }
                } header: {
                    Text("What's Tracked")
                }
            }
            .navigationTitle("Communication")
            .refreshable {
                await syncCommunicationData()
            }
        }
    }

    private func syncCommunicationData() {
        isRefreshing = true

        Task {
            // Sync call history
            await callManager.fetchCallHistory()

            // Sync notification counts
            await notificationManager.syncNotificationCounts()

            await MainActor.run {
                isRefreshing = false
            }
        }
    }
}

// MARK: - Settings Tab View

struct SettingsTabView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var callManager: CallManager
    @EnvironmentObject private var notificationManager: NotificationManager

    var body: some View {
        NavigationStack {
            Form {
                // Server Configuration
                Section {
                    HStack {
                        Text("Server URL")
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(UserDefaults.standard.string(forKey: "server_url") ?? "Not configured")
                            .foregroundStyle(.primary)
                    }

                    HStack {
                        Text("API Key")
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(UserDefaults.standard.string(forKey: "api_key")?.masked ?? "Not configured")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Server Configuration")
                } footer: {
                    Button("Configure Server") {
                        // TODO: Show configuration sheet
                    }
                }

                // Location Settings
                Section {
                    Picker("Tracking Mode", selection: $locationManager.trackingMode) {
                        ForEach(LocationManager.TrackingMode.allCases, id: \.self) { mode in
                            VStack(alignment: .leading) {
                                Text(mode.displayName)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(mode)
                        }
                    }
                } header: {
                    Text("Location Settings")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Battery Saver: Significant location changes only (~500m-1km).")
                        Text("High Accuracy: Active GPS when app is open.")
                        Text("Note: Location data requires 'Always' permission for background tracking.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                // Permissions Status
                Section {
                    PermissionRow(
                        icon: "heart.fill",
                        name: "HealthKit",
                        isAuthorized: healthKitManager.isAuthorized
                    )

                    PermissionRow(
                        icon: "location.fill",
                        name: "Location",
                        isAuthorized: locationManager.authorizationStatus == .authorizedAlways || locationManager.authorizationStatus == .authorizedWhenInUse
                    )

                    PermissionRow(
                        icon: "phone.fill",
                        name: "CallKit",
                        isAuthorized: true // Always available if HealthKit is authorized
                    )
                } header: {
                    Text("Permissions")
                }

                // About
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("LifeLens v1.0")
                                .font(.headline)

                            Text("Automated Life Tracking")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let icon: String
    let name: String
    let isAuthorized: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.red)
                .frame(width: 32)

            Text(name)
                .font(.subheadline)

            Spacer()

            Image(systemName: isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isAuthorized ? .green : .orange)
        }
    }
}

// MARK: - Location View

struct LocationView: View {
    @EnvironmentObject private var locationManager: LocationManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let location = locationManager.currentLocation {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(.red)
                                Text("Current Location")
                                    .font(.headline)
                            }

                            Text("Lat: \(location.coordinate.latitude, format: .number.precision(.fractionLength(6)))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("Lon: \(location.coordinate.longitude, format: .number.precision(.fractionLength(6)))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("Accuracy: \(location.horizontalAccuracy, format: .number.precision(.fractionLength(0)))m")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "location.slash")
                                .foregroundStyle(.gray)
                            Text("No location data yet")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Status")
                } footer: {
                    if let lastSync = locationManager.lastSync {
                        Text("Last updated: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoItem(
                            icon: "battery",
                            title: "Battery Efficient",
                            description: "Uses significant location changes to minimize battery impact"
                        )

                        InfoItem(
                            icon: "checkmark.circle.fill",
                            title: "Background Tracking",
                            description: "Continues tracking when app is closed or in background"
                        )

                        InfoItem(
                            icon: "exclamationmark.triangle.fill",
                            title: "Limited Granularity",
                            description: "Triggers on cell tower changes (~500m-1km), not continuous GPS"
                        )
                    }
                } header: {
                    Text("How It Works")
                }
            }
            .navigationTitle("Location")
        }
    }
}

struct InfoItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - String Extension for Masking

extension String {
    var masked: String {
        guard count > 8 else {
            return String(repeating: "•", count: count)
        }

        let prefix = prefix(4)
        let suffix = suffix(4)
        return "\(prefix)...\(suffix)"
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(HealthKitManager.shared)
}
