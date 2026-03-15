# LifeLens iOS App

Automated health and location tracking for iPhone and Apple Watch.

## Features

- **Health Data Collection**: Automatically syncs steps, heart rate, HRV, sleep, and workouts via HealthKit
- **Apple Watch Support**: Reads Watch data through iPhone HealthKit
- **Background Sync**: Data uploads to your home server automatically
- **Privacy-First**: All data stored on your home server, no third-party services
- **Offline Queue**: Preserves data when server is unreachable

## Requirements

- iPhone with iOS 17+
- Xcode 15+ (for building)
- Free Apple ID (no developer program required)
- Apple Watch (optional, for additional health metrics)

## Setup Instructions

### 1. Open in Xcode

```bash
cd ios
open LifeLens.xcodeproj  # or double-click in Finder
```

### 2. Configure Capabilities

In Xcode, select the **LifeLens** target and go to **Signing & Capabilities**:

1. **HealthKit**: Click "+ Capability" → Add "HealthKit"
2. **Background Modes**: Click "+ Capability" → Add "Background Modes"
   - ✓ Background processing
   - ✓ Location updates (for Task 8)

### 3. Set Your Team

In **Signing & Capabilities** → **Team**:
- Select your personal team (free Apple ID)
- Xcode will automatically provision the app

### 4. Configure Server

Before building, configure your home server URL:

1. Run the app on your iPhone or simulator
2. When prompted, tap "Configure Server Settings"
3. Enter your home server URL (e.g., `http://192.168.1.100:8000`)
4. Enter your API key (default: `test-key`)
5. Tap "Test Connection" to verify
6. Tap "Save"

### 5. Build and Install

**For Simulator:**
```bash
# In Xcode, press ⌘R or click Run
# Or via command line:
xcodebuild -scheme LifeLens -destination 'platform=iOS Simulator,name=iPhone 15' build
```

**For iPhone:**
1. Connect iPhone to Mac via USB
2. Trust the computer on your iPhone
3. In Xcode, select your iPhone as the destination
4. Press ⌘R or click Run
5. On your iPhone: **Settings → General → VPN & Device Management → Developer App** → Trust your Apple ID

### 6. Grant Permissions

On first launch:
1. Tap "Authorize HealthKit"
2. Review the data types LifeLens wants to read
3. Tap "Turn All Categories On"
4. Tap "Allow"
5. When prompted for location permission, tap "Always Allow" (for background tracking)

### 7. Verify Data Collection

1. Walk around to generate step data
2. Open LifeLens → Dashboard
3. Tap "Sync Now"
4. Check server logs: `docker-compose logs -f server`

## Known Limitations

### 7-Day Provisioning Expiration

**Issue**: Free Apple ID provisioning expires after 7 days.

**Solution**: Rebuild the app before expiry. Use the automated script:
```bash
cd scripts
./ios-rebuild.sh check   # Check days until expiry
./ios-rebuild.sh rebuild  # Rebuild and reinstall
```

**Manual Rebuild**:
```bash
cd ios
rm -rf ~/Library/Developer/Xcode/DerivedData/LifeLens-*
xcodebuild clean build -scheme LifeLens
# Then reinstall to iPhone
```

### Location Tracking Granularity

**Issue**: `significantLocationChanges` triggers on cell tower changes (~500m-1km), not continuous GPS.

**Impact**:
- Short trips (<1km) may not be captured
- Urban movement within same cell area may not update
- Not suitable for tracking short walks or detailed routes

**Reason**: This is a battery optimization. Continuous GPS would drain battery in 2-3 hours.

**Solutions**:
- Use "High Accuracy" mode in Settings when app is open (active GPS, higher battery)
- Accept the limitation for background tracking (Battery Saver mode)
- Manual location update: Open app → Location tab → Pull to refresh

### HealthKit Authorization

If you accidentally deny HealthKit permission:
1. iPhone Settings → Health → Data Access & Devices
2. Find LifeLens
3. Tap "Turn All Categories On"

### Background Sync Limits

iOS limits background execution. Data may be delayed up to 30 minutes depending on:
- System conditions (battery, network)
- Background app refresh priority
- iOS scheduling

**Force Sync**: Open LifeLens → Dashboard → Pull to refresh or tap "Sync Now"

### Location Permission Required for Background Tracking

