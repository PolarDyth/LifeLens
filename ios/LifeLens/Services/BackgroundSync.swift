import Foundation
import BackgroundTasks
import HealthKit

// MARK: - Background Sync Manager

@MainActor
class BackgroundSyncManager {
    // MARK: - Properties

    static let shared = BackgroundSyncManager()

    private let healthKitManager = HealthKitManager.shared
    private let locationMgr = LocationManager.shared

    // Background task identifiers
    private let healthSyncTaskIdentifier = "com.lifelens.health.sync"
    private let locationSyncTaskIdentifier = "com.lifelens.location.sync"
    private let dailyMaintenanceTaskIdentifier = "com.lifelens.maintenance"

    // MARK: - Initialization

    private init() {
        // Register background tasks
        registerBackgroundTasks()
    }

    // MARK: - Background Task Registration

    func registerBackgroundTasks() {
        let healthSyncTask = BGProcessingTaskTask(
            identifier: healthSyncTaskIdentifier,
            using: nil
        ) { [weak self] task in
            Task { @MainActor in
                await self?.handleHealthSync(task: task)
            }
        }

        let locationSyncTask = BGProcessingTaskTask(
            identifier: locationSyncTaskIdentifier,
            using: nil
        ) { [weak self] task in
            Task { @MainActor in
                await self?.handleLocationSync(task: task)
            }
        }

        let maintenanceTask = BGProcessingTaskTask(
            identifier: dailyMaintenanceTaskIdentifier,
            using: nil
        ) { [weak self] task in
            Task { @MainActor in
                await self?.handleMaintenance(task: task)
            }
        }

        // Submit tasks
        submitBackgroundTasks()
    }

    private func submitBackgroundTasks() {
        scheduleHealthSync()
        scheduleLocationSync()
        scheduleMaintenance()
    }

    // MARK: - Health Sync Task

    private func scheduleHealthSync() {
        let request = BGProcessingTaskRequest(identifier: healthSyncTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✓ Health sync task scheduled")
        } catch {
            print("✗ Failed to schedule health sync task: \(error.localizedDescription)")
        }
    }

    private func handleHealthSync(task: BGTask) async {
        print("🔄 Background health sync started")

        do {
            // Sync health data
            try await healthKitManager.syncRecentData()

            // Schedule next sync
            scheduleHealthSync()

            task.setTaskCompleted(success: true)
            print("✓ Background health sync completed")
        } catch {
            print("✗ Background health sync failed: \(error.localizedDescription)")

            // Mark task as completed but schedule retry sooner
            task.setTaskCompleted(success: true)

            // Schedule retry in 5 minutes
            let retryDelay: TimeInterval = 300 // 5 minutes
            if let retryDate = Calendar.current.date(byAdding: .second, value: Int(retryDelay), to: Date()) {
                let request = BGProcessingTaskRequest(identifier: healthSyncTaskIdentifier)
                request.requiresNetworkConnectivity = true
                request.requiresExternalPower = false
                request.earliestBeginDate = retryDate

                try? BGTaskScheduler.shared.submit(request)
                print("Scheduled retry sync at \(retryDate)")
            }
        }
    }

    // MARK: - Location Sync Task

    private func scheduleLocationSync() {
        let request = BGProcessingTaskRequest(identifier: locationSyncTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✓ Location sync task scheduled")
        } catch {
            print("✗ Failed to schedule location sync task: \(error.localizedDescription)")
        }
    }

    private func handleLocationSync(task: BGTask) async {
        print("🔄 Background location sync started")

        do {
            // Sync pending location data
            try await locationMgr.syncPendingLocations()

            // Schedule next sync
            scheduleLocationSync()

            task.setTaskCompleted(success: true)
            print("✓ Background location sync completed")
        } catch {
            print("✗ Background location sync failed: \(error.localizedDescription)")

            // Mark task as completed but schedule retry
            task.setTaskCompleted(success: true)

            // Schedule retry in 5 minutes
            let retryDelay: TimeInterval = 300
            if let retryDate = Calendar.current.date(byAdding: .second, value: Int(retryDelay), to: Date()) {
                let request = BGProcessingTaskRequest(identifier: locationSyncTaskIdentifier)
                request.requiresNetworkConnectivity = true
                request.requiresExternalPower = false
                request.earliestBeginDate = retryDate

                try? BGTaskScheduler.shared.submit(request)
            }
        }
    }

    // MARK: - Maintenance Task

