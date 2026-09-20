import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Sensor;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.UserProfile;
import Toybox.WatchUi;

class RangeView extends WatchUi.View {
    // Tune these together: threshold catches a full swing impulse, while the
    // lockout prevents one swing from being counted multiple times.
    private const SWING_THRESHOLD = 2600.0;
    private const SWING_LOCKOUT_MS = 1500;
    private const SENSOR_WARMUP_MS = 3000;

    // FIT developer field numbers must be stable once public FIT files exist.
    private const FIT_FIELD_SWING_COUNT_RECORD = 0;
    private const FIT_FIELD_SWING_COUNT_SESSION = 1;

    private var _session as Session?;
    private var _swingCountRecordField as Field?;
    private var _swingCountSessionField as Field?;
    private var _timer as Timer.Timer?;
    private var _startTime as Moment?;
    private var _heartRate as Number;
    private var _maxHeartRate as Number;
    private var _heartRateTotal as Number;
    private var _heartRateSamples as Number;
    private var _trainingEffect as Float?;
    private var _calories as Number;
    private var _swingCount as Number;
    private var _lastSwingTime as Number;
    private var _autoDetectReadyAt as Number;
    private var _elapsedBeforePause as Number;
    private var _isPaused as Boolean;
    private var _isFinished as Boolean;
    private var _optionsOpen as Boolean;
    private var _hrZones as Array<Number>;

    function initialize() {
        View.initialize();
        _session = null;
        _swingCountRecordField = null;
        _swingCountSessionField = null;
        _timer = null;
        _startTime = null;
        _heartRate = 0;
        _maxHeartRate = 0;
        _heartRateTotal = 0;
        _heartRateSamples = 0;
        _trainingEffect = null;
        _calories = 0;
        _swingCount = 0;
        _lastSwingTime = 0;
        _autoDetectReadyAt = 0;
        _elapsedBeforePause = 0;
        _isPaused = false;
        _isFinished = false;
        _optionsOpen = false;

        // Fallback zone boundaries are replaced by the user's Garmin profile
        // zones when the device exposes them.
        _hrZones = [100, 120, 140, 160, 180, 200];
        loadHeartRateZones();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        // The first show starts recording; returning from overlays resumes the
        // timer as long as the activity was not paused from the menu.
        if (!_isFinished) {
            if (_session == null) {
                startActivity();
            } else if (!_isPaused) {
                startTimer();
            }
        }
    }

    function onHide() as Void {
        stopTimer();
    }

    function startActivity() as Void {
        _startTime = Time.now();
        _elapsedBeforePause = 0;
        _isPaused = false;
        _isFinished = false;
        armAutoDetection();

        // ActivityRecording may not exist on every API/runtime, so guard it
        // before creating the FIT session.
        if ((Toybox has :ActivityRecording) && (_session == null)) {
            _session = ActivityRecording.createSession({
                :name => "Range",
                :sport => Activity.SPORT_GOLF,
                :subSport => Activity.SUB_SPORT_GENERIC
            });
            _session.start();
            createFitFields();
        }

        writeFitFields();
        startTimer();
    }

