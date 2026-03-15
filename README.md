# LifeLens - Automated Life Tracking App

A fully automated, privacy-focused life tracking application that integrates data from iPhone, Apple Watch, PC, and MacBook without manual data entry.

## Features

- **Health Tracking**: Steps, heart rate, HRV, sleep, and workouts from iPhone/Apple Watch
- **Productivity Tracking**: Active app usage, input activity, and categorization (work/study/leisure)
- **Location Tracking**: GPS tracks and place visits with battery-efficient background monitoring
- **Communication Tracking**: Call metadata and notification activity tracking
- **Privacy-First**: All data stored on your home server, no third-party services
- **Fully Automated**: Background sync means no manual data entry required
- **Free Tools**: Works with free Apple ID (no $99/year developer program)

## Architecture

```
┌─────────────┐
│   iPhone    │ ──┐
│ + Apple Watch│  │
└─────────────┘  │
                  ├──► Health/Location/Communication Data
┌─────────────┐  │
│   MacBook   │  │
│   (macOS)   │ ──┘
└─────────────┘
                  │
                  ├──► Productivity Data (app usage, input activity)
┌─────────────┐  │
│     PC      │ ──┘
│  (Windows)  │
└─────────────┘
                  │
                  ▼
        ┌───────────────────┐
        │   Home Server     │
        │  (FastAPI +       │
        │  TimescaleDB)     │
        └─────────┬─────────┘
                  │
                  ▼
        ┌───────────────────┐
        │  Web Dashboard    │
        │  (React + Vite)   │
        └───────────────────┘
```

## Tech Stack

- **iOS App**: Swift 6, SwiftUI, HealthKit, Core Location, CallKit
- **Desktop Apps**: TypeScript, Electron, active-win, uiohook-napi
- **Home Server**: Python 3.12+, FastAPI, TimescaleDB (PostgreSQL)
- **Web Dashboard**: React 18, TypeScript, shadcn/ui, Recharts
- **DevOps**: Docker, nginx, systemd

## Quick Start

### Prerequisites

- **Home Server**: Ubuntu/Debian Linux with Docker
- **Mac**: macOS 14+ with Xcode 15+ (for iOS builds)
- **iPhone**: iOS 17+ (for data collection)
- **Network**: All devices on same local network

### 1. Start Home Server

```bash
cd server
docker-compose up -d

# Verify server is running
curl http://localhost:8000/health
```

Server will be available at `http://localhost:8000`

### 2. Start Web Dashboard

```bash
cd dashboard
npm install
npm run dev
```

Dashboard opens at `http://localhost:5173`

### 3. Build Desktop Apps

**macOS:**
```bash
cd desktop
npm install
npm run build:mac
```

**Windows:**
```bash
cd desktop
npm install
npm run build:win
```

### 4. Build iOS App

```bash
cd ios
# Open in Xcode
open LifeLens.xcodeproj

# In Xcode:
# 1. Select your iPhone as destination
# 2. Add HealthKit capability
# 3. Add Background Modes capability
# 4. Select your free Apple ID as team
# 5. Press ⌘R to build and run
```

See [iOS README](ios/README.md) for detailed iOS setup instructions.

### 5. Configure Devices

All clients need your home server URL and API key:

- **Desktop**: Edit `~/.config/lifelens/config.json` or use UI
- **iOS**: Open app → Settings → Configure Server
- **Default**: `http://<server-ip>:8000` with API key `test-key`

## Data Collection

### Health Data (iOS + Watch)

| Data Type | Source | Frequency |
|-----------|--------|-----------|
| Steps | iPhone/Watch | Real-time (background) |
| Heart Rate | Watch only | Every reading |
| HRV | Watch only | Every reading |
| Active Energy | iPhone/Watch | Real-time |
| Sleep | Watch/Phone | Nightly |
| Workouts | iPhone/Watch | Post-workout |

**Authorization**: iPhone Settings → Health → Data Access → LifeLens → Turn All Categories On

### Productivity Data (macOS/Windows)

