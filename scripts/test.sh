#!/bin/zsh
# Usage: scripts/test.sh [simulator|iphone]
#   simulator  every unit and UI test on the iPhone 18 Pro simulator (default), including the Reminders app
#   iphone     the Apple Intelligence import tests on a connected, unlocked iPhone
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-simulator}" in
simulator)
    id=$(xcrun simctl list devices available | grep -m1 "iPhone 18 Pro (" | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}')
    xcrun simctl boot "$id" 2>/dev/null || true
    args=(-project MyFridge.xcodeproj -scheme MyFridge -destination "platform=iOS Simulator,id=$id" -parallel-testing-enabled NO)
    xcodebuild build-for-testing "${args[@]}"
    # The Reminders unit tests need access, and the Reminders UI tests reset it, so the unit tests go first.
    xcrun simctl privacy "$id" grant reminders com.ajake.MyFridge
    xcodebuild test-without-building "${args[@]}" -only-testing:MyFridgeTests
    xcodebuild test-without-building "${args[@]}" -only-testing:MyFridgeUITests
    ;;
iphone)
    # Physical iPhones have 8-16 hex UDIDs. Simulators use the longer 8-4-4-4-12 form.
    id=$(xcrun devicectl list devices | grep -E "connected" | grep -E "physical" | grep -oE '[0-9A-F]{8}-[0-9A-F]{16}' | head -1 || true)
    if [[ -z "$id" ]]; then
        echo "No iPhone connected. Plug it in, unlock it, and try again."
        exit 1
    fi
    # Only the on-device tests: the full suite includes an import test that clears the phone's pending reminders.
    xcodebuild test -project MyFridge.xcodeproj -scheme MyFridge -destination "platform=iOS,id=$id" -allowProvisioningUpdates \
        -only-testing:"MyFridgeTests/ItemParserTests/onDeviceModelParsesAmazonOrder()" \
        -only-testing:"MyFridgeTests/FixtureTests/onDeviceImportPlacesScreenshotItems()"
    ;;
*)
    echo "Usage: scripts/test.sh [simulator|iphone]"
    exit 1
    ;;
esac
