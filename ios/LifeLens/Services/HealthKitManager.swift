import Foundation
import HealthKit

// MARK: - HealthKit Manager

@MainActor
class HealthKitManager: ObservableObject {
    // MARK: - Properties

    static let shared = HealthKitManager()

    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var lastSync: Date?
    @Published var pendingRecords = 0

    private let healthStore = HKHealthStore()
    private let apiClient = APIClient.shared
    private let offlineQueue = OfflineQueue.shared

    private var observerQueries: [HKObserverQuery] = []

    // MARK: - Health Data Types to Read

    private lazy var healthDataTypes: Set<HKSampleType> = {
        var types = Set<HKSampleType>()

        // Steps
        types.insert(HKObjectType.quantityType(forIdentifier: .stepCount)!)

        // Heart Rate
        types.insert(HKObjectType.quantityType(forIdentifier: .heartRate)!)

        // Heart Rate Variability
        types.insert(HKObjectType.quantityType(forIdentifier: .heartRateVariability)!)

        // Active Energy
        types.insert(HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!)

        // Resting Heart Rate
        types.insert(HKObjectType.quantityType(forIdentifier: .restingHeartRate)!)

        // Sleep Analysis
        types.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)

        // Workouts
        types.insert(HKObjectType.workoutType())

        // Distance
        types.insert(HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!)