| Data Type | Platform | Frequency |
|-----------|----------|-----------|
| Active Window | macOS/Windows | Every 5 seconds |
| App Category | macOS/Windows | Inferred from app name |
| Input Activity | Windows only | Keystrokes/clicks per minute |

**Permissions**: Grant accessibility permissions on first launch (prompted automatically)

### Location Data (iOS)

| Tracking Mode | Battery Impact | Granularity |
|---------------|----------------|-------------|
| Battery Saver | Minimal (<5%/day) | ~500m-1km (cell tower) |
| High Accuracy | Moderate | Active GPS when app open |

**Authorization**: iPhone Settings → Privacy → Location Services → LifeLens → "Always"

**Known Limitation**: Short trips (<500m) may not be captured in Battery Saver mode. This is an iOS limitation for battery efficiency.

### Communication Data (iOS)

| Data Type | Metadata Only | Frequency |
|-----------|---------------|-----------|
| Incoming Calls | ✓ (caller, time, duration) | Real-time |
| Outgoing Calls | ✓ (from call history) | Hourly |
| Notifications | ✓ (count per app) | When app running |

**Privacy**: No call recordings or message content. Only metadata is logged.

## Background Sync

### Desktop Apps
- Sync interval: Every 5 minutes
- Background: Runs as system tray app
- Offline queue: Up to 10,000 records
- Retry: Exponential backoff (1min → 1hour)

### iOS App
- Sync interval: Background tasks (4x daily) + manual
- Background modes: BGProcessingTask (30s limit)
- Offline queue: File-based, survives app restart
- Retry: Exponential backoff with notifications

**Force Sync**: Any client has a "Sync Now" button

## Data Storage

### Database Schema

```sql
-- Health data (hypertable)
CREATE TABLE health_data (
    timestamp TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    data_type TEXT NOT NULL,
    value DOUBLE PRECISION NOT NULL,
    unit TEXT NOT NULL
);

-- Productivity data (hypertable)
CREATE TABLE productivity_data (
    timestamp TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    app_name TEXT NOT NULL,
    window_title TEXT,
    category TEXT,
    duration_seconds INTEGER NOT NULL,
    platform TEXT NOT NULL
);

-- Location data (hypertable)
CREATE TABLE location_data (
    timestamp TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION,
    altitude DOUBLE PRECISION
);
```

### Continuous Aggregates

Pre-computed views for fast queries:
- Hourly step counts
- Daily screen time
- Weekly productivity summaries
- Monthly location statistics

**Retention**: Infinite raw storage (user requirement)

## Privacy & Security

- **Local-First**: All data on your home server
- **No Cloud**: No third-party services or analytics
- **HTTPS**: Encrypted communication (configure SSL cert)
- **API Keys**: Simple authentication (upgrade to OAuth for production)
- **Data Minimization**: Only collect necessary metrics

### Data Access

- **Server**: `~/.config/lifelens/config.json`
- **Desktop**: `~/Library/Application Support/LifeLens/`
- **iOS**: iOS Sandbox (app-encrypted)

## Known Limitations

### iOS 7-Day Provisioning Expiry

**Issue**: Free Apple ID apps expire after 7 days.

**Solution**: Automated rebuild script
```bash
./scripts/ios-rebuild.sh check    # Check days until expiry
./scripts/ios-rebuild.sh rebuild  # Rebuild and reinstall
```

**Scheduling**: Run daily via launchd (see [scripts/README.md](scripts/README.md))

### Location Tracking Granularity

**Issue**: `significantLocationChanges` triggers on cell tower changes (~500m-1km), not continuous GPS.

**Impact**:
- Short trips (<500m) may not be captured
- Urban movement may not trigger updates
- Not suitable for detailed route tracking

**Reason**: Battery optimization. Continuous GPS drains battery in 2-3 hours.

### Notification Tracking

**Issue**: iOS prevents reading notification content or historical counts.

**Workaround**: Only counts notifications while LifeLens is running. Keep app in background for better coverage.

### CallKit Outgoing Calls

**Issue**: Cannot detect outgoing calls in real-time via native Phone app.

