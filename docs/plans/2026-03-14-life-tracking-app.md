# LifeLens - Automated Life Tracking App Implementation Plan

Created: 2026-03-14
Status: PENDING
Approved: Yes
Iterations: 3
Worktree: No
Type: Feature

## Summary

**Goal:** Build a fully automated, privacy-focused life tracking application that integrates data from iPhone, Apple Watch, PC, and MacBook without manual data entry or paid Apple developer tools.

**Architecture:**
- **iOS App**: SwiftUI + HealthKit for health/location data collection with background sync
- **Desktop Apps**: Electron (TypeScript) for Windows/macOS productivity tracking
- **Home Server**: Python FastAPI + TimescaleDB for data storage and API
- **Dashboard**: React + shadcn/ui web interface for data visualization
- **Automation**: Semi-automated script for iOS 7-day provisioning refresh

**Tech Stack:**
- iOS: Swift 6, SwiftUI, HealthKit, Core Location, Background Tasks
- Desktop: TypeScript, Electron, Node.js
- Server: Python 3.12+, FastAPI, TimescaleDB (PostgreSQL), Alembic
- Web: React 18, TypeScript, shadcn/ui, Recharts/Tremor
- DevOps: Docker, nginx, systemd services

---

## Scope

### In Scope
- **Health & Fitness**: Steps, heart rate, heart rate variability, sleep analysis, active energy, workouts (from HealthKit on iPhone + Apple Watch)
- **Screen Time & Digital Wellness**: App/window focus tracking, time categorization on desktop
- **Location & Movement**: GPS tracks (significant location changes), place visits, geofencing (iOS)
- **Productivity**: Active app tracking, input activity monitoring, inferred categories (work/study/leisure) based on app focus patterns
- **Unproductive Time Detection**: Infer doomscrolling via negative space analysis (PC inactive + not moving + not sleeping = likely phone usage)
- **Communication**: Incoming call detection and call history logs (iOS only, metadata only - no content)
- **Study Sessions**: Inferred from app focus patterns (IDE, documentation sites active for >30min = study session)
- **Data Storage**: Infinite retention with continuous aggregates for performance
- **Visualization**: Web dashboard with charts, trends, and insights (displays data within 2 minutes of ingestion)

### Out of Scope
- AI-powered insights (deferred to post-MVP)
- Social features or sharing
- Mobile app for Android (mentioned PC, not Android)
- Apple Watch companion app (Watch data collected via iPhone HealthKit)
- Notification-based data entry prompts
- Integration with third-party services (Google Fit, Fitbit, etc.)
- Advanced ML-based pattern recognition
- Real-time data streaming dashboard
- Export/import functionality
- Calendar integration (removed - use app focus patterns instead)
- Continuous GPS tracking (significant location changes only for battery efficiency)
- Outgoing call detection (CallKit limitation - only incoming calls + call history)
- **Direct iOS screen time/app usage API** (Apple restriction - use unproductive time inference via negative space analysis instead)

---

## Context for Implementer

> This is a greenfield project with no existing code. The architecture prioritizes privacy (local-first), automation (background collection), and extensibility (AI features later).

### Architecture Patterns
- **Data Flow**: Devices → HTTPS POST → Server API → TimescaleDB → Dashboard Query
- **Sync Strategy**: Pull-based (desktop apps poll every 5min), push-based (iOS uses background delivery)
- **Privacy**: All data stored on your home server, no third-party services, HTTPS with self-signed cert
- **Background Execution**: iOS uses BGTaskScheduler, desktop uses electron-power-save-blocker

### Key Conventions
- **Type Safety**: TypeScript (desktop/web), Python type hints (server), Swift (iOS)
- **Error Handling**: Never lose data - local queue with retry logic if server unreachable
- **API Design**: RESTful with JSON, standard HTTP status codes, ISO 8601 timestamps
- **Database**: TimescaleDB hypertables with automatic partitioning, continuous aggregates for queries
- **Authentication**: Simple API key header (X-API-Key) - one key per device

### File Structure (Project Root)
```
LifeLens/
├── ios/                    # Xcode project
│   ├── LifeLens/
│   │   ├── Models/        # Data models
│   │   ├── Services/      # HealthKit, Location, Network
│   │   ├── Views/         # SwiftUI views
│   │   └── Assets.xcassets
├── desktop/               # Electron app
│   ├── src/
│   │   ├── main/         # Main process
│   │   ├── renderer/     # UI (React)
│   │   └── shared/       # TypeScript types
│   ├── package.json
│   └── electron-builder.yml
├── server/                # FastAPI backend
│   ├── app/
│   │   ├── api/          # REST endpoints
│   │   ├── models/       # SQLAlchemy
│   │   ├── services/     # Business logic
│   │   └── db/           # Database connection
│   ├── alembic/          # Migrations
│   ├── pyproject.toml
│   └── Dockerfile
├── dashboard/            # React web UI
│   ├── src/
│   │   ├── components/   # shadcn/ui + custom
│   │   ├── lib/          # API client
│   │   └── pages/        # Route pages
│   ├── package.json
│   └── vite.config.ts
├── scripts/              # Automation scripts
│   ├── ios-rebuild.sh    # iOS 7-day refresh
│   └── setup-dev.sh      # One-time dev setup
└── docs/
    └── plans/
```

