# LifeLens Desktop App

Electron-based desktop application for tracking productivity on macOS and Windows.

## Prerequisites

- Node.js 20+
- macOS or Windows

## Development

1. Install dependencies:
```bash
cd desktop
npm install
```

2. Run in development mode:
```bash
npm run dev
```

3. Build for production:
```bash
npm run build:mac   # macOS
npm run build:win   # Windows
```

## Features

- **Active Window Tracking**: Monitors which app/window is currently active
- **Automatic Categorization**: Categorizes apps as work/study/leisure/communication
- **Batch Upload**: Syncs to home server every 5 minutes
- **Offline Queue**: Stores data locally if server is unavailable
- **System Tray**: Runs in background, minimize to tray

## Platform-Specific Notes

### macOS
- Requires accessibility permissions for active window tracking
- System shows prompt on first launch
- To grant: System Settings → Privacy & Security → Accessibility → LifeLens

### Windows
- No special permissions required for window tracking
- Task 6 adds keyboard/mouse activity monitoring
- May require administrator privileges for global input hooks

## Configuration

Environment variables or config file:
```
LIFLENS_SERVER_URL=http://your-server:8000
LIFLENS_API_KEY=your-api-key
```

Default configuration:
- Device ID: `desktop-{platform}-{hostname}`
- Tracking interval: 5 seconds
- Upload interval: 5 minutes
- Queue limit: 10,000 records

## Data Collection

**Collected:**
- App name and window title
- Duration spent in each app
- Inferred category (work/study/leisure/communication)
- Timestamps

**NOT Collected (Privacy-respecting):**
- Actual keystrokes or mouse clicks (only counts per minute)
- Content of windows or messages
- Screenshots or recordings
- File contents

## Troubleshooting

**macOS accessibility permission denied:**
```
System Settings → Privacy & Security → Accessibility
Enable LifeLens
```

**App not tracking windows:**
- Check accessibility permissions (macOS)
- Check console logs for errors
- Verify server is reachable

**Sync failing:**
- Check LIFLENS_SERVER_URL is correct
- Verify API key is valid
- Check network connection
- Review queue status in app