        return types
    }()

    // MARK: - Initialization

    private init() {
        // Load last sync time from UserDefaults
        if let timestamp = UserDefaults.standard.object(forKey: "last_sync") as? Date {
            self.lastSync = timestamp
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        // Request authorization
        try await healthStore.requestAuthorization(toShare: nil, read: healthDataTypes)

        // Check authorization status for each type
        await updateAuthorizationStatus()

        // If authorized, set up background delivery
        if isAuthorized {
            await setupBackgroundDelivery()
            // Perform initial sync
            await syncRecentData()
        }
    }

    private func updateAuthorizationStatus async {
        // Check authorization status for a key data type (steps)
        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let status = healthStore.authorizationStatus(for: stepsType)

        await MainActor.run {
            self.authorizationStatus = status
            self.isAuthorized = (status == .sharingAuthorized)
        }
    }

    // MARK: - Background Delivery

    func setupBackgroundDelivery() async {
        for sampleType in healthDataTypes {
            // Enable background delivery for each type
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] query, completionHandler, error in
                if let error = error {
                    print("Observer query error: \(error.localizedDescription)")
                    completionHandler()
                    return
                }

                Task { @MainActor in
                    await self?.handleNewData(for: sampleType)
                    completionHandler()
                }
            }

            healthStore.execute(query)
            observerQueries.append(query)

            // Enable background delivery
            healthStore.enableBackgroundDelivery(
                for: sampleType,
                frequency: .hourly,
                withCompletion: { success, error in
                    if !success {
                        print("Failed to enable background delivery for \(sampleType): \(error?.localizedDescription ?? "Unknown error")")
                    } else {
                        print("✓ Background delivery enabled for \(sampleType)")
                    }
                }
            )
        }
    }

    private func handleNewData(for sampleType: HKSampleType) async {
        print("New data detected for: \(sampleType.identifier)")

        // Query and sync the new data
        await syncData(for: sampleType)
    }

    // MARK: - Data Sync

    func syncRecentData() async {
        let now = Date()
        let startTime = lastSync?.addingTimeInterval(-3600) ?? now.addingTimeInterval(-86400) // Last sync or 24h ago

        for sampleType in healthDataTypes {
            await syncData(for: sampleType, startTime: startTime, endTime: now)
        }

        await updateLastSync()
    }

    private func syncData(for sampleType: HKSampleType, startTime: Date? = nil, endTime: Date = Date()) async {
        let predicate: NSPredicate?
        if let startTime = startTime {
            predicate = HKQuery.predicateForSamples(withStart: startTime, end: endTime, options: .strictStartDate)
        } else {
            predicate = nil
        }

        let records = await fetchData(for: sampleType, predicate: predicate)

        guard !records.isEmpty else {
            return
        }

        print("Syncing \(records.count) records for \(sampleType.identifier)")

        // Upload to server
        do {
            let result = try await apiClient.uploadHealthData(records)
            print("✓ Uploaded \(result.recordCount) records to server")

            await MainActor.run {
                pendingRecords = offlineQueue.size
            }
        } catch {
            print("✗ Upload failed: \(error.localizedDescription)")
            // Add to offline queue
            offlineQueue.add(records)

            await MainActor.run {
                pendingRecords = offlineQueue.size
            }
        }
    }

    private func fetchData(for sampleType: HKSampleType, predicate: NSPredicate?) async -> [HealthDataRecord] {
        var records: [HealthDataRecord] = []

        if let quantityType = sampleType as? HKQuantityType {
            records = await fetchQuantityData(type: quantityType, predicate: predicate)
        } else if let categoryType = sampleType as? HKCategoryType {
            records = await fetchCategoryData(type: categoryType, predicate: predicate)
        } else if let workoutType = sampleType as? HKWorkoutType {
            records = await fetchWorkoutData(predicate: predicate)
        }

        return records
    }

    private func fetchQuantityData(type: HKQuantityType, predicate: NSPredicate?) async -> [HealthDataRecord] {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { query, samples, error in
                if let error = error {
                    print("Error fetching \(type.identifier): \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let records = samples.compactMap { sample -> HealthDataRecord? in
                    self.convertQuantitySample(sample, type: type)
                }

                continuation.resume(returning: records)
            }

            healthStore.execute(query)
        }
    }

    private func fetchCategoryData(type: HKCategoryType, predicate: NSPredicate?) async -> [HealthDataRecord] {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { query, samples, error in
                if let error = error {
                    print("Error fetching \(type.identifier): \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let records = samples.compactMap { sample -> HealthDataRecord? in
                    self.convertCategorySample(sample, type: type)
                }

                continuation.resume(returning: records)
            }

            healthStore.execute(query)
        }
    }

    private func fetchWorkoutData(predicate: NSPredicate?) async -> [HealthDataRecord] {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { query, samples, error in
                if let error = error {
                    print("Error fetching workouts: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                guard let samples = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                let records = samples.compactMap { sample -> HealthDataRecord? in
                    self.convertWorkout(sample)
                }

                continuation.resume(returning: records)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Data Conversion

    private func convertQuantitySample(_ sample: HKQuantitySample, type: HKQuantityType) -> HealthDataRecord? {
        let dataType: HealthDataType?
        let unit: HKUnit
        let value: Double

        switch type.identifier {
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            dataType = .steps
            unit = HKUnit.count()
            value = sample.quantity.doubleValue(for: unit)

        case HKQuantityTypeIdentifier.heartRate.rawValue:
            dataType = .heartRate
            unit = HKUnit(from: "count/min")
            value = sample.quantity.doubleValue(for: unit)

        case HKQuantityTypeIdentifier.heartRateVariability.rawValue:
            dataType = .heartRateVariability
            unit = HKUnit.secondUnit(with: .milli)
            value = sample.quantity.doubleValue(for: unit)

        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            dataType = .activeEnergy
            unit = HKUnit.kilocalorie()
            value = sample.quantity.doubleValue(for: unit)

        case HKQuantityTypeIdentifier.restingHeartRate.rawValue:
            dataType = .restingHeartRate
            unit = HKUnit(from: "count/min")
            value = sample.quantity.doubleValue(for: unit)

        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
            dataType = .distance
            unit = HKUnit.meter()
            value = sample.quantity.doubleValue(for: unit)

        default:
            return nil
        }

        guard let dataType = dataType else {
            return nil
        }

        return HealthDataRecord(
            deviceID: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            dataType: dataType,
            value: value,
            unit: unit.unitString,
            timestamp: sample.startDate,
            metadata: sample.metadata?.mapValues { "\($0)" }
        )
    }

    private func convertCategorySample(_ sample: HKCategorySample, type: HKCategoryType) -> HealthDataRecord? {
        guard type.identifier == HKCategoryTypeIdentifier.sleepAnalysis else {
            return nil
        }

        // Convert sleep category to numeric value (asleep = 1, inBed = 2)
        let sleepValue: Double
        let metadata: [String: String] = [
            "sleep_category": "\(sample.value)"
        ]

        switch sample.value {
        case HKCategoryValueSleepAnalysis.inBed:
            sleepValue = 0
        case HKCategoryValueSleepAnalysis.asleep:
            sleepValue = 1
        case HKCategoryValueSleepAnalysis.awake:
            sleepValue = 2
        default:
            sleepValue = -1
        }

        let duration = sample.endDate.timeIntervalSince(sample.startDate)

        return HealthDataRecord(
            deviceID: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            dataType: .sleepAnalysis,
            value: sleepValue,
            unit: "min",
            timestamp: sample.startDate,
            metadata: metadata
        )
    }

    private func convertWorkout(_ workout: HKWorkout) -> HealthDataRecord? {
        let activityType: String
        switch workout.workoutActivityType {
        case .running:
            activityType = "running"
        case .walking:
            activityType = "walking"
        case .cycling:
            activityType = "cycling"
        case .swimming:
            activityType = "swimming"
        case .hiking:
            activityType = "hiking"
        case .yoga:
            activityType = "yoga"
        case .functionalStrengthTraining:
            activityType = "strength_training"
        case .traditionalStrengthTraining:
            activityType = "strength_training"
        case .crossTraining:
            activityType = "cross_training"
        case .mixedCardio:
            activityType = "mixed_cardio"
        case .highIntensityIntervalTraining:
            activityType = "hiit"
        default:
            activityType = "other"
        }

        let duration = workout.duration / 60 // Convert to minutes

        return HealthDataRecord(
            deviceID: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            dataType: .workout,
            value: duration,
            unit: "min",
            timestamp: workout.startDate,
            metadata: [
                "workout_type": activityType,
                "duration": "\(workout.duration)",
                "energy": "\(workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)"
            ]
        )
    }

    // MARK: - Manual Sync

    func manualSync() async {
        await syncRecentData()

        // Try to upload offline queue
        let queuedRecords = offlineQueue.peek(count: 100)
        guard !queuedRecords.isEmpty else {
            return
        }

        print("Uploading \(queuedRecords.count) queued records")

        do {
            let result = try await apiClient.uploadHealthData(queuedRecords)
            print("✓ Uploaded \(result.recordCount) queued records")
            offlineQueue.remove(count: queuedRecords.count)

            await MainActor.run {
                pendingRecords = offlineQueue.size
            }
        } catch {
            print("✗ Failed to upload queued records: \(error.localizedDescription)")
        }
    }

    // MARK: - Sync Status

    private func updateLastSync() async {
        let now = Date()
        await MainActor.run {
            self.lastSync = now
            UserDefaults.standard.set(now, forKey: "last_sync")
        }
    }
}

// MARK: - HealthKit Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case dataNotAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .dataNotAvailable:
            return "Requested health data is not available"
        }
    }
}
