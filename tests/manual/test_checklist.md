# LifeLens End-to-End Testing Checklist

**Project:** LifeLens - Automated Life Tracking App
**Date:** 2026-03-14
**Tester:** _________________

## Pre-Test Setup

### Server Infrastructure
- [ ] Docker is installed and running
- [ ] TimescaleDB container is healthy
- [ ] FastAPI server is running on port 8000
- [ ] Server health check passes: `curl http://localhost:8000/health`
- [ ] API key is configured (default: `test-key`)

### Desktop Apps
- [ ] Electron app is built: `cd desktop && npm run build`
- [ ] Desktop app can launch without errors
- [ ] Configuration file is present: `~/.config/lifelens/config.json`

### iOS App
- [ ] iPhone is connected to Mac via USB
- [ ] Xcode project opens without errors
- [ ] Provisioning profile is valid (check `./scripts/ios-rebuild.sh check`)
- [ ] HealthKit capability is enabled
- [ ] Background modes are enabled

---

## Test 1: Server Health & API Endpoints

### Health Check
- [ ] GET `/health` returns 200 OK
- [ ] Response contains `{"status": "ok"}`

### API Authentication
- [ ] POST without API key returns 403 Forbidden
- [ ] POST with invalid API key returns 403 Forbidden
- [ ] POST with valid API key returns 201 Created

### Data Ingestion Endpoints
- [ ] POST `/api/v1/ingest/health/batch` accepts health data
- [ ] POST `/api/v1/ingest/productivity/batch` accepts productivity data
- [ ] POST `/api/v1/ingest/location/batch` accepts location data (if implemented)
- [ ] Malformed data returns 422 Validation Error

**Status:** ✅ Pass | ❌ Fail | ⚠️ Partial

---

## Test 2: Desktop App - macOS

