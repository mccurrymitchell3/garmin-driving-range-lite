# Garmin Driving Range Lite

![Garmin Driving Range Lite at the driving range](img/Driving_Range_Hero_Image.png)

Garmin Driving Range Lite is a free, simple Garmin Connect IQ watch app for
basic driving range practice. It records a golf FIT activity, counts swings, and
shows a short recap after the activity is saved.

This repository is intended to be public so other Connect IQ developers can see
the project structure, app lifecycle, FIT recording, custom FIT fields, and
simple sensor-based swing counting.

## Features

- Starts a golf FIT activity when the app opens.
- Tracks elapsed time, heart rate, swing count, and Garmin activity calories.
- Detects swings from accelerometer peaks with a short warmup period after
  start/resume to avoid startup sensor noise.
- Lets the user adjust swings manually with `Up` and `Down`.
- Uses `Start`/`Enter`/`Menu` to pause, resume, save, or discard.
- Saves a custom FIT developer field named `Swing Count` on record and session
  messages.
- Shows a five-page saved-activity recap for swings, calories, heart rate,
  training effect, and duration.

## Controls

- `Start`, `Enter`, or `Menu`: open the pause menu.
- `Up`: add one swing.
- `Down`: subtract one swing, stopping at zero.
- Summary screen `Up`/`Down`: move through recap pages.
- Summary screen select/back/menu: exit the app.

Screen taps, holds, releases, swipes, and the back button are consumed during
the activity so the session is not accidentally interrupted.

## Preview

<p align="center">
  <img src="img/Activity_Watch_Face.png" alt="Driving Range Lite activity screen on a Garmin watch" width="262">
  &nbsp;&nbsp;
  <img src="img/Garmin_Driving_Range_Watch_Display.png" alt="Driving Range Lite running during a range session" width="265">
</p>

<p align="center">
  <img src="img/Driving_Range_Cover_Image.png" alt="Driving Range Lite Connect IQ store artwork" width="380">
</p>

## Project Layout

- `manifest.xml`: Connect IQ app metadata, supported devices, and permissions.
- `monkey.jungle`: Garmin project file.
- `img/`: screenshots and artwork used by this README and the store listing.
- `resources/`: app strings, drawables, and launcher icon.
- `source/RangeApp.mc`: app entry point and lifecycle bridge.
- `source/RangeView.mc`: activity recording, sensors, FIT fields, and main UI.
- `source/RangeDelegate.mc`: in-activity input handling.
- `source/RangeMenuDelegate.mc`: pause menu actions.
- `source/RangeSummaryView.mc`: saved-activity recap pages.
- `build.sh`: local helper for building a device `.prg`.

## Requirements

- Garmin Connect IQ SDK.
- Garmin Monkey C extension for Visual Studio Code, recommended for simulator,
  device builds, and store export.
- JDK 17 for the included `build.sh` workflow.
- A private Garmin developer key for signing local builds and store packages.

Do not commit your developer key. This repo ignores `developer_key`, `.der`,
`.key`, and `.pem` files by default.

## Local Build

This repo includes a macOS helper script pointed at the local SDK path currently
used during development:

```sh
~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2
```

Build for Forerunner 265:

```sh
./build.sh
```

Build for another device listed in `manifest.xml`:

```sh
./build.sh fr965
```

The script writes the `.prg` to `/private/tmp` by default:

```sh
/private/tmp/driving-range-fr265.prg
```

On this macOS/JDK setup, Garmin's `monkeyc` shell wrapper can abort while
initializing Java AWT. The build script runs `monkeybrains.jar` directly in
headless mode with JDK 17.

## Publishing To Garmin Connect IQ

For Garmin Connect IQ Store submission, export an `.iq` package rather than a
single-device `.prg`.

Recommended path:

1. Open the project in Visual Studio Code.
2. Run `Monkey C: Verify Installation` from the command palette.
3. Test the app in the simulator and on at least one real device.
4. Run `Monkey C: Export Project`.
5. Select the products/languages to include.
6. Upload the generated `.iq` file in the Garmin Connect IQ developer dashboard.

Command-line equivalent:

```sh
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
export PATH="$JAVA_HOME/bin:$PATH"

java \
  -Xms128m \
  -Djava.awt.headless=true \
  -Dfile.encoding=UTF-8 \
  -classpath "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2/bin/monkeybrains.jar" \
  com.garmin.monkeybrains.Monkeybrains \
  -e \
  -f monkey.jungle \
  -o /private/tmp/garmin-driving-range-lite.iq \
  -y /path/to/private/developer_key
```

Generated `.prg`, `.iq`, MIR, cache, and debug build artifacts are intentionally
ignored by Git.
