import Foundation

// MARK: - Health Data Types

enum HealthDataType: String, CaseIterable {
    case steps = "steps"
    case heartRate = "heart_rate"
    case heartRateVariability = "heart_rate_variability"
    case activeEnergy = "active_energy"
    case restingHeartRate = "resting_heart_rate"
    case sleepAnalysis = "sleep_analysis"
    case workout = "workout"
    case distance = "distance"
}

// MARK: - Health Data Record

struct HealthDataRecord: Codable {
    let deviceID: String
    let dataType: HealthDataType
    let value: Double
    let unit: String
    let timestamp: Date
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case dataType = "data_type"
        case value
        case unit
        case timestamp
        case metadata
    }

    init(deviceID: String, dataType: HealthDataType, value: Double, unit: String, timestamp: Date, metadata: [String: String]? = nil) {
        self.deviceID = deviceID
        self.dataType = dataType
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Batch Upload Request

struct HealthDataBatch: Codable {
    let records: [HealthDataRecord]
}

// MARK: - Server Response

struct ServerResponse: Codable {
    let message: String
    let recordCount: Int
}

// MARK: - Sync Status

struct SyncStatus: Codable {
    let lastSync: Date
    let pendingRecords: Int
    let lastError: String?

    var lastSyncFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
}
