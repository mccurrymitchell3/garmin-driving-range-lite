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
    private const BACKSWING_THRESHOLD = 2500.0;
    private const FORWARD_SWING_THRESHOLD = 5000.0;
    private const SWING_CONFIRM_WINDOW_MS = 1500;
    private const SWING_LOCKOUT_MS = 2000;
    private const SENSOR_WARMUP_MS = 3000;
    private const FIT_FIELD_SWING_COUNT_RECORD = 0;
    private const FIT_FIELD_SWING_COUNT_SESSION = 1;

    private var _session as Session?;
    private var _swingCountRecordField as Field?;
    private var _swingCountSessionField as Field?;
    private var _diagnostics;
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
    private var _lastSwingSampleTimestamp as Number?;
    private var _swingCandidateTimestamp as Number?;
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
        _diagnostics = createRangeDiagnostics();
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
        _lastSwingSampleTimestamp = null;
        _swingCandidateTimestamp = null;
        _autoDetectReadyAt = 0;
        _elapsedBeforePause = 0;
        _isPaused = false;
        _isFinished = false;
        _optionsOpen = false;
        _hrZones = [100, 120, 140, 160, 180, 200];
        loadHeartRateZones();
    }

    function onLayout(dc as Dc) as Void {}

    function onShow() as Void {
        if (!_isFinished) {
            if (_session == null) {
                startActivity();
            } else if (!_isPaused) {
                startTimer();
            }
        }
    }

    function onHide() as Void { stopTimer(); }

    function startActivity() as Void {
        _startTime = Time.now();
        _elapsedBeforePause = 0;
        _isPaused = false;
        _isFinished = false;
        armAutoDetection();

        if ((Toybox has :ActivityRecording) && (_session == null)) {
            var sessionOptions = {
                :name => "Range",
                :sport => Activity.SPORT_GOLF,
                :subSport => Activity.SUB_SPORT_GENERIC
            };
            _diagnostics.configureSessionOptions(sessionOptions);
            _session = ActivityRecording.createSession(sessionOptions);
            _session.start();
            createFitFields();
        }

        writeFitFields();
        startSensorDataListener();
        startTimer();
    }

    function startTimer() as Void {
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTimer), 500, true);
        }
    }

    function stopActivity() as Void {
        if (!_isFinished) { saveActivity(); }
    }

    function pauseActivity() as Void {
        if (_isFinished || _isPaused) { return; }
        _elapsedBeforePause = getElapsedSeconds();
        _isPaused = true;
        stopSensorDataListener();
        stopTimer();
        if ((_session != null) && _session.isRecording()) { _session.stop(); }
        WatchUi.requestUpdate();
    }

    function resumeActivity() as Void {
        if (_isFinished || !_isPaused) { return; }
        _startTime = Time.now();
        _isPaused = false;
        armAutoDetection();
        if ((_session != null) && !_session.isRecording()) { _session.start(); }
        writeFitFields();
        startSensorDataListener();
        startTimer();
        WatchUi.requestUpdate();
    }

    function saveActivity() as Void {
        if (_isFinished) { return; }
        stopSensorDataListener();
        stopTimer();
        var session = _session;
        if (session != null) {
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
        if (_isFinished) { return; }
        stopSensorDataListener();
        stopTimer();
        if (_session != null) {
            if (_session.isRecording()) { _session.stop(); }
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
        if (_isPaused || _isFinished) { return; }
        _swingCount++;
        writeFitFields();
        WatchUi.requestUpdate();
    }

    function subtractSwing() as Void {
        if (_isPaused || _isFinished) { return; }
        if (_swingCount > 0) {
            _swingCount--;
            writeFitFields();
            WatchUi.requestUpdate();
        }
    }

    function isOptionsOpen() as Boolean { return _optionsOpen; }
    function setOptionsOpen(open as Boolean) as Void { _optionsOpen = open; }

    function armAutoDetection() as Void {
        var now = System.getTimer();
        _lastSwingTime = now;
        _lastSwingSampleTimestamp = null;
        _swingCandidateTimestamp = null;
        _autoDetectReadyAt = now + SENSOR_WARMUP_MS;
    }

    function onTimer() as Void {
        readActivitySensors();
        writeFitFields();
        WatchUi.requestUpdate();
    }

    function startSensorDataListener() as Void {
        var sampleRate = Sensor.getMaxSampleRateForSensorType(:accelerometer);
        if (sampleRate > 100) { sampleRate = 100; }
        if (sampleRate <= 0) { return; }
        Sensor.registerSensorDataListener(method(:onSensorData), {
            :period => 1,
            :accelerometer => {
                :enabled => true,
                :sampleRate => sampleRate,
                :includeTimestamps => true
            }
        });
    }

    function stopSensorDataListener() as Void { Sensor.unregisterSensorDataListener(); }

    function onSensorData(sensorData as Sensor.SensorData) as Void {
        if (_isPaused || _isFinished || (sensorData.accelerometerData == null)) { return; }
        var accel = sensorData.accelerometerData;
        var xSamples = accel.x;
        var ySamples = accel.y;
        var zSamples = accel.z;
        var timestamps = accel.timestamp;
        if ((xSamples == null) || (ySamples == null) || (zSamples == null)) { return; }

        var count = xSamples.size();
        if (ySamples.size() < count) { count = ySamples.size(); }
        if (zSamples.size() < count) { count = zSamples.size(); }
        if ((timestamps != null) && (timestamps.size() < count)) { count = timestamps.size(); }

        for (var i = 0; i < count; i++) {
            var sampleTimestamp = (timestamps != null) ? timestamps[i] : System.getTimer();
            var counted = processAccelerationSample(xSamples[i], ySamples[i], zSamples[i], sampleTimestamp);
            _diagnostics.logSample(sampleTimestamp, xSamples[i], ySamples[i], zSamples[i], counted);
        }
    }

    function processAccelerationSample(x as Number, y as Number, z as Number, sampleTimestamp as Number) as Boolean {
        var mag = Math.sqrt((x * x) + (y * y) + (z * z));
        var now = System.getTimer();
        if (now < _autoDetectReadyAt) { return false; }

        var outsideSampleLockout =
            (_lastSwingSampleTimestamp == null) ||
            ((sampleTimestamp - (_lastSwingSampleTimestamp as Number)) > SWING_LOCKOUT_MS);
        if (!outsideSampleLockout) {
            _swingCandidateTimestamp = null;
            return false;
        }

        if ((_swingCandidateTimestamp != null) &&
            ((sampleTimestamp - (_swingCandidateTimestamp as Number)) > SWING_CONFIRM_WINDOW_MS)) {
            _swingCandidateTimestamp = null;
        }

        if ((_swingCandidateTimestamp != null) && (mag >= FORWARD_SWING_THRESHOLD)) {
            _lastSwingTime = now;
            _lastSwingSampleTimestamp = sampleTimestamp;
            _swingCandidateTimestamp = null;
            _swingCount++;
            _diagnostics.recordSwingTimestamp(sampleTimestamp);
            writeFitFields();
            WatchUi.requestUpdate();
            return true;
        }

        if ((_swingCandidateTimestamp == null) &&
            (mag >= BACKSWING_THRESHOLD) && (mag < FORWARD_SWING_THRESHOLD)) {
            _swingCandidateTimestamp = sampleTimestamp;
        }
        return false;
    }

    function loadHeartRateZones() as Void {
        var profileZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        if ((profileZones != null) && (profileZones.size() >= 6)) { _hrZones = profileZones; }
    }

    function readActivitySensors() as Void {
        var info = Sensor.getInfo();
        var activityInfo = Activity.getActivityInfo();
        if ((info has :heartRate) && (info.heartRate != null)) {
            updateHeartRate(info.heartRate as Number);
        } else if ((info has :currentHeartRate) && (info.currentHeartRate != null)) {
            updateHeartRate(info.currentHeartRate as Number);
        } else if ((activityInfo has :currentHeartRate) && (activityInfo.currentHeartRate != null)) {
            updateHeartRate(activityInfo.currentHeartRate as Number);
        }
        if ((activityInfo has :averageHeartRate) && (activityInfo.averageHeartRate != null)) {
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
    }

    function createFitFields() as Void {
        var session = _session;
        if ((session != null) && (session has :createField)) {
            if (_swingCountRecordField == null) {
                _swingCountRecordField = session.createField(
                    "Swing Count", FIT_FIELD_SWING_COUNT_RECORD, FitContributor.DATA_TYPE_UINT16,
                    {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "swings"}
                );
            }
            if (_swingCountSessionField == null) {
                _swingCountSessionField = session.createField(
                    "Swing Count", FIT_FIELD_SWING_COUNT_SESSION, FitContributor.DATA_TYPE_UINT16,
                    {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "swings"}
                );
            }
            _diagnostics.createFitFields(session);
        }
    }

    function writeFitFields() as Void {
        if (_swingCountRecordField != null) { _swingCountRecordField.setData(_swingCount as Object); }
        if (_swingCountSessionField != null) { _swingCountSessionField.setData(_swingCount as Object); }
    }

    function clearFitFields() as Void {
        _swingCountRecordField = null;
        _swingCountSessionField = null;
        _diagnostics.clear();
    }

    function updateHeartRate(heartRate as Number) as Void {
        if (heartRate <= 0) { return; }
        _heartRate = heartRate;
        _heartRateTotal += heartRate;
        _heartRateSamples++;
        if (heartRate > _maxHeartRate) { _maxHeartRate = heartRate; }
    }

    function getSummary() as Dictionary {
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
        if (_heartRateSamples > 0) { return _heartRateTotal / _heartRateSamples; }
        return 0;
    }

    function onUpdate(dc as Dc) as Void {
        var activityInfo = Activity.getActivityInfo();
        if ((activityInfo has :calories) && (activityInfo.calories != null)) {
            _calories = activityInfo.calories as Number;
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var elapsedSec = getElapsedSeconds();
        var timeStr = formatDuration(elapsedSec);
        var hrStr = (_heartRate > 0) ? _heartRate.toString() : "--";

        drawHrGauge(dc, width, height);
        drawActivityGrid(dc, width, height);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 7) / 100, Graphics.FONT_XTINY, "TIMER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (dc.getTextWidthInPixels(timeStr, Graphics.FONT_LARGE) > (width * 80) / 100) {
            dc.drawText(centerX, (height * 15) / 100, Graphics.FONT_SMALL, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(centerX, (height * 15) / 100, Graphics.FONT_LARGE, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        }
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

    function formatDuration(elapsed as Number) as String {
        var hours = elapsed / 3600;
        var minutes = (elapsed % 3600) / 60;
        var seconds = elapsed % 60;
        if (hours > 0) {
            return hours.format("%d") + ":" + minutes.format("%02d") + ":" + seconds.format("%02d");
        }
        return minutes.format("%02d") + ":" + seconds.format("%02d");
    }

    function drawActivityGrid(dc as Dc, width as Number, height as Number) as Void {
        var left = (width * 10) / 100;
        var right = width - left;
        var topDivider = (height * 32) / 100;
        var hrDivider = (height * 62) / 100;
        var centerX = width / 2;
        drawFadedRedLine(dc, left, right, topDivider);
        drawFadedRedLine(dc, left, right, hrDivider);
        drawSolidRedVerticalLine(dc, centerX, topDivider, hrDivider);
    }

    function drawFadedRedLine(dc as Dc, startX as Number, endX as Number, y as Number) as Void {
        var totalWidth = endX - startX;
        var halfWidth = totalWidth / 2.0;
        var centerX = startX + halfWidth;
        var step = 4;
        dc.setPenWidth(2);
        for (var x = startX; x < endX; x += step) {
            var distFromCenter = x - centerX;
            if (distFromCenter < 0) { distFromCenter = -distFromCenter; }
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
        if (factor > 0.4) { return Graphics.COLOR_RED; }
        else if (factor > 0.2) { return Graphics.COLOR_DK_RED; }
        else if (factor > 0.1) { return Graphics.COLOR_DK_GRAY; }
        return Graphics.COLOR_BLACK;
    }

    function drawHrGauge(dc as Dc, width as Number, height as Number) as Void {
        var center = width / 2;
        var radius = center - 8;
        var penWidth = 8;
        var startAngle = 210;
        var totalArc = 120;
        var arcPerZone = totalArc / 5;
        dc.setPenWidth(penWidth);
        for (var i = 0; i < 5; i++) {
            var zStart = startAngle + (i * arcPerZone);
            var zEnd = zStart + arcPerZone - 2;
            dc.setColor(getHeartRateZoneColor(i), Graphics.COLOR_TRANSPARENT);
            dc.drawArc(center, center, radius, Graphics.ARC_COUNTER_CLOCKWISE, zStart, zEnd);
        }
        dc.setPenWidth(1);
        if (_heartRate > 0) { drawHeartRateIndicator(dc, center, radius, startAngle, totalArc); }
    }

    function drawHeartRateIndicator(dc as Dc, center as Number, radius as Number, startAngle as Number, totalArc as Number) as Void {
        var minHr = _hrZones[0];
        var maxHr = _hrZones[5];
        var currentHrClamped = _heartRate;
        if (currentHrClamped < minHr) { currentHrClamped = minHr; }
        if (currentHrClamped > maxHr) { currentHrClamped = maxHr; }
        if (maxHr <= minHr) { return; }
        var pct = (currentHrClamped - minHr).toFloat() / (maxHr - minHr).toFloat();
        var indicatorAngle = startAngle + (pct * totalArc);
        var radians = Math.toRadians(indicatorAngle);
        var px = center + (radius * Math.cos(radians));
        var py = center - (radius * Math.sin(radians));
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px, py, 6);
    }

    function getHeartRateZoneColor(zone as Number) as Number {
        if (zone == 0) { return Graphics.COLOR_DK_GRAY; }
        else if (zone == 1) { return Graphics.COLOR_BLUE; }
        else if (zone == 2) { return Graphics.COLOR_GREEN; }
        else if (zone == 3) { return Graphics.COLOR_ORANGE; }
        return Graphics.COLOR_RED;
    }

    function getHeartRateValueColor(heartRate as Number) as Number {
        if (heartRate <= 0) { return Graphics.COLOR_WHITE; }
        else if (heartRate < _hrZones[1]) { return Graphics.COLOR_DK_GRAY; }
        else if (heartRate < _hrZones[2]) { return Graphics.COLOR_BLUE; }
        else if (heartRate < _hrZones[3]) { return Graphics.COLOR_GREEN; }
        else if (heartRate < _hrZones[4]) { return Graphics.COLOR_ORANGE; }
        return Graphics.COLOR_RED;
    }

    function getElapsedSeconds() as Number {
        if (_startTime != null) {
            if (_isPaused) { return _elapsedBeforePause; }
            return _elapsedBeforePause + Time.now().subtract(_startTime).value();
        }
        return 0;
    }
}
