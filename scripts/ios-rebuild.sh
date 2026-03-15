#!/bin/bash

##############################################################################
# LifeLens iOS 7-Day Provisioning Rebuild Script
##############################################################################
#
# This script checks the iOS app's provisioning profile expiry and rebuilds
# if needed. Designed for free Apple ID development (7-day expiry limit).
#
# Usage:
#   ./ios-rebuild.sh check       # Check days until expiry
#   ./ios-rebuild.sh rebuild     # Rebuild and install to connected device
#   ./ios-rebuild.sh auto        # Automatic mode (check + rebuild if needed)
#
# Scheduling (macOS launchd):
#   Run daily: Copy ios-rebuild-com.laud.plist to ~/Library/LaunchAgents/
#   load: launchctl load ~/Library/LaunchAgents/ios-rebuild-com.laud.plist
#
##############################################################################

set -e  # Exit on error

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="${PROJECT_DIR}/ios"
SCHEME_NAME="LifeLens"
BUILD_CONFIG="Release"
DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData"
APP_NAME="LifeLens.app"
ARCHIVE_PATH="${PROJECT_DIR}/build/LifeLens.xcarchive"

# Notification thresholds
EXPIRY_THRESHOLD_HOURS=48  # Rebuild 48 hours before expiry
NOTIFICATION_THRESHOLD_HOURS=48  # Notify user 48 hours before expiry

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

##############################################################################
# Helper Functions
##############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

send_notification() {
    local title="$1"
    local message="$2"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: Use osascript
        osascript -e "display notification \"$message\" with title \"$title\" sound default"
    else
        # Fallback: echo
        echo "[$title] $message"
    fi
}

##############################################################################
# Provisioning Check Functions
##############################################################################

get_provisioning_expiry() {
    local app_path="$1"

    if [[ ! -d "$app_path" ]]; then
        log_error "App not found at $app_path"
        echo "0"
        return 1
    fi

    local provisioning_path="$app_path/embedded.mobileprovision"

    if [[ ! -f "$provisioning_path" ]]; then
        log_error "Provisioning profile not found"
        echo "0"
        return 1
    fi

    # Extract expiration date from provisioning profile
    local expiration_date
    expiration_date=$(security cms -D -i "$provisioning_path" 2>/dev/null | \
        plutil -extract ExpirationDate raw - 2>/dev/null | \
        tr -d 'Z"')

    if [[ -z "$expiration_date" ]]; then
        log_error "Failed to parse expiration date"
        echo "0"
        return 1
    fi

    # Convert to timestamp
    local expiry_timestamp
    expiry_timestamp=$(date -j -f "%Y-%m-%d %H:%M:%S" "$expiration_date" +%s 2>/dev/null || echo "0")

    echo "$expiry_timestamp"
}

check_days_until_expiry() {
    local app_path="${DERIVED_DATA}/Build/Products/${BUILD_CONFIG}-iphoneos/${APP_NAME}"

    if [[ ! -d "$app_path" ]]; then
        log_warning "App not built yet. Cannot check expiry."
        echo "-1"
        return
    fi

    local expiry_timestamp
    expiry_timestamp=$(get_provisioning_expiry "$app_path")

    if [[ "$expiry_timestamp" == "0" ]]; then
        echo "-1"
        return
    fi

    local current_timestamp
    current_timestamp=$(date +%s)

    local seconds_until_expiry=$((expiry_timestamp - current_timestamp))
    local days_until_expiry=$((seconds_until_expiry / 86400))

    echo "$days_until_expiry"
}

format_expiry_date() {
    local app_path="${DERIVED_DATA}/Build/Products/${BUILD_CONFIG}-iphoneos/${APP_NAME}"

    if [[ ! -d "$app_path" ]]; then
        echo "Unknown (app not built)"
        return
    fi

    local provisioning_path="$app_path/embedded.mobileprovision"
    local expiration_date
    expiration_date=$(security cms -D -i "$provisioning_path" 2>/dev/null | \
        plutil -extract ExpirationDate raw - 2>/dev/null | \
        tr -d 'Z"')

    if [[ -n "$expiration_date" ]]; then
        echo "$expiration_date"
    else
        echo "Unknown"
    fi
}

##############################################################################
# Build Functions
##############################################################################

clean_build() {
    log_info "Cleaning previous build..."

    # Remove derived data
    rm -rf "${DERIVED_DATA}/${SCHEME_NAME}-"* 2>/dev/null || true

    # Clean build folder
    cd "$IOS_DIR"
    xcodebuild clean -scheme "$SCHEME_NAME" -configuration "$BUILD_CONFIG" >/dev/null 2>&1 || true

    log_success "Clean completed"
}