### Installation & Launch
- [ ] App installs to Applications folder
- [ ] App launches from Applications
- [ ] System tray icon appears
- [ ] Window closes to tray (doesn't quit)

### Active Window Tracking
- [ ] Open different apps (VSCode, Chrome, Terminal)
- [ ] Console logs window changes
- [ ] App categorization works (work/study/leisure)

### Data Sync
- [ ] Records are batched and uploaded to server
- [ ] Server logs show incoming POST requests
- [ ] Database contains productivity records
- [ ] Query database: `docker-compose exec db psql -U lifelens -d lifelens -c "SELECT * FROM productivity_data LIMIT 5;"`

### Input Activity (Windows only)
- [ ] Keyboard and mouse events are tracked
- [ ] Input activity counter updates in console
- [ ] Data includes `input_activity` field

**Status:** ✅ Pass | ❌ Fail | ⚠️ Partial

**Notes:** _________________

---

## Test 3: iOS App - Health Data

### Installation & Authorization
- [ ] App installs on iPhone without errors
- [ ] App launches and shows authorization screen
- [ ] HealthKit permission prompt appears
- [ ] "Turn All Categories On" option is available
- [ ] Authorization success enables main app

### Data Collection
- [ ] Walk around to generate step data
- [ ] Check steps in Health app (should see LifeLens access)
- [ ] Wait 5 minutes for background sync
- [ ] Server receives health data
- [ ] Database contains health records

### Background Sync
- [ ] Lock iPhone while generating step data
- [ ] Background task triggers within 15 minutes
- [ ] Data appears in server logs
- [ ] Dashboard shows "Last Sync" timestamp

### Manual Sync
- [ ] Open LifeLens → Dashboard
- [ ] Tap "Sync Now"
- [ ] Console shows sync progress
- [ ] Server receives data immediately

### Apple Watch Data
- [ ] iPhone app can query Watch health data
- [ ] Heart rate data appears in database
- [ ] HRV data appears in database (if Watch supports it)

**Status:** ✅ Pass | ❌ Fail | ⚠️ Partial

**Notes:** _________________

---

## Test 4: iOS App - Location Tracking

### Authorization
- [ ] Location permission prompt appears on first access
- [ ] "Always Allow" option is available
- [ ] Background location access is granted

### Significant Location Changes
- [ ] Travel to different location (>1km)
- [ ] App receives location update in background
- [ ] Server receives location data
- [ ] Database contains location records

### Battery Saver Mode
- [ ] Switch to "Battery Saver" in Settings
- [ ] Location updates trigger on cell tower changes
- [ ] Battery impact is minimal (<5% per day)

### High Accuracy Mode
- [ ] Switch to "High Accuracy" in Settings
- [ ] Location updates more frequently when app is open
- [ ] Check Settings → Privacy → Location Services → LifeLens for battery usage

**Status:** ✅ Pass | ❌ Fail | ⚠️ Partial

**Notes:** _________________

---

## Test 5: iOS App - Communication Tracking

### Call Detection
- [ ] Receive incoming call
- [ ] Call metadata appears in Communication tab
- [ ] Call history syncs via background task
- [ ] Server receives call metadata (no content)

### Notification Tracking
- [ ] Receive notifications from other apps
- [ ] Notification counts appear in Communication tab
- [ ] Only counts while LifeLens is running (iOS limitation)

**Status:** ✅ Pass | ❌ Fail | ⚠️ Partial

**Notes:** _________________

---

## Test 6: Offline Queue & Resilience

### Desktop Offline Queue
- [ ] Stop server: `docker-compose stop server`
- [ ] Use desktop app for 5 minutes (generate data)
- [ ] Check queue status (should show pending records)
- [ ] Restart server: `docker-compose start server`
- [ ] Desktop app auto-syncs queued data
- [ ] Server receives all data (no data loss)

### iOS Offline Queue
- [ ] Turn off WiFi on iPhone
- [ ] Generate step data (walk around)
- [ ] Open LifeLens → Dashboard (shows pending count)
- [ ] Turn on WiFi
- [ ] Tap "Sync Now" or wait for background task
- [ ] Server receives queued data
- [ ] No data loss

### Exponential Backoff
- [ ] Stop server
- [ ] Generate data on all clients
- [ ] Check logs for retry attempts
- [ ] Verify exponential backoff (1min, 2min, 4min, ...)
- [ ] Max retry limit is respected
- [ ] Queue doesn't grow indefinitely (max 10,000 records)

**Status:** ✅ Pass | ❌ Fail | ⚠️ Partial

**Notes:** _________________

---

## Test 7: Cross-Platform Data Collection

### Simultaneous Collection
- [ ] Start all clients (iOS, macOS, Windows) simultaneously
- [ ] Generate data on all platforms within 5-minute window:
  - iPhone: Walk around for steps
  - macOS: Switch between apps
  - Windows: Type and click
- [ ] Wait for sync (5 minutes)
- [ ] Verify all data appears in database
- [ ] Check device_id for each record
- [ ] No data corruption or mixed records

### Timestamp Validation
- [ ] All records have valid timestamps
- [ ] Timestamps are in ISO 8601 format
- [ ] Timestamps are within collection window
- [ ] No future dates or invalid dates

**Status:** ✅ Pass | ❌ Fail | ⚠️ Partial

**Notes:** _________________

---

## Test 8: Web Dashboard

### Dashboard Loads
- [ ] Navigate to `http://localhost:5173`
- [ ] Dashboard renders without errors
- [ ] Browser console shows no errors

### Data Display
- [ ] Summary cards show today's stats
- [ ] Steps chart displays data
- [ ] Heart rate chart displays data
- [ ] Productivity breakdown shows app usage
- [ ] Location map shows GPS tracks (if available)

### Real-Time Updates
- [ ] Generate new data (walk or use desktop)
- [ ] Wait 2 minutes
- [ ] Refresh dashboard
- [ ] New data appears in charts
- [ ] "Last updated" timestamp is recent

### Dark Mode
- [ ] Toggle dark mode
- [ ] All charts and text are readable
- [ ] No layout issues

**Status:** ✅ Pass | ❌ Fail | ⚠️ Partial

**Notes:** _________________

---

## Test 9: Performance Testing

### Server Performance
- [ ] Insert 100,000 health records
- [ ] Insert 100,000 productivity records
- [ ] Query performance < 100ms using aggregates
- [ ] Dashboard load time < 2 seconds

### Database Performance
- [ ] Hypertables are partitioning correctly
- [ ] Continuous aggregates are refreshing
- [ ] Query plans show index usage

### Client Performance
- [ ] Desktop app uses < 5% CPU
- [ ] Desktop app memory < 100MB
- [ ] iOS app doesn't drain battery excessively
- [ ] iOS app background sync completes within 30 seconds

**Status:** ✅ Pass | ❌ Fail | ⚠️ Partial

**Notes:** _________________

---

## Test 10: Security & Privacy

### API Key Validation
- [ ] Requests without API key are rejected (403)
- [ ] Requests with wrong API key are rejected (403)
- [ ] API key is not logged in server logs
- [ ] No sensitive data in logs

### Data Privacy
- [ ] No data is sent to third-party services
- [ ] All data stays on home server
- [ ] Network traffic is encrypted (HTTPS in production)
- [ ] No call recording or content logging
- [ ] Only metadata (timestamps, counts) is stored

### Database Security
- [ ] Database is not exposed to internet
- [ ] Strong password is set (not default)
- [ ] Backups are encrypted

**Status:** ✅ Pass | ❌ Fail | ⚠️ Partial

**Notes:** _________________

---

## Test 11: Error Handling

### Server Unreachable
- [ ] Stop server
- [ ] Client apps don't crash
- [ ] Offline queue activates
- [ ] Error messages are clear and actionable
- [ ] Retry logic kicks in

### Invalid Data
- [ ] Send malformed JSON to server
- [ ] Server returns 422 with error details
- [ ] Client logs the error
- [ ] Client continues functioning

### Network Timeout
- [ ] Slow down server (simulate network lag)
- [ ] Client respects timeout (30s)
- [ ] Retry with backoff
- [ ] No infinite hangs

**Status:** ✅ Pass | ❌ Fail | ⚠️ Partial

**Notes:** _________________

---

## Test 12: iOS 7-Day Rebuild

### Expiry Detection
- [ ] Run `./scripts/ios-rebuild.sh check`
- [ ] Script shows days until expiry
- [ ] Expiration date is accurate
- [ ] Notification appears 48 hours before expiry

### Automated Rebuild
- [ ] Run `./scripts/ios-rebuild.sh rebuild`
- [ ] Xcode build succeeds
- [ ] App installs to connected iPhone
- [ ] App launches without errors
- [ ] HealthKit data is preserved

### Launchd Scheduling
- [ ] Launchd agent loads successfully
- [ ] Agent runs daily at scheduled time
- [ ] Logs appear in `/tmp/lifelens-ios-rebuild.log`

**Status:** ✅ Pass | ❌ Fail | ⚠️ Partial

**Notes:** _________________

---

## Edge Cases & Known Limitations

### Location Granularity
- [ ] Short trips (<500m) may not be captured (expected)
- [ ] Urban movement may not trigger updates (expected)
- [ ] Documentation warns about limitations

### iOS Notification Tracking
- [ ] Only counts while LifeLens is running (expected)
- [ ] Cannot read notification content (expected)
- [ ] Documentation explains limitations

### CallKit Outgoing Calls
- [ ] Outgoing calls detected via history (not real-time)
- [ ] Documentation explains limitation

**Status:** ✅ Pass | ❌ Fail | ⚠️ Partial

**Notes:** _________________

---

## Final Verification

### Definition of Done Checklist
- [ ] All automated tests pass (server, dashboard, desktop)
- [ ] Manual test checklist is complete
- [ ] Data verified in dashboard for all types
- [ ] Background sync tested on iOS
- [ ] Offline queue tested on all platforms
- [ ] Cross-platform test completed
- [ ] Performance meets targets (<2s dashboard, <100ms API)
- [ ] README has complete setup instructions
- [ ] Known limitations documented

### Sign-Off
- [ ] All critical tests pass
- [ ] No blocking issues
- [ ] Ready for production deployment

**Overall Status:** ✅ Pass | ❌ Fail | ⚠️ Partial (with known limitations)

**Tester Signature:** _________________

**Date:** _________________

---

## Issues Found

| ID | Severity | Description | Status |
|----|----------|-------------|--------|
|   | Critical |             |        |
|   | High     |             |        |
|   | Medium   |             |        |
|   | Low      |             |        |

---

## Recommendations

1.
2.
3.

---

## Appendix: Test Commands

### Server
```bash
# Start server
cd server && docker-compose up -d

# Check health
curl http://localhost:8000/health

# View logs
docker-compose logs -f server

# Query database
docker-compose exec db psql -U lifelens -d lifelens -c "SELECT COUNT(*) FROM health_data;"
```

### Desktop
```bash
# Build
cd desktop && npm run build

# Run
npm run dev

# Check logs
tail -f ~/Library/Logs/LifeLens/*.log  # macOS
type %APPDATA%\LifeLens\logs\*.log     # Windows
```

### Dashboard
```bash
# Start
cd dashboard && npm run dev

# Open
open http://localhost:5173
```

### iOS
```bash
# Check expiry
./scripts/ios-rebuild.sh check

# Rebuild
./scripts/ios-rebuild.sh rebuild

# View device console
open -a Xcode && Window → Devices and Simulators → View Device Logs
```