### Gotchas
- **iOS 7-day provisioning**: App stops working after 7 days - script checks and rebuilds automatically at 48h before expiry
- **HealthKit authorization**: Must describe usage in Info.plist or app crashes on startup
- **Background limits**: iOS has strict background execution limits - data may be delayed up to 15min
- **Cross-platform window tracking**: `active-win` works differently on macOS (accessibility) vs Windows (Win32 API)
- **TimescaleDB setup**: Requires PostgreSQL 14+, install as extension, not a separate database
- **Self-signed certificates**: iOS requires certificate trust for HTTPS - include in README
- **Location granularity**: `significantLocationChanges` only triggers on cell tower changes (~500m-1km), not suitable for short trips
- **Study session inference**: Rules-based categorization (IDE, documentation sites active >30min = study) - may need user feedback to refine

### Domain Context
- **Hypertable**: TimescaleDB table optimized for time-series data with automatic partitioning by time
- **Continuous Aggregate**: Materialized view that auto-updates with new data for fast queries
- **Background Delivery**: HealthKit feature that pushes new data to app instead of polling
- **Geofencing**: Location-based triggers (enter/exit region) for automatic place logging
- **Productivity Score**: Calculated from (active time / total time) × (focus depth score)
- **Unproductive Time Inference**: "Negative space" detection - when PC inactive + not moving + not sleeping = likely phone doomscrolling. iOS doesn't allow screen time API, so we infer unproductive time from absence of other activity. Notification counts provide app hints (e.g., 30 Instagram notifications during unaccounted time)

---

## Runtime Environment

### Home Server
- **Start**: `systemctl start lifelens-server` (or `docker-compose up -d`)
- **Port**: 8000 (configurable via `SERVER_PORT` env var)
- **Health Check**: `curl http://localhost:8000/health` → `{"status": "ok"}`
- **Logs**: `journalctl -u lifelens-server -f` or `docker-compose logs -f`
- **Restart**: `systemctl restart lifelens-server` or `docker-compose restart`

