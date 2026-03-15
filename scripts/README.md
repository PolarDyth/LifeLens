# iOS Rebuild Automation Scripts

This directory contains automation scripts for managing the LifeLens iOS app's 7-day provisioning expiration.

## Scripts

### `ios-rebuild.sh` - Main Rebuild Script

Automated rebuild script for iOS app with free Apple ID provisioning.

**Usage:**
```bash
./scripts/ios-rebuild.sh check    # Check days until expiry
./scripts/ios-rebuild.sh rebuild  # Rebuild and install to device
./scripts/ios-rebuild.sh auto     # Automatic mode (check + rebuild if needed)
```

**Features:**
- Checks provisioning profile expiry from built app
- Rebuilds 48 hours before expiration
- Auto-installs to connected iPhone via `ios-deploy`
- Sends macOS notifications on rebuild completion
- Color-coded output for easy reading

**Requirements:**
- macOS with Xcode installed
- `ios-deploy` for automated installation (`brew install ios-deploy`)
- Free Apple ID configured in Xcode
- Connected iPhone (for installation)

### `com.lifelens.ios-rebuild.plist` - Launchd Scheduler

macOS launchd agent for scheduling daily rebuild checks.

**Setup:**
```bash
# Update the script path in the plist file to your actual project path:
# /path/to/LifeLens/scripts/ios-rebuild.sh

# Copy to LaunchAgents
cp com.lifelens.ios-rebuild.plist ~/Library/LaunchAgents/

# Update the path in your copied file:
# Edit ~/Library/LaunchAgents/com.lifelens.ios-rebuild.plist
# Change /path/to/LifeLens to your actual project directory

# Load the agent
launchctl load ~/Library/LaunchAgents/com.lifelens.ios-rebuild.plist

# Check if it's loaded
launchctl list | grep lifelens

# View logs
tail -f /tmp/lifelens-ios-rebuild.log
```

**Uninstall:**
```bash
launchctl unload ~/Library/LaunchAgents/com.lifelens.ios-rebuild.plist
rm ~/Library/LaunchAgents/com.lifelens.ios-rebuild.plist
```

## Scheduling

The launchd agent runs daily at 9:00 AM by default. To customize:

```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>9</integer>     <!-- Change this for different hour (0-23) -->
    <key>Minute</key>
    <integer>0</integer>    <!-- Change this for different minute (0-59) -->
</dict>
```

## Expiry Thresholds

Configure in `ios-rebuild.sh`:

```bash
EXPIRY_THRESHOLD_HOURS=48      # Rebuild 48h before expiry
NOTIFICATION_THRESHOLD_HOURS=48 # Notify 48h before expiry
```

## Manual Workflow

If you prefer manual rebuilding:

1. **Check expiry daily:**
   ```bash
   ./scripts/ios-rebuild.sh check
   ```

2. **When < 2 days remaining:**
   ```bash
   ./scripts/ios-rebuild.sh rebuild
   ```

3. **Verify installation:**
   - Check iPhone for LifeLens app
   - Open app to verify it launches

## Troubleshooting

### "App not found at path"

The app hasn't been built yet. Build in Xcode first:
```bash
cd ios
xcodebuild -scheme LifeLens -configuration Release
```

### "Failed to parse expiration date"

Provisioning profile may be missing or corrupted. Clean and rebuild in Xcode.

### "ios-deploy not found"

Install ios-deploy:
```bash
brew install ios-deploy
```

### Launchd agent not running

Check logs:
```bash
cat /tmp/lifelens-ios-rebuild.err
```

Verify script path is correct in plist file.

### Build fails with code signing errors

1. Open Xcode
2. Select LifeLens project
3. Go to Signing & Capabilities
4. Ensure your team is selected
5. Try "Reset to Recommended Settings" if needed

## Advanced: Team ID Configuration

Update `ExportOptions.plist` with your actual Team ID:

1. Find your Team ID:
   - Xcode → Preferences → Accounts
   - Select your Apple ID
   - Look for "Team ID" (10-character string)

2. Update `scripts/ExportOptions.plist`:
   ```xml
   <key>teamID</key>
   <string>YOUR_ACTUAL_TEAM_ID</string>
   ```

## Integration with CI/CD

For GitHub Actions or other CI:

```yaml
name: Check iOS Expiry

on:
  schedule:
    - cron: '0 9 * * *'  # Daily at 9 AM UTC

jobs:
  check-expiry:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check iOS provisioning expiry
        run: ./scripts/ios-rebuild.sh check
```

## Notifications

The script sends macOS notifications for:

- ⚠️ 48 hours before expiry (rebuild soon)
- ✓ Successful rebuild completion
- ✗ Build failures

To customize, modify `send_notification()` function in `ios-rebuild.sh`.

## Logs

- Standard output: `/tmp/lifelens-ios-rebuild.log`
- Error output: `/tmp/lifelens-ios-rebuild.err`

## Security Notes

- Script requires Xcode and developer tools
- Provisioning profiles contain sensitive data - don't commit to git
- Keep `.mobileprovision` files private
- Never share your Apple ID credentials

## Alternative: Paid Developer Program

To avoid 7-day expiry entirely:
1. Join Apple Developer Program ($99/year)
2. Update provisioning in Xcode
3. No rebuild script needed (1-year certificates)

For most personal projects, the free tier + rebuild automation is sufficient.