    function startTimer() as Void {
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTimer), 100, true);
        }
    }

    function stopActivity() as Void {
        if (!_isFinished) {
            saveActivity();
        }
    }

    function pauseActivity() as Void {
        if (_isFinished || _isPaused) {
            return;
        }

        // Preserve elapsed app time separately from Garmin's recording state so
        // the on-screen timer resumes from the same value.
        _elapsedBeforePause = getElapsedSeconds();
        _isPaused = true;
        stopTimer();

        if ((_session != null) && _session.isRecording()) {
            _session.stop();
        }

        WatchUi.requestUpdate();
    }

    function resumeActivity() as Void {
        if (_isFinished || !_isPaused) {
            return;
        }

        // Reset the start moment for the next active segment. The previous
        // active duration remains in _elapsedBeforePause.
        _startTime = Time.now();
        _isPaused = false;
        armAutoDetection();

        if ((_session != null) && !_session.isRecording()) {
            _session.start();
        }

        writeFitFields();
        startTimer();
        WatchUi.requestUpdate();
    }

    function saveActivity() as Void {
        if (_isFinished) {
            return;
        }

        stopTimer();

        var session = _session;
        if (session != null) {
            // Write once before stopping and again before saving so both record
            // and session developer fields have the final swing count.
            if (session.isRecording()) {
                writeFitFields();
                session.stop();
            }
            writeFitFields();
            session.save();
            _session = null;
            clearFitFields();
        }

        _isFinished = true;
        WatchUi.requestUpdate();
    }

    function discardActivity() as Void {
        if (_isFinished) {
            return;
        }

        stopTimer();

        if (_session != null) {
            if (_session.isRecording()) {
                _session.stop();
            }
            _session.discard();
            _session = null;
            clearFitFields();
        }

        _isFinished = true;
        System.exit();
    }

    function stopTimer() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function addSwing() as Void {
        if (_isPaused || _isFinished) {
            return;
        }

        // Manual adjustments update FIT data immediately so save/stop paths do
        // not need to infer pending changes.
        _swingCount++;
        writeFitFields();
        WatchUi.requestUpdate();
    }

    function subtractSwing() as Void {
        if (_isPaused || _isFinished) {
            return;
        }

        if (_swingCount > 0) {
            _swingCount--;
            writeFitFields();
            WatchUi.requestUpdate();
        }
    }

    function isOptionsOpen() as Boolean {
        return _optionsOpen;
    }

    function setOptionsOpen(open as Boolean) as Void {
        _optionsOpen = open;
    }

    function armAutoDetection() as Void {
        var now = System.getTimer();

        // Startup and resume can produce noisy accelerometer samples; delay
        // auto-counting briefly and use this time as the first lockout anchor.
        _lastSwingTime = now;
        _autoDetectReadyAt = now + SENSOR_WARMUP_MS;
    }

    function onTimer() as Void {
        readSensors();
        writeFitFields();
        WatchUi.requestUpdate();
    }

    function loadHeartRateZones() as Void {
        var profileZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);

        if ((profileZones != null) && (profileZones.size() >= 6)) {
            _hrZones = profileZones;
        }
    }

    function readSensors() as Void {
        var info = Sensor.getInfo();
        var activityInfo = Activity.getActivityInfo();

        // Devices and API levels expose live heart rate through different
        // fields, so try the most direct sensor values before activity info.
        if ((info has :heartRate) && (info.heartRate != null)) {
            updateHeartRate(info.heartRate as Number);
        } else if ((info has :currentHeartRate) && (info.currentHeartRate != null)) {
            updateHeartRate(info.currentHeartRate as Number);
        } else if ((activityInfo has :currentHeartRate) && (activityInfo.currentHeartRate != null)) {
            updateHeartRate(activityInfo.currentHeartRate as Number);
        }

        if ((activityInfo has :averageHeartRate) && (activityInfo.averageHeartRate != null)) {
            // Prefer Garmin's activity average when available because it is the
            // same value that users expect to see in saved activities.
            _heartRateTotal = activityInfo.averageHeartRate as Number;
            _heartRateSamples = 1;
        }

        if ((activityInfo has :maxHeartRate) && (activityInfo.maxHeartRate != null)) {
            _maxHeartRate = activityInfo.maxHeartRate as Number;
        }

        if ((activityInfo has :trainingEffect) && (activityInfo.trainingEffect != null)) {
            _trainingEffect = activityInfo.trainingEffect as Float;
        }

        if ((activityInfo has :calories) && (activityInfo.calories != null)) {
            _calories = activityInfo.calories as Number;
        }

        if ((info has :accel) && (info.accel != null)) {
            var accel = info.accel as Array<Float>;

            if (accel.size() >= 3) {
                var x = accel[0];
                var y = accel[1];
                var z = accel[2];
                var mag = Math.sqrt((x * x) + (y * y) + (z * z));

                var now = System.getTimer();
                if (now < _autoDetectReadyAt) {
                    return;
                }

                // Count high-magnitude acceleration spikes as swings, then
                // ignore nearby samples until the lockout window has passed.
                if ((mag > SWING_THRESHOLD) && ((now - _lastSwingTime) > SWING_LOCKOUT_MS)) {
                    _lastSwingTime = now;
                    _swingCount++;
                    writeFitFields();
                }
            }
        }
    }

    function createFitFields() as Void {
        var session = _session;

        if ((session != null) && (session has :createField)) {
            // The record field lets analysis tools see swing count over time.
            if (_swingCountRecordField == null) {
                _swingCountRecordField = session.createField(
                    "Swing Count",
                    FIT_FIELD_SWING_COUNT_RECORD,
                    FitContributor.DATA_TYPE_UINT16,
                    {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "swings"}
                );
            }

            // The session field stores the final value at the activity level.
            if (_swingCountSessionField == null) {
                _swingCountSessionField = session.createField(
                    "Swing Count",
                    FIT_FIELD_SWING_COUNT_SESSION,
                    FitContributor.DATA_TYPE_UINT16,
                    {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "swings"}
                );
            }
        }
    }

    function writeFitFields() as Void {
        if (_swingCountRecordField != null) {
            _swingCountRecordField.setData(_swingCount as Object);
        }

        if (_swingCountSessionField != null) {
            _swingCountSessionField.setData(_swingCount as Object);
        }
    }

    function clearFitFields() as Void {
        _swingCountRecordField = null;
        _swingCountSessionField = null;
    }

    function updateHeartRate(heartRate as Number) as Void {
        if (heartRate <= 0) {
            return;
        }

        _heartRate = heartRate;
        _heartRateTotal += heartRate;
        _heartRateSamples++;

        if (heartRate > _maxHeartRate) {
            _maxHeartRate = heartRate;
        }
    }

    function getSummary() as Dictionary {
        // Snapshot values before replacing the activity view with the summary.
        return {
            :elapsedSeconds => getElapsedSeconds(),
            :swingCount => _swingCount,
            :currentHeartRate => _heartRate,
            :averageHeartRate => getAverageHeartRate(),
            :maxHeartRate => _maxHeartRate,
            :trainingEffect => _trainingEffect,
            :calories => _calories
        };
    }

    function getAverageHeartRate() as Number {
        if (_heartRateSamples > 0) {
            return _heartRateTotal / _heartRateSamples;
        }

        return 0;
    }

    function onUpdate(dc as Dc) as Void {
        var activityInfo = Activity.getActivityInfo();

        // Calories are managed by Garmin's activity engine; read them during
        // draw as well so the screen stays current between timer ticks.
        if ((activityInfo has :calories) && (activityInfo.calories != null)) {
            _calories = activityInfo.calories as Number;
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        var elapsedSec = getElapsedSeconds();
        var minutes = elapsedSec / 60;
        var seconds = elapsedSec % 60;
        var timeStr = minutes.format("%02d") + ":" + seconds.format("%02d");
        var hrStr = (_heartRate > 0) ? _heartRate.toString() : "--";

        drawHrGauge(dc, width, height);
        drawActivityGrid(dc, width, height);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 7) / 100, Graphics.FONT_XTINY, "TIMER", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 15) / 100, Graphics.FONT_LARGE, timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText((width * 25) / 100, (height * 35) / 100, Graphics.FONT_XTINY, "SWINGS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText((width * 75) / 100, (height * 35) / 100, Graphics.FONT_XTINY, "CALORIES", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText((width * 25) / 100, (height * 44) / 100, Graphics.FONT_LARGE, _swingCount.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText((width * 75) / 100, (height * 44) / 100, Graphics.FONT_LARGE, _calories.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 64) / 100, Graphics.FONT_XTINY, "HEART RATE", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 72) / 100, Graphics.FONT_LARGE, hrStr, Graphics.TEXT_JUSTIFY_CENTER);

    }

    function drawActivityGrid(dc as Dc, width as Number, height as Number) as Void {
        var left = (width * 10) / 100;
        var right = width - left;
        var topDivider = (height * 32) / 100;
        var hrDivider = (height * 62) / 100;
        var centerX = width / 2;
        var verticalTop = (height * 32) / 100;
        var verticalBottom = (height * 62) / 100;

        // Thin red separators create the main three-zone dashboard without
        // needing image resources for each supported screen size.
        drawFadedRedLine(dc, left, right, topDivider);
        drawFadedRedLine(dc, left, right, hrDivider);
        drawSolidRedVerticalLine(dc, centerX, verticalTop, verticalBottom);
    }

    function drawFadedRedLine(dc as Dc, startX as Number, endX as Number, y as Number) as Void {
        var totalWidth = endX - startX;
        var halfWidth = totalWidth / 2.0;
        var centerX = startX + halfWidth;
        var step = 4;

        dc.setPenWidth(2);

        for (var x = startX; x < endX; x += step) {
            var distFromCenter = x - centerX;

            if (distFromCenter < 0) {
                distFromCenter = -distFromCenter;
            }

            dc.setColor(getFadedRedColor(1.0 - (distFromCenter / halfWidth)), Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x, y, x + step, y);
        }

        dc.setPenWidth(1);
    }

    function drawSolidRedVerticalLine(dc as Dc, x as Number, startY as Number, endY as Number) as Void {
        dc.setPenWidth(2);
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, startY, x, endY);
        dc.setPenWidth(1);
    }

    function getFadedRedColor(factor as Float) as Number {
        if (factor > 0.4) {
            return Graphics.COLOR_RED;
        } else if (factor > 0.2) {
            return Graphics.COLOR_DK_RED;
        } else if (factor > 0.1) {
            return Graphics.COLOR_DK_GRAY;
        }

        return Graphics.COLOR_BLACK;
    }

    function drawHrGauge(dc as Dc, width as Number, height as Number) as Void {
        var center = width / 2;
        var radius = center - 8;
        var penWidth = 8;
        var startAngle = 210;
        var totalArc = 120;
        var arcPerZone = totalArc / 5;

        // Draw five colored segments across the top of the screen as a compact
        // heart-rate zone gauge.
        dc.setPenWidth(penWidth);

        for (var i = 0; i < 5; i++) {
            var zStart = startAngle + (i * arcPerZone);
            var zEnd = zStart + arcPerZone - 2;

            dc.setColor(getHeartRateZoneColor(i), Graphics.COLOR_TRANSPARENT);
            dc.drawArc(center, center, radius, Graphics.ARC_COUNTER_CLOCKWISE, zStart, zEnd);
        }

        dc.setPenWidth(1);

        if (_heartRate > 0) {
            drawHeartRateIndicator(dc, center, radius, startAngle, totalArc);
        }
    }

    function drawHeartRateIndicator(dc as Dc, center as Number, radius as Number, startAngle as Number, totalArc as Number) as Void {
        var minHr = _hrZones[0];
        var maxHr = _hrZones[5];
        var currentHrClamped = _heartRate;

        // Clamp before mapping to the arc so the indicator always stays on the
        // gauge even when current HR is outside the user's configured zones.
        if (currentHrClamped < minHr) {
            currentHrClamped = minHr;
        }

        if (currentHrClamped > maxHr) {
            currentHrClamped = maxHr;
        }

        if (maxHr <= minHr) {
            return;
        }

        var pct = (currentHrClamped - minHr).toFloat() / (maxHr - minHr).toFloat();
        var indicatorAngle = startAngle + (pct * totalArc);
        var radians = Math.toRadians(indicatorAngle);
        var px = center + (radius * Math.cos(radians));
        var py = center - (radius * Math.sin(radians));

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px, py, 6);
    }

    function getHeartRateZoneColor(zone as Number) as Number {
        if (zone == 0) {
            return Graphics.COLOR_DK_GRAY;
        } else if (zone == 1) {
            return Graphics.COLOR_BLUE;
        } else if (zone == 2) {
            return Graphics.COLOR_GREEN;
        } else if (zone == 3) {
            return Graphics.COLOR_ORANGE;
        }

        return Graphics.COLOR_RED;
    }

    function getHeartRateValueColor(heartRate as Number) as Number {
        if (heartRate <= 0) {
            return Graphics.COLOR_WHITE;
        } else if (heartRate < _hrZones[1]) {
            return Graphics.COLOR_DK_GRAY;
        } else if (heartRate < _hrZones[2]) {
            return Graphics.COLOR_BLUE;
        } else if (heartRate < _hrZones[3]) {
            return Graphics.COLOR_GREEN;
        } else if (heartRate < _hrZones[4]) {
            return Graphics.COLOR_ORANGE;
        }

        return Graphics.COLOR_RED;
    }

    function getElapsedSeconds() as Number {
        if (_startTime != null) {
            if (_isPaused) {
                return _elapsedBeforePause;
            }

            // Active elapsed time is prior completed segments plus the current
            // segment that began at _startTime.
            return _elapsedBeforePause + Time.now().subtract(_startTime).value();
        }

        return 0;
    }
}
