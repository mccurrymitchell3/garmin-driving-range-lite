import Toybox.FitContributor;
import Toybox.SensorLogging;
import Toybox.System;

// RangeView talks only to this small diagnostics surface. The Jungle files
// select exactly one factory implementation at build time, so detector and UI
// behavior stay identical between production and beta builds.
class RangeDiagnosticsBase {
    function initialize() {}
    function configureSessionOptions(options) as Void {}
    function createFitFields(session) as Void {}
    function recordSwingTimestamp(timestamp as Number) as Void {}
    function logSample(timestamp as Number, x as Number, y as Number, z as Number, counted as Boolean) as Void {}
    function clear() as Void {}
}

(:production)
class RangeProductionDiagnostics extends RangeDiagnosticsBase {
    function initialize() {
        RangeDiagnosticsBase.initialize();
    }
}

(:beta)
class RangeBetaDiagnostics extends RangeDiagnosticsBase {
    private const FIT_FIELD_LAST_SWING_TIMESTAMP = 2;

    private var _sensorLogger;
    private var _lastSwingTimestampField;

    function initialize() {
        RangeDiagnosticsBase.initialize();
        _sensorLogger = null;
        _lastSwingTimestampField = null;
    }

    function configureSessionOptions(options) as Void {
        if (Toybox has :SensorLogging) {
            _sensorLogger = new SensorLogging.SensorLogger({
                :accelerometer => { :enabled => true },
                :synchronous => false
            });
            options[:sensorLogger] = _sensorLogger;
        }
    }

    function createFitFields(session) as Void {
        if ((session != null) && (session has :createField) && (_lastSwingTimestampField == null)) {
            _lastSwingTimestampField = session.createField(
                "Last Swing Sample Timestamp",
                FIT_FIELD_LAST_SWING_TIMESTAMP,
                FitContributor.DATA_TYPE_UINT32,
                { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "ms" }
            );
        }
    }

    function recordSwingTimestamp(timestamp as Number) as Void {
        if (_lastSwingTimestampField != null) {
            _lastSwingTimestampField.setData(timestamp as Object);
        }
    }

    function logSample(timestamp as Number, x as Number, y as Number, z as Number, counted as Boolean) as Void {
        System.println(
            "ACCEL," + timestamp + "," + x + "," + y + "," + z + "," +
            (counted ? "1" : "0")
        );
    }

    function clear() as Void {
        _lastSwingTimestampField = null;
        _sensorLogger = null;
    }
}

(:production)
function createRangeDiagnostics() {
    return new RangeProductionDiagnostics();
}

(:beta)
function createRangeDiagnostics() {
    return new RangeBetaDiagnostics();
}
