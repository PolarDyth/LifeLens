import Foundation
import CallKit
import Contacts

// MARK: - Call Manager

@MainActor
class CallManager: NSObject, ObservableObject {
    // MARK: - Properties

    static let shared = CallManager()

    @Published var incomingCallsDetected = 0
    @Published var lastSync: Date?

    private let callObserver = CXCallObserver()
    private let apiClient = APIClient.shared
    private var activeCalls: [String: Date] = [:]

    // MARK: - Initialization

    private override init() {
        super.init()
        setupCallObserver()
    }

    // MARK: - Call Observer Setup

    private func setupCallObserver() {
        callObserver.setDelegate(self, queue: nil)
        print("✓ Call observer configured")
    }

    // MARK: - Call History Fetch

    func fetchCallHistory() async {
        guard #available(iOS 14.0, *) else {
            print("Call history fetch requires iOS 14+")
            return
        }

        let fetchDescriptor = CNCallRecord.fetchDescriptor()
        fetchDescriptor.sortOrder = CNCallRecordSortOrder.dateDescending

        do {
            let callRecords = try await CNContactStore.shared.unifiedContacts(
                matchingPredicate: CNContact.predicateForContacts(withNoName: false),
                keysToFetch: [CNCallRecord.descriptor()]
            )

            // Extract call records
            var records: [CallMetadata] = []

            for contact in callRecords {
                if let callRecords = contact.callRecords {
                    for callRecord in callRecords {
                        let metadata = CallMetadata(
                            deviceID: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
                            callType: callRecord.callType == .incoming ? "incoming" : "outgoing",
                            duration: callRecord.duration,
                            timestamp: callRecord.date,
                            contactIdentifier: callRecord.contactIdentifier ?? "unknown",
                            phoneNumber: callRecord.phoneNumber?.stringValue ?? "unknown"
                        )
                        records.append(metadata)
                    }
                }
            }

            // Upload to server
            if !records.isEmpty {
                try await apiClient.uploadCallMetadata(records)
                print("✓ Uploaded \(records.count) call records")

                await MainActor.run {
                    self.lastSync = Date()
                }
            }
        } catch {
            print("✗ Failed to fetch call history: \(error.localizedDescription)")
        }
    }
}

// MARK: - CXCallObserverDelegate

extension CallManager: CXCallObserverDelegate {
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        let callUUID = call.UUID.uuidString

        if call.hasEnded {
            // Call ended
            if let startTime = activeCalls[callUUID] {
                let duration = Date().timeIntervalSince(startTime)
                activeCalls.removeValue(forKey: callUUID)

                Task {
                    await uploadCall(
                        direction: .incoming, // CallKit doesn't distinguish direction in observer
                        duration: duration,
                        timestamp: startTime
                    )
                }
            }
        } else if call.hasConnected && !call.isOnHold {
            // Call connected (answered)
            if !activeCalls.keys.contains(callUUID) {
                activeCalls[callUUID] = Date()
            }
        } else if call.isOutgoing {
            // Outgoing call started
            activeCalls[callUUID] = Date()
        }
    }
}

// MARK: - Call Upload

extension CallManager {
    private func uploadCall(
        direction: CallDirection,
        duration: TimeInterval,
        timestamp: Date
    ) async {
        let metadata = CallMetadata(
            deviceID: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            callType: direction == .incoming ? "incoming" : "outgoing",
            duration: duration,
            timestamp: timestamp,
            contactIdentifier: "unknown",
            phoneNumber: "unknown"
        )

        do {
            try await apiClient.uploadCallMetadata([metadata])
            print("✓ Uploaded call metadata")

            await MainActor.run {
                self.incomingCallsDetected += 1
                self.lastSync = Date()
            }
        } catch {
            print("✗ Failed to upload call metadata: \(error.localizedDescription)")
        }
    }
}

// MARK: - Call Data Models

struct CallMetadata: Codable {
    let deviceID: String
    let callType: String // "incoming" or "outgoing"
    let duration: TimeInterval // seconds
    let timestamp: Date
    let contactIdentifier: String
    let phoneNumber: String

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case callType = "call_type"
        case duration
        case timestamp
        case contactIdentifier = "contact_identifier"
        case phoneNumber = "phone_number"
    }
}

enum CallDirection {
    case incoming
    case outgoing
}

// MARK: - API Client Extension

extension APIClient {
    func uploadCallMetadata(_ records: [CallMetadata]) async throws -> ServerResponse {
        guard !records.isEmpty else {
            throw APIError.noData
        }

        var request = createRequest(endpoint: "/api/v1/ingest/communication/batch", method: "POST")
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
