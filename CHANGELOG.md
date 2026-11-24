# Changelog

All notable changes to Garmin Driving Range Lite will be documented in this
file.

The project uses [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-11-24

### Added

- Animated activity save confirmation.
- Dedicated beta build with accelerometer diagnostics and FIT debug logging.

### Changed

- Increased accelerometer sampling frequency up to 100 Hz while retaining the 500 ms UI timer.
- Improved automatic swing detection using a two-stage acceleration pattern and per-sample timestamps.
- Increased swing cooldown to two seconds to reduce duplicate counts.
- Redesigned the post-activity summary with swing count, duration, and calories.
- Improved duration formatting for activities exceeding one hour.
- Separated production and beta diagnostics while maintaining a shared application codebase.

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

[1.1.0]: https://github.com/mccurrymitchell3/garmin-driving-range-lite/releases/tag/v1.1.0
[1.0.0]: https://github.com/mccurrymitchell3/garmin-driving-range-lite/releases/tag/v1.0.0