**Workaround**: Uses call history log (CNCallRecordChangeHistoryEvent) fetched hourly.

## Project Structure

```
LifeLens/
├── ios/                    # iOS app (SwiftUI + HealthKit)
│   ├── LifeLens/
│   │   ├── Models/         # Data models
│   │   ├── Services/       # HealthKit, Location, Network
│   │   ├── Views/          # SwiftUI views
│   │   └── Assets.xcassets
│   ├── README.md           # iOS-specific docs
│   └── Info.plist
├── desktop/                # Electron apps (macOS + Windows)
│   ├── src/
│   │   ├── main/           # Main process
│   │   ├── renderer/       # UI (React)
│   │   └── shared/         # TypeScript types
│   ├── package.json
│   └── electron.vite.config.ts
├── server/                 # FastAPI backend
│   ├── app/
│   │   ├── api/            # REST endpoints
│   │   ├── models/         # SQLAlchemy models
│   │   ├── services/       # Business logic
│   │   └── db/             # Database connection
│   ├── alembic/            # Database migrations
│   ├── docker-compose.yml
│   └── Dockerfile
├── dashboard/              # React web UI
│   ├── src/
│   │   ├── components/     # shadcn/ui + custom
│   │   ├── lib/            # API client
│   │   └── pages/          # Route pages
│   └── package.json
├── scripts/                # Automation scripts
│   ├── ios-rebuild.sh      # iOS 7-day refresh
│   └── README.md           # Scripts documentation
├── tests/
│   ├── integration/        # E2E tests
│   └── manual/             # Test checklist
└── docs/
    └── plans/              # Implementation plan
```

## Configuration

### Server

**Environment Variables** (`.env`):
```bash
DATABASE_URL=postgresql+asyncpg://lifelens:lifelens@db:5432/lifelens
API_KEY=test-key
SERVER_PORT=8000
```

**Docker Compose** (`docker-compose.yml`):
```yaml
services:
  db:
    image: timescale/timescaledb:latest-pg16
    environment:
      POSTGRES_DB: lifelens
      POSTGRES_USER: lifelens
      POSTGRES_PASSWORD: lifelens
    volumes:
      - db_data:/var/lib/postgresql/data

  server:
    build: .
    ports:
      - "8000:8000"
    depends_on:
      - db
```

### Desktop

**Config File** (`~/.config/lifelens/config.json`):
```json
{
  "serverUrl": "http://192.168.1.100:8000",
  "apiKey": "test-key",
  "trackingIntervalSeconds": 5,
  "uploadIntervalMinutes": 5
}
```

### iOS

**UserDefaults** (set in app Settings):
```swift
UserDefaults.standard.set("http://192.168.1.100:8000", forKey: "server_url")
UserDefaults.standard.set("test-key", forKey: "api_key")
```

## Testing

### Automated Tests

```bash
# Server tests
cd server
pytest

# Integration tests
cd tests/integration
pytest test_e2e.py

# Dashboard tests (TODO)
cd dashboard
npm test
```

### Manual Testing

See [tests/manual/test_checklist.md](tests/manual/test_checklist.md) for comprehensive E2E testing procedures.

### Test Coverage

- Unit tests: Server API endpoints
- Integration tests: Data flow from ingestion to query
- Manual tests: Cross-platform, offline scenario, performance

## Troubleshooting

### Server Issues

**Server won't start:**
```bash
docker-compose logs server
docker-compose ps
```

**Database connection failed:**
```bash
docker-compose logs db
docker-compose exec db psql -U lifelens -d lifelens -c "SELECT 1;"
```

### Desktop Issues