### Desktop Apps
- **Start**: Launch from `Applications/` (macOS) or `Start Menu` (Windows)
- **Background**: Runs as system tray application
- **Logs**: `~/Library/Logs/LifeLens/` (macOS), `%APPDATA%\LifeLens\logs\` (Windows)
- **Config**: `~/.config/lifelens/config.json` (auto-generated on first run)

### iOS App
- **Install**: Connect iPhone to Mac, run `./scripts/ios-rebuild.sh install`
- **Background**: System manages background tasks, no user action needed
- **Debug**: Console.app on Mac with iPhone connected
- **Refresh**: Run `./scripts/ios-rebuild.sh` (checks expiry, rebuilds if needed)

---

## Assumptions

- **Home server exists** — User has always-on server (Ubuntu/Debian Linux assumed) — All server tasks depend on this
- **Mac available for iOS builds** — Free Apple ID requires Mac for Xcode builds — Tasks 7, 10 depend on this
- **iOS 17+ supported** — HealthKit background delivery requires iOS 17+ — Task 7 depends on this
- **Local network trusted** — Devices can reach home server via local IP or mDNS — Tasks 6, 7, 8 depend on this
- **PostgreSQL 14+ available** — TimescaleDB requires PostgreSQL 14+ — Task 1 depends on this
- **Node.js 20+ and Python 3.12+** — Development environments assumed for desktop/server — Tasks 2, 3, 4 depend on this
- **User has basic Xcode knowledge** — Can connect iPhone, run build, troubleshoot provisioning — Task 10 assumes this

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **iOS 7-day expiration causes data loss** | Medium | High | ✅ Complete data loss from iOS for ~48h until rebuild completes; script rebuilds 48h before expiry; user notified 2 days before expiry for manual rebuild option; local cache preserves data until rebuild completes |
| **HealthKit authorization denied by user** | Low | High | ✅ Graceful degradation - app functions without health data; clear onboarding explains necessity; retry option in Settings |
| **Home server downtime loses data** | Medium | Medium | ✅ All devices implement local queue (up to 7 days offline); exponential backoff retry; manual sync trigger in dashboard |
| **TimescaleDB performance degradation** | Low | Medium | ✅ Continuous aggregates pre-compute common queries; automatic data retention policy; monitor query performance and add indexes |
| **Cross-platform Electron crashes** | Medium | High | ✅ Comprehensive error tracking; graceful fallback for platform-specific features; extensive testing on both platforms |
| **iOS background task limits block sync** | Medium | Medium | ✅ Use BGProcessingTask (not BGAppRefresh) for 30min execution; schedule multiple tasks per day; priority queue for critical data |
| **Network configuration blocks HTTPS** | Low | Medium | ✅ Support both HTTPS and HTTP (with warning); include setup guide for port forwarding; mDNS for local discovery |
| **Database schema changes break clients** | Medium | High | ✅ Alembic migrations with versioning; API versioning (/v1/); backward compatibility for 2 versions; changelog in docs |

---

## Goal Verification

### Truths
1. **Health data is automatically collected from iPhone/Watch without manual entry**
   - iOS app uses HealthKit background delivery to receive new data automatically
   - Background tasks sync to server within 15 minutes of data generation
   - No user action required after initial authorization

2. **Productivity metrics are tracked on PC/MacBook without user interaction**
   - Electron app monitors active window and input activity in background
   - Data uploads to server every 5 minutes
   - System tray icon shows status but doesn't require interaction

3. **All data is stored privately on home server with no third-party services**
   - Server code runs on user's hardware only
   - No external APIs, analytics, or cloud services
   - Network traffic is encrypted (HTTPS) or local-only

4. **Web dashboard displays comprehensive life metrics with trends and insights**
   - React UI queries aggregated data from server API
   - Charts show hourly/daily/weekly trends across all data types
   - Dashboard accessible from any device on home network

5. **iOS app functions without paid Apple Developer Program**
   - Sideloading via free Apple ID
   - Automated script handles 7-day provisioning refresh
   - Background execution and HealthKit work with free tier

### Artifacts
- `ios/LifeLens/Services/HealthKitManager.swift` - Background delivery setup
- `ios/LifeLens/Services/BackgroundSync.swift` - BGTaskScheduler implementation
- `desktop/src/main/tracker.ts` - Active window and input monitoring
- `server/app/api/ingest.py` - Data ingestion endpoint
- `dashboard/src/pages/Dashboard.tsx` - Main visualization UI
- `scripts/ios-rebuild.sh` - Automated provisioning refresh
- `server/alembic/versions/001_initial.py` - TimescaleDB hypertables
- Tests showing data flow from device → server → dashboard

---

## Progress Tracking

- [x] Task 1: Set up home server infrastructure with TimescaleDB
- [x] Task 2: Create FastAPI backend with data models and ingestion endpoints
- [x] Task 3: Implement database migrations and continuous aggregates
- [x] Task 4: Build React web dashboard with data visualization
- [x] Task 5: Set up Electron desktop app with window tracking (macOS)
- [x] Task 6: Extend desktop app for Windows with input monitoring
- [x] Task 7: Build iOS app with HealthKit integration
- [x] Task 8: Add Core Location and background sync to iOS app
- [x] Task 9: Implement iOS communication metadata tracking
- [x] Task 10: Create semi-automated iOS 7-day rebuild script
- [x] Task 11: Add error handling, retry logic, and offline queuing (all clients)
- [x] Task 12: Comprehensive testing and end-to-end verification
- [x] Task 13: Implement server query endpoints for dashboard
- [x] Task 14: Fix desktop and dashboard test failures
- [x] Task 15: Resolve database startup timing issues
- [ ] Task 16: Implement query service for aggregated data
- [ ] Task 17: Complete dashboard "Last updated" stale warning logic
- [ ] Task 18: Integrate location map component in dashboard

**Total Tasks:** 18 | **Completed:** 15 | **Remaining:** 3

---

## Implementation Tasks

### Task 1: Set up home server infrastructure with TimescaleDB

**Objective:** Initialize the home server environment with PostgreSQL, TimescaleDB extension, and Docker configuration for deployment.

**Dependencies:** None

**Files:**
- Create: `server/docker-compose.yml`
- Create: `server/Dockerfile`
- Create: `server/pyproject.toml`
- Create: `server/app/db/connection.py`
- Create: `server/app/core/config.py`

**Key Decisions / Notes:**
- Use Docker Compose for easy deployment and dependency management
- TimescaleDB extends PostgreSQL - install via official Docker image
- Environment variables for sensitive config (API keys, database URL)
- Use `uvicorn` as ASGI server (standard for FastAPI)
- Reference: TimescaleDB Docker docs at https://docs.timescale.com/self-hosted/latest/install/

**Definition of Done:**
- [ ] `docker-compose up -d` starts successfully
- [ ] TimescaleDB extension is enabled (`CREATE EXTENSION IF NOT EXISTS timescaledb;`)
- [ ] Health check endpoint returns 200 OK
- [ ] Server logs show successful database connection
- [ ] README includes setup instructions

**Verify:**
```bash
cd server && docker-compose up -d
curl http://localhost:8000/health
docker-compose logs db | grep "TimescaleDB"
```

---

### Task 2: Create FastAPI backend with data models and ingestion endpoints

**Objective:** Build the REST API with Pydantic models for all data types and create ingestion endpoints for health, productivity, and location data.

**Dependencies:** Task 1

**Files:**
- Create: `server/app/models/health.py`
- Create: `server/app/models/productivity.py`
- Create: `server/app/models/location.py`
- Create: `server/app/services/inference.py` (unproductive time detection)
- Create: `server/app/api/ingest.py`
- Create: `server/app/api/health.py`
- Create: `server/app/core/security.py`

**Key Decisions / Notes:**
- Use SQLAlchemy ORM for database models
- Pydantic for request validation (FastAPI integrates natively)
- Device authentication via `X-API-Key` header (simple, effective)
- Separate endpoints for data types: `/api/v1/ingest/health`, `/api/v1/ingest/productivity`, `/api/v1/ingest/location`
- Batch ingestion support (array of records) to reduce request overhead
- ISO 8601 timestamps for all datetime fields
- **Unproductive time inference**: Server-side logic analyzes gaps in desktop activity + location data to infer phone usage periods
- Reference: FastAPI docs at https://fastapi.tiangolo.com/

**Definition of Done:**
- [ ] POST `/api/v1/ingest/health` accepts health data and returns 201
- [ ] POST `/api/v1/ingest/productivity` accepts productivity data and returns 201
- [ ] POST `/api/v1/ingest/location` accepts location data and returns 201
- [ ] API key validation rejects invalid keys with 403
- [ ] Request validation rejects malformed data with 422
- [ ] CORS allows requests from desktop/dashboard origins
- [ ] **Inference service detects unproductive time periods** (PC inactive + not moving + not sleeping = likely phone usage)

**Verify:**
```bash
curl -X POST http://localhost:8000/api/v1/ingest/health \
  -H "X-API-Key: test-key" \
  -H "Content-Type: application/json" \
  -d '{"device_id": "test", "data_type": "steps", "value": 1000, "timestamp": "2024-01-01T00:00:00Z"}'