**Issue**: Location features require "Always" permission for background tracking.

**Solution**:
1. iPhone Settings → Privacy & Security → Location Services
2. Find LifeLens
3. Change to "Always"
4. Enable "Precise Location" for better accuracy

### Location Tracking (Task 8)

Location features require:
- "Always" location permission
- Background location access
- Significant location changes (not continuous GPS for battery life)

## Data Types Collected

| Data Type | Source | Unit | Notes |
|-----------|--------|------|-------|
| Steps | iPhone/Watch | count | Automatic |
| Heart Rate | Watch only | bpm | Background delivery |
| HRV | Watch only | ms | Requires Watch |
| Active Energy | iPhone/Watch | kcal | Automatic |
| Resting HR | Watch only | bpm | Daily metric |
| Sleep Analysis | Watch/Phone | min | In-bed/asleep/awake |
| Workouts | iPhone/Watch | min | Auto-detected type |
| Distance | iPhone/Watch | m | Walking/running |

## Troubleshooting

### "No data to sync"

**Cause**: No health data available in HealthKit.

**Solution**:
- Generate some data (walk, workout)
- Check Health app → Browse → Steps
- Wait for background delivery (up to 1 hour)
- Force sync: Dashboard → Sync Now

### "Connection failed"

**Cause**: Cannot reach home server.

**Solutions**:
1. Verify server is running: `curl http://<server-ip>:8000/health`
2. Check iPhone and server are on same network
3. Verify server URL in Settings
4. Check API key matches server config
5. Temporarily disable VPN on iPhone

### "Authorization denied"

**Cause**: HealthKit permission denied.

**Solution**:
1. iPhone Settings → Health → Data Access & Devices
2. Tap LifeLens → Turn All Categories On
3. Force quit LifeLens and reopen

### App crashes on launch

**Cause**: Missing capabilities or provisioning issue.

**Solutions**:
1. In Xcode, verify HealthKit capability is added
2. Clean build folder: ⌘Shift+K
3. Delete app from iPhone, reinstall
4. Check Xcode console for crash logs

### Background sync not working

**Cause**: iOS background limits or battery optimization.

**Solutions**:
1. iPhone Settings → General → Background App Refresh → Enable LifeLens
2. Disable Low Power Mode (limits background activity)
3. Keep app in Background App Refresh enabled
4. Manual sync always works: Dashboard → Sync Now

## Development

### Project Structure

```
LifeLens/
├── Models/
│   └── HealthData.swift          # Data models and types
├── Services/
│   ├── HealthKitManager.swift    # HealthKit integration
│   └── APIClient.swift           # Server communication
├── Views/
│   ├── AuthorizationView.swift   # Permission request UI
│   └── (Other views)
├── LifeLensApp.swift             # App entry point
└── Info.plist                    # App configuration
```

### Adding New Health Data Types

1. Add type to `HealthDataType` enum in `HealthData.swift`
2. Add to `healthDataTypes` set in `HealthKitManager.swift`
3. Update `convertQuantitySample()` or `convertCategorySample()`
4. Add icon in `DashboardView` (if needed)

### Testing in Simulator

Simulator has limited HealthKit data:
1. Download HealthKit sample data from Apple
2. Or manually add data in Health app (simulator only)
3. Use `HKHealthStore` methods to add sample data for testing

### Testing on iPhone

For realistic testing:
1. Install on iPhone
2. Walk around to generate steps
3. Wear Apple Watch for heart rate/HRV
4. Create a workout in Workout app
5. Open LifeLens and sync

## Privacy & Security

- **Local-First**: All data stored on your home server
- **No Third Parties**: No cloud services, analytics, or tracking
- **HTTPS**: Encrypted communication (configure cert on server)
- **API Key**: Simple authentication (consider upgrading to OAuth for production)
- **Data Minimization**: Only collect necessary health metrics

## Next Steps

After iOS app is working:
- **Task 8**: Add location tracking and background sync
- **Task 9**: Add communication metadata tracking (calls, notifications)
- **Task 10**: Set up automated 7-day rebuild script

## Support

For issues or questions:
1. Check this README's Troubleshooting section
2. Check main project README: `/README.md`
3. Review server logs: `docker-compose logs -f server`
4. Check Xcode console for iOS app errors

## License

Proprietary - Personal use only.