build_app() {
    log_info "Building $SCHEME_NAME..."

    cd "$IOS_DIR"

    # Build archive
    xcodebuild archive \
        -scheme "$SCHEME_NAME" \
        -archivePath "$ARCHIVE_PATH" \
        -configuration "$BUILD_CONFIG" \
        -allowProvisioningUpdates \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        | xcpretty || xcodebuild archive \
        -scheme "$SCHEME_NAME" \
        -archivePath "$ARCHIVE_PATH" \
        -configuration "$BUILD_CONFIG" \
        -allowProvisioningUpdates \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO

    # Export IPA
    local export_options_plist="${PROJECT_DIR}/scripts/ExportOptions.plist"

    if [[ ! -f "$export_options_plist" ]]; then
        log_warning "ExportOptions.plist not found, creating..."
        create_export_options "$export_options_plist"
    fi

    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "${PROJECT_DIR}/build" \
        -exportOptionsPlist "$export_options_plist" \
        | xcpretty || xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "${PROJECT_DIR}/build" \
        -exportOptionsPlist "$export_options_plist"

    log_success "Build completed"
}

create_export_options() {
    local plist_path="$1"

    cat > "$plist_path" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <false/>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

    log_warning "Please update YOUR_TEAM_ID in $plist_path"
}

install_to_device() {
    log_info "Checking for connected iOS device..."

    # Check if ios-deploy is installed
    if ! command -v ios-deploy &> /dev/null; then
        log_warning "ios-deploy not found. Installing..."
        brew install ios-deploy 2>/dev/null || true
    fi

    if command -v ios-deploy &> /dev/null; then
        local ipa_path="${PROJECT_DIR}/build/${SCHEME_NAME}.ipa"

        if [[ -f "$ipa_path" ]]; then
            log_info "Installing to device..."
            ios-deploy --bundle "$ipa_path" --no-wifi || log_warning "Auto-install failed"
            log_success "Install completed"
        else
            log_warning "IPA not found at $ipa_path"
        fi
    else
        log_warning "ios-deploy not available. Please install manually."
    fi
}

##############################################################################
# Main Commands
##############################################################################

cmd_check() {
    log_info "Checking provisioning expiry..."

    local days_until_expiry
    days_until_expiry=$(check_days_until_expiry)

    if [[ "$days_until_expiry" == "-1" ]]; then
        log_warning "Unable to check expiry (app not built or profile missing)"
        return 1
    fi

    local expiry_date
    expiry_date=$(format_expiry_date)

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Provisioning Expiry Check"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Days until expiry:  $days_until_expiry"
    echo "  Expiration date:     $expiry_date"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ "$days_until_expiry" -le "$((NOTIFICATION_THRESHOLD_HOURS / 24))" ]]; then
        log_warning "⚠️  App expires in $days_until_expiry days!"
        send_notification "LifeLens iOS Expiring" "App expires in $days_until_expiry days. Run rebuild soon."
    elif [[ "$days_until_expiry" -le 3 ]]; then
        log_warning "App expires in $days_until_expiry days"
    else
        log_success "App is valid for $days_until_expiry more days"
    fi
}

cmd_rebuild() {
    log_info "Starting rebuild process..."

    cmd_check

    local days_until_expiry
    days_until_expiry=$(check_days_until_expiry)

    # Check if rebuild is needed
    if [[ "$days_until_expiry" != "-1" ]] && [[ "$days_until_expiry" -gt "$((EXPIRY_THRESHOLD_HOURS / 24))" ]]; then
        log_info "No rebuild needed (expires in $days_until_expiry days)"
        return 0
    fi

    echo ""
    log_warning "Rebuilding app (expires in $days_until_expiry days)..."

    clean_build
    build_app
    install_to_device

    echo ""
    log_success "✓ Rebuild completed!"

    send_notification "LifeLens iOS Rebuilt" "App successfully rebuilt and installed."
}

cmd_auto() {
    log_info "Automatic rebuild check..."

    local days_until_expiry
    days_until_expiry=$(check_days_until_expiry)

    if [[ "$days_until_expiry" == "-1" ]]; then
        log_warning "Cannot determine expiry. Skipping rebuild."
        return 1
    fi

    if [[ "$days_until_expiry" -le "$((EXPIRY_THRESHOLD_HOURS / 24))" ]]; then
        log_warning "Expiry threshold reached. Rebuilding..."
        cmd_rebuild
    else
        log_success "No rebuild needed ($days_until_expiry days until expiry)"
    fi
}

##############################################################################
# Script Entry Point
##############################################################################

main() {
    local command="${1:-check}"

    case "$command" in
        check)
            cmd_check
            ;;
        rebuild)
            cmd_rebuild
            ;;
        auto)
            cmd_auto
            ;;
        *)
            echo "Usage: $0 {check|rebuild|auto}"
            echo ""
            echo "Commands:"
            echo "  check    - Check provisioning expiry"
            echo "  rebuild  - Rebuild and install app"
            echo "  auto     - Automatic mode (check + rebuild if needed)"
            exit 1
            ;;
    esac
}

main "$@"
