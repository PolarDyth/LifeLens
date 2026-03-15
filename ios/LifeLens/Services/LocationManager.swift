import Foundation
import CoreLocation
import HealthKit

// MARK: - Location Manager

@MainActor
class LocationManager: NSObject, ObservableObject {
    // MARK: - Properties

    static let shared = LocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var trackingMode: TrackingMode = .batterySaver
    @Published var currentLocation: CLLocation?
    @Published var lastSync: Date?

    private let locationManager = CLLocationManager()
    private let apiClient = APIClient.shared
    private let offlineQueue = OfflineQueue.shared

    private var activeTracking = false

    // MARK: - Tracking Mode

    enum TrackingMode: String, CaseIterable {
        case batterySaver = "battery_saver"
        case accuracy = "accuracy"

        var displayName: String {
            switch self {
            case .batterySaver:
                return "Battery Saver"
            case .accuracy:
                return "High Accuracy"
            }
        }

        var description: String {
            switch self {
            case .batterySaver:
                return "Significant location changes only (~500m-1km). Minimal battery impact."
            case .accuracy:
                return "Active GPS when app is open. Higher battery usage."
            }
        }
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        setupLocationManager()
    }

    // MARK: - Setup

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // meters
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = true

        // Load saved tracking mode
        if let savedMode = UserDefaults.standard.string(forKey: "tracking_mode"),
           let mode = TrackingMode(rawValue: savedMode) {
            trackingMode = mode
        }
    }

    // MARK: - Authorization

    func requestAuthorization() {
        // Request "Always" authorization for background tracking
        locationManager.requestAlwaysAuthorization()
    }

    private func updateAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus

        // Start tracking if authorized
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            startTracking()
        }
    }

    // MARK: - Tracking Control

    func startTracking() {
        guard !activeTracking else { return }
        activeTracking = true

        switch trackingMode {
        case .batterySaver:
            // Significant location changes (most battery-efficient)
            locationManager.startMonitoringSignificantLocationChanges()

            // Also monitor visits for place detection
            locationManager.startMonitoringVisits()

            print("✓ Started battery saver location tracking")

        case .accuracy:
            // Active GPS tracking (higher battery usage)
            locationManager.startUpdatingLocation()

            print("✓ Started high accuracy location tracking")
        }
    }

    func stopTracking() {
        activeTracking = false

        switch trackingMode {
        case .batterySaver:
            locationManager.stopMonitoringSignificantLocationChanges()
            locationManager.stopMonitoringVisits()

        case .accuracy:
            locationManager.stopUpdatingLocation()
        }

        print("✓ Stopped location tracking")
    }

    func setTrackingMode(_ mode: TrackingMode) {
        stopTracking()
        trackingMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "tracking_mode")

        if activeTracking {
            startTracking()
        }
    }

    // MARK: - Location Data Upload

    private func uploadLocation(_ location: CLLocation) async {
        let record = LocationRecord(
            deviceID: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            altitude: location.altitude,
            timestamp: location.timestamp,
            metadata: [
                "speed": "\(location.speed)",
                "course": "\(location.course)"
            ]
        )

        do {
            let response = try await apiClient.uploadLocation([record])
            print("✓ Uploaded location to server")

            await MainActor.run {
                self.lastSync = Date()
            }
        } catch {
            print("✗ Failed to upload location: \(error.localizedDescription)")
            // Add to offline queue
            offlineQueue.addLocation(record)
        }
    }

    private func uploadVisit(_ visit: CLVisit) async {
        let record = VisitRecord(
            deviceID: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            latitude: visit.coordinate.latitude,
            longitude: visit.coordinate.longitude,
            arrivalDate: visit.arrivalDate,
            departureDate: visit.departureDate,
            placeType: "visit"
        )

        do {
            let response = try await apiClient.uploadVisit([record])
            print("✓ Uploaded visit to server")

            await MainActor.run {
                self.lastSync = Date()
            }
        } catch {
            print("✗ Failed to upload visit: \(error.localizedDescription)")
            // Add to offline queue
            offlineQueue.addVisit(record)
        }
    }

    // MARK: - Manual Sync

    func syncPendingLocations() async {
        // TODO: Implement sync of offline queue
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        print("📍 Location update: \(location.coordinate.latitude), \(location.coordinate.longitude)")

        Task {
            await uploadLocation(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        print("🏠 Visit detected: \(visit.coordinate.latitude), \(visit.coordinate.longitude)")

        Task {
            await uploadVisit(visit)
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 Location authorization changed: \(status.rawValue)")

        Task { @MainActor in
            updateAuthorizationStatus()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Location error: \(error.localizedDescription)")

        let locationError = error as? CLError

        switch locationError?.code {
        case .denied:
            print("📍 Location access denied")
        case .locationUnknown:
            print("📍 Location unknown (temporary)")
        case .network:
            print("📍 Network error - location unavailable")
        default:
            print("📍 Unknown location error")
        }
    }
}

// MARK: - Location Data Models

struct LocationRecord: Codable {
    let deviceID: String
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let altitude: Double
    let timestamp: Date
    let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case latitude
        case longitude
        case accuracy
        case altitude
        case timestamp
        case metadata
    }
}

struct VisitRecord: Codable {
    let deviceID: String
    let latitude: Double
    let longitude: Double
    let arrivalDate: Date
    let departureDate: Date?
    let placeType: String

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case latitude
        case longitude
        case arrivalDate = "arrival_date"
        case departureDate = "departure_date"
        case placeType = "place_type"
    }
}

// MARK: - Offline Queue Extension

extension OfflineQueue {
    func addLocation(_ record: LocationRecord) {
        // Save to file-based queue
        // TODO: Implement
    }

    func addVisit(_ record: VisitRecord) {
        // Save to file-based queue
        // TODO: Implement
    }
}
