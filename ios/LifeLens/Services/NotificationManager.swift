import Foundation
import UserNotifications
import CoreData

// MARK: - Notification Manager

@MainActor
class NotificationManager: NSObject, ObservableObject {
    // MARK: - Properties

    static let shared = NotificationManager()

    @Published var notificationCounts: [String: Int] = [:]
    @Published var lastSync: Date?

    private let userNotificationCenter = UNUserNotificationCenter.current()
    private let apiClient = APIClient.shared

    // MARK: - Notification Data Models

    struct NotificationMetadata: Codable {
        let deviceID: String
        let appIdentifier: String
        let count: Int
        let timestamp: Date

        enum CodingKeys: String, CodingKey {
            case deviceID = "device_id"
            case appIdentifier = "app_identifier"
            case count
            case timestamp
        }
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        setupNotificationDelegate()
    }

    // MARK: - Setup

    private func setupNotificationDelegate() {
        userNotificationCenter.delegate = self
        requestAuthorization()
    }

    // MARK: - Authorization

    func requestAuthorization() {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        userNotificationCenter.requestAuthorization(options: options) { granted, error in
            if granted {
                print("✓ Notification authorization granted")
            } else {
                print("✗ Notification authorization denied")
            }
        }
    }

    // MARK: - Sync Notification Counts

    func syncNotificationCounts() async {
        // Fetch delivered notifications
        let requests = await userNotificationCenter.pendingNotificationRequests()

        // Count by app identifier
        var counts: [String: Int] = [:]

        for request in requests {
            let identifier = request.content.categoryIdentifier // Use category as app identifier

            if identifier.isEmpty {
                continue
            }

            counts[identifier, default: 0] += 1
        }

        // Convert to metadata
        let records = counts.map { appIdentifier, count in
            NotificationMetadata(
                deviceID: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
                appIdentifier: appIdentifier,
                count: count,
                timestamp: Date()
            )
        }

        // Upload to server
        if !records.isEmpty {
            do {
                try await apiClient.uploadNotificationMetadata(records)
                print("✓ Uploaded notification counts")

                await MainActor.run {
                    self.notificationCounts = counts
                    self.lastSync = Date()
                }
            } catch {
                print("✗ Failed to upload notification counts: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Manual Notification Logging

    func logNotification(category: String) {
        Task {
            let record = NotificationMetadata(
                deviceID: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
                appIdentifier: category,
                count: 1,
                timestamp: Date()
            )

            do {
                try await apiClient.uploadNotificationMetadata([record])

                await MainActor.run {
                    self.notificationCounts[category, default: 0] += 1
                }
            } catch {
                print("✗ Failed to log notification: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Called when app is in foreground and a notification is delivered
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Log notification
        let category = notification.request.content.categoryIdentifier
        if !category.isEmpty {
            Task {
                await logNotification(category: category)
            }
        }

        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Called when user taps on a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Log notification interaction
        let category = response.notification.request.content.categoryIdentifier
        if !category.isEmpty {
            Task {
                await logNotification(category: category)
            }
        }

        completionHandler()
    }
}

// MARK: - API Client Extension

extension APIClient {
    func uploadNotificationMetadata(_ records: [NotificationManager.NotificationMetadata]) async throws -> ServerResponse {
        guard !records.isEmpty else {
            throw APIError.noData
        }

        var request = createRequest(endpoint: "/api/v1/ingest/notification/batch", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["records": records]
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 201:
            let result = try decoder.decode(ServerResponse.self, from: data)
            return result
        case 401, 403:
            throw APIError.unauthorized
        case 422:
            throw APIError.validationError(String(data: data, encoding: .utf8) ?? "Unknown validation error")
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.unknownError(httpResponse.statusCode)
        }
    }
}

// MARK: - Notification Limitations Notice

/*
IMPORTANT LIMITATIONS:

iOS does NOT allow apps to:
1. Read notification content from other apps (privacy/security)
2. Access historical notification counts
3. Count notifications that were delivered while app was not running
4. Detect silent notifications
5. Access notification data from locked device

What this implementation CAN do:
1. Count notifications delivered while app is running
2. Log when user interacts with notifications (taps)
3. Track notifications from local sources (app-generated)
4. Estimate notification activity via UserNotifications framework

For accurate notification tracking:
- User must keep LifeLens running in background
- Notifications must be interactive (tappable)
- Notification categories must be set by source apps
- Data will be incomplete (only captures what iOS allows)

ALTERNATIVE: Use "Screen Time" API (if available)
iOS 15+ introduces some Screen Time APIs for app usage tracking,
but these are limited and require additional entitlements.
*/