    private func scheduleMaintenance() {
        let request = BGProcessingTaskRequest(identifier: dailyMaintenanceTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true // Only when charging

        // Schedule for early morning (2 AM)
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 2
        components.minute = 0

        let earliestBeginDate = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime)!
        request.earliestBeginDate = earliestBeginDate

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✓ Maintenance task scheduled for \(earliestBeginDate)")
        } catch {
            print("✗ Failed to schedule maintenance task: \(error.localizedDescription)")
        }
    }

    private func handleMaintenance(task: BGTask) async {
        print("🔄 Daily maintenance started")

        // Perform maintenance tasks
        await performMaintenance()

        // Schedule next maintenance
        scheduleMaintenance()

        task.setTaskCompleted(success: true)
        print("✓ Daily maintenance completed")
    }

    // MARK: - Maintenance Tasks

    private func performMaintenance() async {
        // 1. Full health sync with error handling
        do {
            try await healthKitManager.syncRecentData()
        } catch {
            print("⚠️ Health sync failed during maintenance: \(error.localizedDescription)")
        }

        // 2. Try to flush offline queue
        do {
            try await flushOfflineQueue()
        } catch {
            print("⚠️ Failed to flush offline queue: \(error.localizedDescription)")
        }

        // 3. Verify server connectivity
        do {
            let healthy = try await APIClient.shared.checkServerHealth()
            if !healthy {
                print("⚠️ Server health check failed")
            }
        } catch {
            print("⚠️ Cannot reach server: \(error.localizedDescription)")
        }
    }

    private func flushOfflineQueue() async throws {
        let offlineQueue = OfflineQueue.shared
        let (pending, failed, maxRetries) = offlineQueue.getRetryStatus()

        print("🔄 Flushing offline queue: \(pending) pending, \(failed) failed")

        guard pending > 0 else {
            print("No pending records in offline queue")
            return
        }

        let recordsToSync = offlineQueue.peek(count: 100)
        let recordIDs = recordsToSync.map { $0.id }
        let healthRecords = recordsToSync.map { $0.record }

        do {
            let result = try await APIClient.shared.uploadHealthData(healthRecords)
            print("✓ Uploaded \(result.recordCount) queued records")
            offlineQueue.markSuccessful(for: recordIDs)
        } catch {
            print("✗ Failed to upload queued records: \(error.localizedDescription)")
            offlineQueue.incrementRetryCount(for: recordIDs, error: error)
            throw error
        }
    }
}

// MARK: - App Lifecycle Integration

extension LifeLensApp {
    func setupBackgroundTasks() {
        // Register background tasks when app launches
        BackgroundSyncManager.shared.registerBackgroundTasks()

        // Schedule background app refresh
        scheduleBackgroundAppRefresh()
    }

    private func scheduleBackgroundAppRefresh() {
        // Request more frequent background refresh (iOS may throttle)
        BGTaskScheduler.shared.getTask { [weak self] task in
            if let task = task {
                Task { @MainActor in
                    await self?.handleAppRefresh(task: task)
                }
            }
        }
    }

    private func handleAppRefresh(task: BGTask) async {
        print("🔄 Background app refresh")

        // Quick sync (limit time to avoid being terminated)
        await BackgroundSyncManager.shared.healthKitManager.manualSync()

        task.setTaskCompleted(success: true)
    }
}

// MARK: - Background Task Request (iOS 13+)

class BGProcessingTaskTask {
    let identifier: String
    let using: [String: Any]?
    let handler: (BGTask) -> Void

    init(identifier: String, using: [String: Any]? = nil, handler: @escaping (BGTask) -> Void) {
        self.identifier = identifier
        self.using = using
        self.handler = handler
    }
}

// MARK: - URLSession Background Upload

// MARK: - Location Data Models for API

struct LocationData: Codable {
    let device_id: String
    let location_type: String
    let latitude: Double?
    let longitude: Double?
    let place_name: String?
    let horizontal_accuracy: Double?
    let timestamp: Date

    init(from record: LocationRecord) {
        self.device_id = record.deviceID
        self.location_type = "gps"
        self.latitude = record.latitude
        self.longitude = record.longitude
        self.place_name = nil
        self.horizontal_accuracy = record.accuracy
        self.timestamp = record.timestamp
    }

    init(from visit: VisitRecord) {
        self.device_id = visit.deviceID
        self.location_type = "visit"
        self.latitude = visit.latitude
        self.longitude = visit.longitude
        self.place_name = visit.placeType
        self.horizontal_accuracy = nil
        self.timestamp = visit.arrivalDate
    }
}

struct LocationDataBatch: Codable {
    let records: [LocationData]
}

// MARK: - APIClient Extension

extension APIClient {
    /// Upload location data batch to server with retry logic
    func uploadLocationBatch(_ records: [LocationRecord], retryCount: Int = 0) async throws -> ServerResponse {
        guard !records.isEmpty else {
            throw APIError.noData
        }

        let locationDataRecords = records.map { LocationData(from: $0) }
        let batch = LocationDataBatch(records: locationDataRecords)

        var request = createRequest(endpoint: "/api/v1/ingest/location/batch", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(batch)

        do {
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
        } catch {
            // Check if we should retry
            if retryCount < OfflineQueue.shared.getRetryStatus().maxRetries {
                let delay = OfflineQueue.shared.calculateBackoffDelay(retryCount: retryCount)

                print("Location upload failed (attempt \(retryCount + 1)), retrying in \(Int(delay))s: \(error.localizedDescription)")

                // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Retry
                return try await uploadLocationBatch(records, retryCount: retryCount + 1)
            } else {
                // Max retries exceeded
                print("Location upload failed after \(retryCount) attempts: \(error.localizedDescription)")
                throw error
            }
        }
    }

    /// Upload visit data batch to server with retry logic
    func uploadVisitBatch(_ records: [VisitRecord], retryCount: Int = 0) async throws -> ServerResponse {
        guard !records.isEmpty else {
            throw APIError.noData
        }

        let locationDataRecords = records.map { LocationData(from: $0) }
        let batch = LocationDataBatch(records: locationDataRecords)

        var request = createRequest(endpoint: "/api/v1/ingest/location/batch", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(batch)

        do {
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
        } catch {
            // Check if we should retry
            if retryCount < OfflineQueue.shared.getRetryStatus().maxRetries {
                let delay = OfflineQueue.shared.calculateBackoffDelay(retryCount: retryCount)

                print("Visit upload failed (attempt \(retryCount + 1)), retrying in \(Int(delay))s: \(error.localizedDescription)")

                // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Retry
                return try await uploadVisitBatch(records, retryCount: retryCount + 1)
            } else {
                // Max retries exceeded
                print("Visit upload failed after \(retryCount) attempts: \(error.localizedDescription)")
                throw error
            }
        }
    }
}