```

---

### Task 3: Implement database migrations and continuous aggregates

**Objective:** Create TimescaleDB hypertables with automatic partitioning and continuous aggregates for efficient querying of aggregated data.

**Dependencies:** Task 2

**Files:**
- Create: `server/alembic/env.py`
- Create: `server/alembic/script.py.mako`
- Create: `server/app/db/migrations/versions/001_initial_hypertables.py`
- Create: `server/app/db/migrations/versions/002_continuous_aggregates.py`
- Create: `server/app/services/query.py`

**Key Decisions / Notes:**
- Hypertables partition by time (required for time-series optimization)
- Create continuous aggregates for common queries: hourly steps, daily screen time, weekly averages
- Automatic refresh policies run every hour
- Data retention: infinite raw storage (per user requirement)
- Use `time_bucket()` for grouping by interval
- Reference: TimescaleDB continuous aggregates at https://docs.timescale.com/use-timescale/latest/continuous-aggregates/

**Definition of Done:**
- [ ] `alembic upgrade head` creates all hypertables
- [ ] Continuous aggregates exist for hourly/daily/weekly summaries
- [ ] Refresh policies are active (check with `SELECT * FROM timescaledb_information.jobs;`)
- [ ] Query service can fetch raw and aggregated data
- [ ] Performance test: 1M records queried in <100ms using aggregates

**Verify:**
```bash
docker-compose exec server alembic upgrade head
docker-compose exec db psql -U lifelens -d lifelens -c "SELECT * FROM timescaledb_information.continuous_aggregates;"
```

---

### Task 4: Build React web dashboard with data visualization

**Objective:** Create the web interface with shadcn/ui components and Recharts/Tremor for visualizing health, productivity, and location data.

**Dependencies:** Task 3

**Files:**
- Create: `dashboard/package.json`
- Create: `dashboard/vite.config.ts`
- Create: `dashboard/src/pages/Dashboard.tsx`
- Create: `dashboard/src/pages/Health.tsx`
- Create: `dashboard/src/pages/Productivity.tsx`
- Create: `dashboard/src/pages/Location.tsx`
- Create: `dashboard/src/lib/api.ts`
- Create: `dashboard/src/components/charts/StepsChart.tsx`
- Create: `dashboard/src/components/charts/ScreenTimeChart.tsx`
- Create: `dashboard/src/components/charts/LocationMap.tsx`

**Key Decisions / Notes:**
- Use Vite for fast development and optimized builds
- shadcn/ui provides accessible, customizable components
- Recharts for simple charts, Tremor for complex metrics dashboards
- Fetch aggregated data from `/api/v1/query/` endpoints
- Responsive design: mobile-first, works on iPhone as web app
- Dark mode support (system preference detection)
- Real-time updates: poll every 30s or use Server-Sent Events

**Definition of Done:**
- [ ] Dashboard page shows summary cards (steps today, screen time, active hours)
- [ ] **Dashboard shows "Last updated" timestamp** (displays data within 2 minutes of server ingestion)
- [ ] Health page displays steps, heart rate, sleep charts with time range selector
- [ ] Productivity page shows app usage breakdown, focus trends
- [ ] Location page displays GPS tracks on map (use react-leaflet or mapbox-gl)
- [ ] API client handles errors gracefully (retry, offline indication)
- [ ] Build produces optimized bundle (<500KB gzipped)

**Verify:**
```bash
cd dashboard && npm run dev
# Open http://localhost:5173
# Verify all charts render with test data
# Generate health data via API, verify dashboard reflects new data within 2 minutes
```

---

### Task 5: Set up Electron desktop app with window tracking (macOS)

**Objective:** Initialize Electron project with TypeScript and implement active window tracking for macOS using accessibility APIs.

**Dependencies:** Task 2

**Files:**
- Create: `desktop/package.json`
- Create: `desktop/electron.vite.config.ts`
- Create: `desktop/src/main/index.ts`
- Create: `desktop/src/main/tracker.ts`
- Create: `desktop/src/main/sync.ts`
- Create: `desktop/src/preload/index.ts`
- Create: `desktop/src/renderer/App.tsx`
- Create: `desktop/src/shared/types.ts`

**Key Decisions / Notes:**
- Use `electron-vite` for improved development experience (hot reload)
- `active-win` package for cross-platform window detection
- macOS requires accessibility permissions - prompt user on first launch
- Poll every 5 seconds for active window (configurable)
- Upload to server every 5 minutes (batch records)
- Run as system tray app (hide dock icon, show in menu bar)
- Include enable-accessibility.sh helper script

**Definition of Done:**
- [ ] Electron app launches and shows tray icon
- [ ] Active window changes are logged to console
- [ ] Data is batched and POSTed to `/api/v1/ingest/productivity`
- [ ] App survives window close (runs in background)
- [ ] macOS accessibility prompt shows on first launch
- [ ] Configuration file stores server URL and API key

**Verify:**
```bash
cd desktop && npm run dev
# Open different apps, check console logs
# Verify data appears in server logs
```

---

### Task 6: Extend desktop app for Windows with input monitoring

**Objective:** Add Windows-specific window tracking and implement keyboard/mouse activity monitoring using `iohook`.

**Dependencies:** Task 5

**Files:**
- Modify: `desktop/src/main/tracker.ts`
- Create: `desktop/src/main/input-monitor.ts`
- Modify: `desktop/package.json`

**Key Decisions / Notes:**
- `active-win` already supports Windows via Win32 API
- `iohook` or `uiohook-napi` for keyboard/mouse events (cross-platform)
- Count keypresses and mouse clicks per minute as engagement metric
- Respect user privacy - count activity only, don't log keystrokes/content
- Windows may require administrator privileges for global input hooks
- Add installer script (NSIS or electron-builder)

**Definition of Done:**
- [ ] Windows build runs without errors
- [ ] Active window tracking works on Windows 10/11
- [ ] Input activity counter updates in real-time
- [ ] Data includes `input_activity` field (keystrokes/min, clicks/min)
- [ ] Electron-builder creates Windows installer (.exe)

**Verify:**
```bash
cd desktop && npm run build:win
# Install and run on Windows machine
# Verify window and input tracking work
```

---

### Task 7: Build iOS app with HealthKit integration

**Objective:** Create SwiftUI iOS app with HealthKit authorization and background delivery for health data (steps, heart rate, sleep, workouts).

**Dependencies:** Task 2

**Files:**
- Create: `ios/LifeLens.xcodeproj/project.pbxproj`
- Create: `ios/LifeLens/LifeLensApp.swift`
- Create: `ios/LifeLens/Models/HealthData.swift`
- Create: `ios/LifeLens/Services/HealthKitManager.swift`
- Create: `ios/LifeLens/Services/APIClient.swift`
- Create: `ios/LifeLens/Views/AuthorizationView.swift`
- Create: `ios/LifeLens/Info.plist`

**Key Decisions / Notes:**
- Xcode project must enable HealthKit capability (Signing & Capabilities)
- Info.plist requires `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription`
- Request authorization for specific data types (steps, heart rate, sleep, workouts)
- Use `enableBackgroundDelivery(for:frequency:)` to receive automatic updates
- Query new samples with `execute()` when background delivery triggers
- Upload to server in batches (up to 100 records per request)
- Background app refresh interval: minimum 15 minutes (iOS limitation)

**Definition of Done:**
- [ ] App launches and requests HealthKit authorization on first run
- [ ] Authorization success enables data collection from iPhone
- [ ] **Apple Watch data accessible**: Verify iPhone app can query Watch health data (heart rate, HRV, ECG, sleep, steps) through HealthKit
- [ ] Background delivery triggers `HKObserverQuery` callbacks
- [ ] New health data is uploaded to server within 30 minutes
- [ ] App shows last sync timestamp in Settings
- [ ] Build succeeds for free Apple ID (no paid developer program)

**Verify:**
```bash
# In Xcode, run on iPhone
# Grant HealthKit permission
# Walk around to generate step data
# Check server logs for incoming health data
```

---

### Task 8: Add Core Location and background sync to iOS app

**Objective:** Implement GPS tracking, place visits (geofencing), and BGTaskScheduler for reliable background synchronization.

**Dependencies:** Task 7

**Files:**
- Create: `ios/LifeLens/Services/LocationManager.swift`
- Create: `ios/LifeLens/Services/BackgroundSync.swift`
- Modify: `ios/LifeLens/Info.plist`
- Modify: `ios/LifeLens/LifeLensApp.swift`

**Key Decisions / Notes:**
- Core Location requires `NSLocationWhenInUseUsageDescription` in Info.plist
- Use `significantLocationChanges` for battery-efficient tracking (triggers on cell tower changes, ~500m-1km)
- **Known limitation**: `significantLocationChanges` may miss short trips or urban movement - documented in README
- `CLVisit` API for automatic place visit detection (enter/exit events)
- Register `BGProcessingTask` for background sync (30 second execution limit)
- Schedule multiple tasks per day: 6 AM, 12 PM, 6 PM, 12 AM
- Implement `URLSession` background upload for network resilience
- Local queue (CoreData or files) preserves data if server is unreachable
- User-configurable tracking modes: Battery Saver (significant changes only) vs. Accuracy (active GPS when app is in foreground)

**Definition of Done:**
- [ ] Location permission prompt shows and is granted
- [ ] App receives location updates in background (significant location changes)
- [ ] Place visits trigger automatic logging
- [ ] Background sync tasks execute successfully
- [ ] Data survives app termination (background upload completes)
- [ ] Battery impact is minimal (<5% per day)
- [ ] **README documents location tracking limitation** (significant changes only, ~500m-1km granularity)
- [ ] User can toggle tracking mode in Settings (Battery Saver vs. Accuracy)

**Verify:**
```bash
# Install app on iPhone
# Grant location permission (Always)
# Travel to different locations
# Check server for location data
# Check Settings > Privacy > Location Services > LifeLens for battery usage
```

---

### Task 9: Implement iOS communication metadata tracking

**Objective:** Add CallKit and notification metadata tracking for calls and messages (metadata only, no content).

**Dependencies:** Task 7

**Files:**
- Create: `ios/LifeLens/Services/CallManager.swift`
- Create: `ios/LifeLens/Services/NotificationManager.swift`
- Modify: `ios/LifeLens/Info.plist`

**Key Decisions / Notes:**
- CallKit requires `NSCallKitUsageDescription` in Info.plist
- **Privacy constraint**: Only metadata (caller ID, timestamp, duration), NOT content
- Use `CXCallObserver` to detect incoming calls in real-time
- **CallKit limitation**: Cannot detect outgoing calls made through native Phone app (only calls initiated via CXCallController)
- Use `CNCallRecordChangeHistoryEvent` (iOS 14+) to fetch call history logs periodically (includes both incoming and outgoing)
- Notification tracking is limited on iOS - can only count notifications per app, not read content
- SMS metadata requires Message framework integration (available with free tools)
- Data uploaded as: `{"type": "call", "direction": "incoming", "duration_seconds": 120, "timestamp": "..."}`

**Definition of Done:**
- [ ] CallKit authorization is requested and granted
- [ ] **Incoming calls** are detected in real-time via `CXCallObserver`
- [ ] **Call history** (both incoming and outgoing) is fetched periodically via `CNCallRecordChangeHistoryEvent`
- [ ] Call metadata (not content) is uploaded to server
- [ ] Notification counts are tracked (per app per day)
- [ ] Dashboard shows communication trends (call frequency, peak hours)

**Verify:**
```bash
# Make/receive calls on iPhone
# Check server logs for call metadata
# Verify dashboard displays communication trends
```

---

### Task 10: Create semi-automated iOS 7-day rebuild script

**Objective:** Build automation script that checks iOS app provisioning expiry, rebuilds if needed, and optionally installs to connected iPhone.

**Dependencies:** Task 7

**Files:**
- Create: `scripts/ios-rebuild.sh`
- Create: `scripts/ios-check-expiry.sh`
- Modify: `README.md` (add setup instructions)

**Key Decisions / Notes:**
- Check provisioning expiry by reading embedded.mobileprovision in .app bundle
- Use `xcodebuild -scheme LifeLens -configuration Release` to build
- Use `ios-deploy` or `ideviceinstaller` for automated installation
- Schedule via launchd (macOS) to run daily
- Rebuild **48 hours before expiry** (7 days is hard limit, 48h gives buffer)
- **User notification 2 days before expiry** so they can trigger manual rebuild earlier if needed
- Send notification when rebuild completes (macOS notification or desktop alert)
- Script should be idempotent (safe to run multiple times)

**Definition of Done:**
- [ ] Script checks provisioning expiry accurately
- [ ] Automatic rebuild triggers when expiry < 48 hours
- [ ] User notified 2 days (48h) before expiry
- [ ] Build succeeds with free Apple ID
- [ ] App installs to connected iPhone (if present)
- [ ] User receives notification on successful rebuild
- [ ] Script is executable: `chmod +x scripts/ios-rebuild.sh`

**Verify:**
```bash
./scripts/ios-rebuild.sh check  # Should show days until expiry
./scripts/ios-rebuild.sh rebuild  # Should rebuild and install
# Manually set date forward to test expiry logic
```

---

### Task 11: Add error handling, retry logic, and offline queuing (all clients)

**Objective:** Implement resilient data collection with local queuing, exponential backoff retry, and graceful degradation when server is unreachable.

**Dependencies:** Tasks 5, 7, 8

**Files:**
- Modify: `desktop/src/main/sync.ts` (add queue and retry)
- Modify: `ios/LifeLens/Services/APIClient.swift` (add queue and retry)
- Modify: `ios/LifeLens/Services/BackgroundSync.swift` (add retry logic)
- Create: `desktop/src/main/store.ts` (localStorage queue)
- Create: `ios/LifeLens/Models/QueuedRecord.swift` (CoreData or files)

**Key Decisions / Notes:**
- Use `backoff` exponential delay: 1min, 2min, 4min, 8min, ... max 1 hour
- Store failed requests locally (SQLite for desktop, CoreData/files for iOS)
- Queue limit: 10,000 records (after that, drop oldest or compress)
- Flush queue when connectivity restored
- Manual sync trigger in dashboard and iOS settings
- Log errors with context (timestamp, error code, retry count)

**Definition of Done:**
- [ ] Server unreachable triggers immediate queue (not crash)
- [ ] Queued data retries with exponential backoff
- [ ] Queue survives app restart
- [ ] Manual sync button flushes queue immediately
- [ ] Error logs include actionable information
- [ ] Dashboard shows "Last successful sync" timestamp

**Verify:**
```bash
# Stop server: docker-compose stop server
# Generate data on all devices
# Restart server: docker-compose start server
# Verify queued data appears in database
```

---

### Task 12: Comprehensive testing and end-to-end verification

**Objective:** Test complete data flow from all devices to dashboard, verify automation works as expected, and document any edge cases.

**Dependencies:** All previous tasks

**Files:**
- Create: `tests/integration/test_e2e.py`
- Create: `tests/manual/test_checklist.md`
- Modify: `README.md` (update with final setup instructions)

**Key Decisions / Notes:**
- End-to-end test: Generate data → Sync → Query → Display
- Test offline scenario: Stop server, generate data, restart, verify queue flush
- Test iOS background: Lock phone, generate step data, verify sync within 30min
- Test cross-platform: Run all clients simultaneously, verify no data loss
- Performance test: 100K records per data type, verify dashboard <2s load
- Security test: Verify API key rejection, no data leaks in logs

**Definition of Done:**
- [ ] All automated tests pass (pytest for server, jest for dashboard/desktop)
- [ ] Manual test checklist completed
- [ ] Data verified in dashboard for all data types
- [ ] Background sync tested and working on iOS
- [ ] Offline queue tested and working on all platforms
- [ ] **Cross-platform test**: All three clients (iOS, macOS, Windows) tested simultaneously with concurrent data ingestion
- [ ] Performance meets targets (<2s dashboard load, <100ms API response)
- [ ] README has complete setup instructions for all components
- [ ] Known limitations and edge cases documented

**Verify:**
```bash
# Run all test suites
cd server && pytest
cd desktop && npm test
cd dashboard && npm test