**App crashes on launch:**
- Check logs: `~/Library/Logs/LifeLens/` (macOS) or `%APPDATA%\LifeLens\logs\` (Windows)
- Verify Node.js version: `node --version` (should be 20+)

**No window tracking:**
- Grant accessibility permissions (prompted on first launch)
- macOS: System Settings → Privacy & Security → Accessibility
- Windows: Run as administrator (for input hooks)

### iOS Issues

**App won't install:**
- Trust developer: iPhone Settings → General → VPN & Device Management → Trust
- Check provisioning: `./scripts/ios-rebuild.sh check`

**No health data:**
- Grant HealthKit permission: iPhone Settings → Health → Data Access → LifeLens
- Check background refresh: iPhone Settings → General → Background App Refresh → LifeLens
- Generate data: Walk around or check Health app

**7-day expiry:**
- Run rebuild: `./scripts/ios-rebuild.sh rebuild`
- Schedule daily: See [scripts/README.md](scripts/README.md)

## Development

### Adding New Health Data Types

1. Add to `HealthDataType` enum in `ios/LifeLens/Models/HealthData.swift`
2. Add to `healthDataTypes` set in `HealthKitManager.swift`
3. Update conversion logic in `fetchData()`
4. Add icon in dashboard if needed

### Adding New Dashboard Charts

1. Create component in `dashboard/src/components/charts/`
2. Add API endpoint in `server/app/api/query.py`
3. Add route in `dashboard/src/App.tsx`
4. Fetch and display data in page component

### Server API Development

1. Add Pydantic model in `server/app/models/`
2. Add endpoint in `server/app/api/`
3. Add SQLAlchemy model in `server/app/db/models/`
4. Create migration: `alembic revision --autogenerate -m "description"`
5. Apply migration: `alembic upgrade head`

## Deployment

### Home Server (Systemd)

**Service File** (`/etc/systemd/system/lifelens.service`):
```ini
[Unit]
Description=LifeLens Server
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/user/LifeLens/server
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down

[Install]
WantedBy=multi-user.target
```

Enable: `sudo systemctl enable lifelens`

### Nginx Reverse Proxy

**Config** (`/etc/nginx/sites-available/lifelens`):
```nginx
server {
    listen 80;
    server_name lifelens.local;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### HTTPS (Self-Signed Cert)

```bash
# Generate cert
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Configure nginx
ssl_certificate /path/to/cert.pem;
ssl_certificate_key /path/to/key.pem;
```

## Performance

### Benchmarks

- **Ingestion**: 1000 records in <5 seconds
- **Query**: Aggregated queries <100ms
- **Dashboard**: Load time <2 seconds
- **Battery**: iOS <5% per day (Battery Saver mode)

### Optimization

- TimescaleDB hypertables for automatic partitioning
- Continuous aggregates for pre-computed queries
- Exponential backoff for retry logic
- Batch ingestion (100 records per request)

## Contributing

This is a personal project, but suggestions are welcome:

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push branch: `git push origin feature/amazing-feature`
5. Open Pull Request

## Roadmap

### Completed ✅
- Server infrastructure with TimescaleDB
- FastAPI backend with ingestion endpoints
- React web dashboard with data visualization
- Electron desktop apps (macOS + Windows)
- iOS app with HealthKit integration
- Location tracking with background sync
- Communication metadata tracking
- Error handling and offline queuing
- iOS 7-day rebuild automation

### Future 🔮
- AI-powered insights (activity patterns, productivity recommendations)
- Apple Watch companion app with complications
- Integration with third-party services (Strava, Oura, Whoop)
- Real-time WebSocket-based dashboard updates
- Export to CSV/JSON/PDF reports
- Natural language queries ("What was my average sleep this week?")
- Custom metrics and dashboards
- Alert system for unusual patterns

## License

Proprietary - Personal use only.

## Acknowledgments

- **TimescaleDB** for excellent time-series database
- **FastAPI** for modern Python web framework
- **shadcn/ui** for beautiful React components
- **HealthKit** for comprehensive health data access
- **active-win** for cross-platform window tracking

## Support

For issues or questions:
1. Check this README's Troubleshooting section
2. Check component-specific READMEs ([ios/README.md](ios/README.md), [scripts/README.md](scripts/README.md))
3. Review server logs: `docker-compose logs -f server`
4. Run manual test checklist: [tests/manual/test_checklist.md](tests/manual/test_checklist.md)

---

**Built with ❤️ for personal privacy and data ownership**
