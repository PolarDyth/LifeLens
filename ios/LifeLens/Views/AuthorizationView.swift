import SwiftUI

// MARK: - Authorization View

struct AuthorizationView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var isAuthorizing = false
    @State private var showSettings = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App Icon
            Image(systemName: "heart.fill")
                .font(.system(size: 80))
                .foregroundStyle(.red.gradient)
                .shadow(radius: 10)

            // Title
            VStack(spacing: 8) {
                Text("LifeLens")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Automated Life Tracking")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Description
            VStack(spacing: 16) {
                InfoRow(
                    icon: "figure.walk",
                    title: "Health Data",
                    description: "Steps, heart rate, sleep, and workouts from your iPhone and Apple Watch"
                )

                InfoRow(
                    icon: "location.fill",
                    title: "Location",
                    description: "Track places you visit (optional, can be enabled later)"
                )

                InfoRow(
                    icon: "lock.fill",
                    title: "Privacy First",
                    description: "All data stored on your home server. No third-party services."
                )

                InfoRow(
                    icon: "checkmark.circle.fill",
                    title: "Fully Automated",
                    description: "Background sync means no manual data entry required"
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Error message
            if let error = errorMessage {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }

            // Authorize button
            Button(action: authorize) {
                ZStack {
                    if isAuthorizing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Authorize HealthKit")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isAuthorizing ? Color.gray : Color.red)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(isAuthorizing)
            .padding(.horizontal, 32)

            // Settings button
            Button("Configure Server Settings") {
                showSettings = true
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom, 32)

            // Privacy note
            Text("LifeLens requires HealthKit authorization to function. Your data never leaves your home server.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Actions

    private func authorize() {
        isAuthorizing = true
        errorMessage = nil

        Task {
            do {
                try await healthKitManager.requestAuthorization()

                await MainActor.run {
                    isAuthorizing = false
                }
            } catch {
                await MainActor.run {
                    isAuthorizing = false
                    if case HealthKitError.authorizationDenied = error {
                        errorMessage = "HealthKit authorization denied. Please enable in Settings > Health > LifeLens"
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.red)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("server_url") private var serverURL = "http://localhost:8000"
    @AppStorage("api_key") private var apiKey = "test-key"

    @State private var tempServerURL = ""
    @State private var tempAPIKey = ""
    @State private var isTesting = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Configuration") {
                    TextField("Server URL", text: $tempServerURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    SecureField("API Key", text: $tempAPIKey)
                        .textContentType(.password)
                } header: {
                    Text("Connection Settings")
                } footer: {
                    Text("Enter your home server URL and API key. These will be used to sync your health data.")
                }

                Section {
                    Button(action: testConnection) {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(showSuccess ? .green : .gray)
                            }
                            Text("Test Connection")
                        }
                    }
                    .disabled(isTesting || tempServerURL.isEmpty)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        tempServerURL = serverURL
                        tempAPIKey = apiKey
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        serverURL = tempServerURL
                        apiKey = tempAPIKey
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                tempServerURL = serverURL
                tempAPIKey = apiKey
            }
        }
    }

    private func testConnection() {
        isTesting = true
        showSuccess = false

        Task {
            defer {
                isTesting = false
            }

            // Temporarily update API client settings
            UserDefaults.standard.set(tempServerURL, forKey: "server_url")
            UserDefaults.standard.set(tempAPIKey, forKey: "api_key")

            do {
                let success = try await APIClient.shared.checkServerHealth()

                await MainActor.run {
                    showSuccess = success
                }
            } catch {
                print("Connection test failed: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AuthorizationView()
        .environmentObject(HealthKitManager.shared)
}