# Manual E2E test:
# 1. Start server
# 2. Open dashboard
# 3. Generate data on iPhone (walk, make call)
# 4. Generate data on desktop (work, switch apps)
# 5. Verify all data appears in dashboard within 5 minutes

# Cross-platform test:
# 1. Start all clients (iOS, macOS, Windows) simultaneously
# 2. Generate data on all devices within 5-minute window
# 3. Verify all data appears in dashboard without corruption
```

---

### Task 13: Implement server query endpoints for dashboard

**Objective:** Create GET endpoints to serve aggregated data to the dashboard, replacing hardcoded mock data with live database queries.

**Dependencies:** Task 3

**Files:**
- Create: `server/app/api/query.py`
- Create: `server/app/models/query.py` (Pydantic models for query responses)
- Modify: `server/app/main.py` (include query router)
- Modify: `dashboard/src/lib/api.ts` (add query methods)

**Key Decisions / Notes:**
- Query endpoints: GET `/api/v1/query/health/today`, `/api/v1/query/productivity/today`, `/api/v1/query/location/recent`
- Use TimescaleDB time_bucket for efficient aggregation
- Return data in dashboard-friendly format (totals, averages, trends)
- Support date range parameters: ?start=2024-01-01&end=2024-01-02
- Reference: Task 4 DoD line 392 requires dashboard displays data "within 2 minutes of server ingestion"

**Definition of Done:**
- [ ] GET `/api/v1/query/health/today` returns today's step count, heart rate stats, sleep duration
- [ ] GET `/api/v1/query/productivity/today` returns screen time breakdown by category
- [ ] GET `/api/v1/query/location/recent` returns recent GPS tracks and place visits
- [ ] All endpoints handle missing data gracefully (return empty arrays, not 404)
- [ ] API client in dashboard calls query endpoints instead of using mock data
- [ ] Dashboard displays live data from server (not hardcoded values)

**Verify:**
```bash
# Start server and test query endpoints
curl -H "X-API-Key: test-key" http://localhost:8000/api/v1/query/health/today
curl -H "X-API-Key: test-key" http://localhost:8000/api/v1/query/productivity/today

