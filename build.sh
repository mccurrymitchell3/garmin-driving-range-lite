#!/bin/sh
set -eu

SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2"
DEVICE="${1:-fr265}"
OUTPUT="${2:-/private/tmp/driving-range-$DEVICE.prg}"

# Use JDK 17 explicitly because this local SDK/compiler combination is known
# to be stable with it.
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
export PATH="$JAVA_HOME/bin:$PATH"

# Run the compiler jar directly in headless mode to avoid macOS AWT startup
# issues seen with the SDK's monkeyc shell wrapper.
java \
  -Xms128m \
  -Djava.awt.headless=true \
  -Dfile.encoding=UTF-8 \
  -classpath "$SDK/bin/monkeybrains.jar" \
  com.garmin.monkeybrains.Monkeybrains \
  -f monkey.jungle \
  -o "$OUTPUT" \
  -y developer_key \
  -d "$DEVICE"
