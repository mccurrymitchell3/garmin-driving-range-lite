# Changelog

All notable changes to Garmin Driving Range Lite will be documented in this
file.

The project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Swing detection now consumes Garmin's high-frequency accelerometer batches at
  the fastest device-supported sample rate, capped at 100 Hz, instead of polling
  a single accelerometer reading from the UI timer.
- The 500 ms UI/activity timer remains separate from high-frequency swing
  sampling so display, heart-rate, calorie, and FIT refresh work does not run at
  the accelerometer sample rate.
- The existing swing magnitude threshold, 1.5-second lockout, and 3-second
  startup/resume warmup remain unchanged so sampling frequency can be evaluated
  independently.

## [1.0.0] - 2026-09-18

### Added

- Initial public release of Garmin Driving Range Lite.
- Golf FIT activity recording with elapsed time, heart rate, and calories.
- Automatic swing counting using accelerometer data.
- Manual swing-count adjustment using the watch's Up and Down buttons.
- Pause, resume, save, and discard controls.
- Garmin Connect integration with a cumulative swing-count chart and final
  swing count in the activity summary.
- Five-page post-activity summary for swings, calories, heart rate, training
  effect, and duration.
- Support for selected Garmin Forerunner, Fenix, Epix, Enduro, Instinct, Venu,
  and vivoactive devices.

[1.0.0]: https://github.com/mccurrymitchell3/garmin-driving-range-lite/releases/tag/v1.0.0