# Open dashboard and verify data displays correctly
```

---

### Task 14: Fix desktop and dashboard test failures

**Objective:** Update test files to match actual implementation APIs and ensure all tests pass.

**Dependencies:** Task 13

**Files:**
- Modify: `desktop/src/main/tracker.test.ts` (fix API mismatches)
- Modify: `dashboard/src/lib/api.test.ts` (fix API mismatches)
- Modify: `desktop/src/main/tracker.ts` (if API changes needed for testability)
- Create: `desktop/src/test/setup.ts` (if not exists)

**Key Decisions / Notes:**
- Desktop test failures: ProductivityTracker constructor signature mismatch, private property access
- Dashboard test failures: Need to mock fetch responses properly
- Use vi.mock() for external dependencies (active-win, fetch)
- Test file path references must match actual implementation
- Coverage target: >80% for tested modules

**Definition of Done:**
- [ ] `npm test` passes in desktop with 0 failures
- [ ] `npm test` passes in dashboard with 0 failures
- [ ] Coverage >80% for tracker and api modules
- [ ] Tests verify behavior (public API) not implementation details
- [ ] No tests skipped or marked as .todo

**Verify:**
```bash
cd desktop && npm test
cd dashboard && npm test
```

---

### Task 15: Resolve database startup timing issues

**Objective:** Fix the TimescaleDB connection timing issue where the server fails to start even though the database is "healthy".

**Dependencies:** None

**Files:**
- Modify: `docker-compose.yml` (add healthcheck delay)
- Modify: `server/app/main.py` (increase retry attempts or delay)

**Key Decisions / Notes:**
- Current issue: TimescaleDB passes pg_isready but refuses connections for ~60 seconds
- Current retry: 5 attempts × 2/4/8/16/32s delays = 62 seconds total, but still fails
- Options: (1) Add healthcheck.delay: 30s to docker-compose, (2) Increase max_retries to 10, (3) Add startup script that waits for db
- Recommended: Combine healthcheck.delay + increase max_retries to 10
- Test by doing `docker compose down && docker compose up -d` cold start

**Definition of Done:**
- [ ] `docker compose down && docker compose up -d` starts server successfully on first try
- [ ] Server logs show "Database initialized successfully" without retry failures
- [ ] Health check endpoint returns 200 OK within 90 seconds of `docker compose up`
- [ ] No manual intervention required (no need to restart server container)

**Verify:**
```bash
# Cold start test
docker compose down
docker compose up -d
sleep 90
curl http://localhost:8000/health
# Should return {"status":"ok","version":"0.1.0"}
```

---

### Task 16: Implement query service for aggregated data

**Objective:** Implement the query service referenced in Task 3 to efficiently retrieve and aggregate time-series data from TimescaleDB.

**Dependencies:** Task 13, Task 3

**Files:**
- Modify: `server/app/services/query.py` (implement or create if stub)
- Modify: `server/app/api/query.py` (use query service)

**Key Decisions / Notes:**
- Query service provides abstraction layer over raw SQL queries
- Implement methods: get_health_summary(), get_productivity_breakdown(), get_location_tracks()
- Use TimescaleDB time_bucket() for efficient time-based aggregation
- Cache common queries (Redis optional for now, in-memory caching acceptable)
- Support pagination for large datasets

**Definition of Done:**
- [ ] `query.py` exports QueryService class with get_health_summary() method
- [ ] get_health_summary() returns today's aggregated health metrics (steps, HR, sleep)
- [ ] get_productivity_breakdown() returns time by category with percentages
- [ ] Query service uses TimescaleDB continuous aggregates when available
- [ ] Query endpoints use query service instead of direct database access

**Verify:**
```bash
# Test query service directly
curl -H "X-API-Key: test-key" http://localhost:8000/api/v1/query/health/today
# Should return aggregated data, not empty response
```

---

### Task 17: Complete dashboard "Last updated" stale warning logic

**Objective:** Implement automatic stale data detection and re-fetching in the dashboard when data is older than 2 minutes.

**Dependencies:** Task 13

**Files:**
- Modify: `dashboard/src/pages/Dashboard.tsx`

**Key Decisions / Notes:**
- Current implementation shows "Last updated" timestamp but doesn't auto-refresh
- Add useEffect hook that polls every 60 seconds when data is stale
- Show visual warning when data is older than 2 minutes (yellow warning icon)
- Only re-fetch when tab is visible (use Intersection Observer or visibility API)
- Avoid thundering herd problem: add random jitter to refresh intervals

**Definition of Done:**
- [ ] Dashboard shows "⚠ Data may be stale" warning when last update >2 minutes ago
- [ ] Dashboard automatically re-fetches data every 60 seconds when stale
- [ ] Re-fetch stops when user navigates away (visibility change listener)
- [ ] No multiple simultaneous requests (debounce or cancel pending requests)
- [ ] User can manually trigger refresh with "Sync Now" button

**Verify:**
- Open dashboard, wait 3 minutes, verify warning appears
- Verify warning disappears after automatic refresh
- Check browser network tab for multiple simultaneous requests (should be none)

---

### Task 18: Integrate location map component in dashboard

**Objective:** Add interactive map visualization to the dashboard Location page showing GPS tracks and place visits.

**Dependencies:** Task 13, Task 8

**Files:**
- Modify: `dashboard/src/pages/Location.tsx`
- Modify: `dashboard/package.json` (add react-leaflet or mapbox-gl)
- Create: `dashboard/src/components/LocationMap.tsx`

**Key Decisions / Notes:**
- Use react-leaflet (free, open-source) or mapbox-gl (requires API key)
- Display GPS tracks as polylines with color coding by date
- Show place visit markers with tooltips (place name, arrival/departure times)
- Support zoom, pan, and click for details
- Handle case with no location data (show "No location data available" message)
- Performance: Limit displayed points to last 1000 locations (add pagination)

**Definition of Done:**
- [ ] Location page displays map component (not just text)
- [ ] GPS tracks shown as polylines on map
- [ ] Place visits displayed as markers with tooltips
- [ ] Map controls work (zoom in/out, pan, click markers)
- [ ] Empty state shows helpful message when no data
- [ ] Performance acceptable with 1000+ location points
- [ ] Works on mobile (responsive design)

**Verify:**
```bash
# Generate test location data via API
curl -X POST http://localhost:8000/api/v1/ingest/location \
  -H "X-API-Key: test-key" \
  -H "Content-Type: application/json" \
  -d '{"device_id":"test","location_type":"gps","latitude":37.7749,"longitude":-122.4194,"timestamp":"2024-01-01T00:00:00Z"}'

