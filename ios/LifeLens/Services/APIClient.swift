import Foundation

// MARK: - API Client

class APIClient {
    // MARK: - Properties

    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private var serverURL: URL {
        // TODO: Load from user settings
        guard let url = URL(string: UserDefaults.standard.string(forKey: "server_url") ?? "http://localhost:8000") else {
            fatalError("Invalid server URL")
        }
        return url
    }

    private var apiKey: String {
        // TODO: Load from user settings
        return UserDefaults.standard.string(forKey: "api_key") ?? "test-key"
    }

    private let deviceID: String

    // MARK: - Initialization

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601

        self.deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios-device"
    }

    // MARK: - Public Methods

    /// Upload health data batch to server with retry logic
    func uploadHealthData(_ records: [HealthDataRecord], retryCount: Int = 0) async throws -> ServerResponse {
        guard !records.isEmpty else {
            throw APIError.noData
        }

        let batch = HealthDataBatch(records: records)

        var request = createRequest(endpoint: "/api/v1/ingest/health/batch", method: "POST")
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

                print("Upload failed (attempt \(retryCount + 1)), retrying in \(Int(delay))s: \(error.localizedDescription)")

                // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Retry
                return try await uploadHealthData(records, retryCount: retryCount + 1)
            } else {
                // Max retries exceeded
                print("Upload failed after \(retryCount) attempts: \(error.localizedDescription)")
                throw error
            }
        }
    }

    /// Check server health
    func checkServerHealth() async throws -> Bool {
        var request = createRequest(endpoint: "/health", method: "GET")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        return httpResponse.statusCode == 200
    }

    // MARK: - Private Methods

    private func createRequest(endpoint: String, method: String) -> URLRequest {
        var urlComponents = URLComponents(url: serverURL, resolvingAgainstBaseURL: true)!
        urlComponents.path = endpoint

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("LifeLens-iOS/1.0", forHTTPHeaderField: "User-Agent")

        return request
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case noData
    case invalidResponse
    case unauthorized
    case validationError(String)
    case serverError(Int)
    case unknownError(Int)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noData:
            return "No data to upload"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Unauthorized - Check API key"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .serverError(let code):
            return "Server error: \(code)"
        case .unknownError(let code):
            return "Unknown error (code: \(code))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Offline Queue

class OfflineQueue {
    static let shared = OfflineQueue()

    private let queueURL: URL
    private var queue: [QueuedRecord] = []

    // Retry configuration
    private let MAX_RETRY_ATTEMPTS = 10
    private let BASE_DELAY_SECONDS: TimeInterval = 60 // 1 minute
    private let MAX_DELAY_SECONDS: TimeInterval = 3600 // 1 hour

    private init() {
        let fileManager = FileManager.default
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        queueURL = documentsDir.appendingPathComponent("offline_queue.json")

        loadQueue()
    }

    // MARK: - Public Methods

    func add(_ records: [HealthDataRecord]) {
        let queuedRecords = records.map { record in
            QueuedRecord(
                id: UUID().uuidString,
                record: record,
                timestamp: Date(),
                retryCount: 0,
                lastError: nil
            )
        }

        queue.append(contentsOf: queuedRecords)
        saveQueue()

        // Limit queue size to prevent excessive storage
        if queue.count > 10000 {
            queue = Array(queue.suffix(10000))
        }

        print("Added \(records.count) records to offline queue (size: \(queue.count))")
    }

    func peek(count: Int = 100) -> [QueuedRecord] {
        // Return records that haven't exceeded max retry attempts
        return queue.filter { $0.retryCount < MAX_RETRY_ATTEMPTS }
            .prefix(count)
            .map { $0 }
    }

    func remove(count: Int) {
        guard count > 0 else { return }

        let removeCount = min(count, queue.count)
        queue.removeFirst(removeCount)
        saveQueue()
    }

    func clear() {
        queue.removeAll()
        saveQueue()
    }

    var size: Int {
        return queue.count
    }

    func getRetryStatus() -> (pending: Int, failed: Int, maxRetries: Int) {
        let pending = queue.filter { $0.retryCount < MAX_RETRY_ATTEMPTS }.count
        let failed = queue.filter { $0.retryCount >= MAX_RETRY_ATTEMPTS }.count
        return (pending, failed, MAX_RETRY_ATTEMPTS)
    }

    // MARK: - Retry Logic

    func incrementRetryCount(for ids: [String], error: Error) {
        let errorMessage = error.localizedDescription
        for id in ids {
            if let index = queue.firstIndex(where: { $0.id == id }) {
                queue[index].retryCount += 1
                queue[index].lastError = errorMessage
            }
        }
        saveQueue()
    }

    func markSuccessful(for ids: [String]) {
        let idsSet = Set(ids)
        queue.removeAll { idsSet.contains($0.id) }
        saveQueue()
    }

    func calculateBackoffDelay(retryCount: Int) -> TimeInterval {
        let delay = BASE_DELAY_SECONDS * pow(2, Double(retryCount))
        return min(delay, MAX_DELAY_SECONDS)
    }

    // MARK: - Private Methods

    private func loadQueue() {
        guard let data = try? Data(contentsOf: queueURL) else {
            print("No existing offline queue found")
            return
        }

        do {
            queue = try JSONDecoder().decode([QueuedRecord].self, from: data)
            print("Loaded \(queue.count) records from offline queue")
        } catch {
            print("Failed to load offline queue: \(error)")
            queue = []
        }
    }

    private func saveQueue() {
        guard let data = try? JSONEncoder().encode(queue) else {
            print("Failed to encode offline queue")
            return
        }

        do {
            try data.write(to: queueURL)
        } catch {
            print("Failed to save offline queue: \(error)")
        }
    }
}

// MARK: - Queued Record Model

struct QueuedRecord: Codable {
    let id: String
    let record: HealthDataRecord
    let timestamp: Date
    var retryCount: Int
    var lastError: String?
}
