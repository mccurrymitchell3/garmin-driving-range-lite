import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class RangeApp extends Application.AppBase {
    private var _view as RangeView?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
        // Save any active recording when Garmin stops the app lifecycle.
        if (_view != null) {
            _view.stopActivity();
        }
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        // Keep the activity view around so onStop can close the FIT session.
        _view = new $.RangeView();
        return [_view, new $.RangeDelegate(_view)];
    }
}