# Open dashboard Location page, verify map displays data
```

---
# 1. Start all clients (iOS, macOS, Windows) simultaneously
# 2. Generate data on all devices within 5-minute window
# 3. Verify all data appears in dashboard without corruption
```

---

## Verification Gaps

**Iteration 3 (Post-Verification):** The following gaps were identified during verification and must be addressed before marking COMPLETE.

| Gap | Type | Severity | Affected Files | Fix Description |
|-----|------|----------|----------------|----------------|
| **Dashboard query endpoints missing** | spec_compliance | High | server/app/api/, dashboard/src/lib/api.ts, dashboard/src/pages/Dashboard.tsx | Dashboard calls API but server only has ingest endpoints. Need GET /api/v1/query/health/today, GET /api/v1/query/productivity/today, etc. |
| **Test failures** | test_quality | High | desktop/src/main/tracker.test.ts, dashboard/src/lib/api.test.ts | Tests created but fail due to API mismatch (ProductivityTracker constructor, private properties). Fix tests to match actual implementation. |
| **Database startup timing** | deployment | Medium | server/app/main.py, docker-compose.yml | TimescaleDB health check passes but refuses connections for ~60 seconds. Current retry logic (5 attempts × 30s) insufficient. Add healthcheck.delay or startup script. |
| **Missing query service** | spec_compliance | High | server/app/services/query.py | Plan references query service (Task 3) but file doesn't exist or is empty. Implement query service for aggregated data retrieval. |
| **Dashboard "Last updated" not stale warning** | definition_of_done | Low | dashboard/src/pages/Dashboard.tsx | Added timestamp but stale warning logic incomplete (checks >2min but doesn't re-fetch automatically). |
| **Location map component missing** | spec_compliance | Medium | dashboard/src/pages/Location.tsx | Plan requires map visualization (Task 4 DoD). Location page exists but no map integration (react-leaflet or mapbox-gl). |

**Deployment Note:** Server starts successfully after manual restart once database is fully ready (~60 seconds after `docker compose up`).

**Recommendation:** Focus on implementing query endpoints first (highest impact), then fix test failures, then address deployment timing.

None at this time - architecture decisions are clear and user requirements are well-defined.

---

## Deferred Ideas

**Post-MVP Enhancements:**
- AI-powered insights (activity patterns, productivity recommendations, anomaly detection)
- Mobile app for Android
- Apple Watch companion app with complications
- Advanced ML models for predicting health trends
- Integration with third-party services (Strava, Oura, Whoop)
- Real-time WebSocket-based dashboard updates
- Social features (family sharing, leaderboards)
- Export to CSV/JSON/PDF reports
- Natural language queries ("What was my average sleep this week?")
- Custom metrics and dashboards
- Alert system for unusual patterns (e.g., "You haven't left the house today")
- Integration with home automation (turn off lights when sleep detected)
- Data donation to research studies (opt-in)

**Reason for deferral:** These are all valuable features but not required for core functionality. The MVP focuses on automated data collection and visualization. AI features are explicitly deferred by user requirement. Other features can be prioritized based on user feedback after MVP is in use.
