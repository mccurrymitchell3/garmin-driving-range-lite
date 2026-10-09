#!/bin/sh
set -eu

SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2"
DEVICE="${1:-fr265}"
OUTPUT="${2:-/private/tmp/driving-range-beta-$DEVICE.prg}"

export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
export PATH="$JAVA_HOME/bin:$PATH"

# Beta build: same detector/UI code as production, plus SensorLogging,
# per-sample console output, and the debug swing timestamp FIT field.
java \
  -Xms128m \
  -Djava.awt.headless=true \
  -Dfile.encoding=UTF-8 \
  -classpath "$SDK/bin/monkeybrains.jar" \
  com.garmin.monkeybrains.Monkeybrains \
  -f monkey-beta.jungle \
  -o "$OUTPUT" \
  -y developer_key \
  -d "$DEVICE"
