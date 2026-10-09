import Toybox.Lang;
import Toybox.WatchUi;

class RangeMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _view as RangeView;

    function initialize(view as RangeView) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();

        // Each menu branch clears the menu-open flag before leaving the menu so
        // the activity delegate can open it again later if needed.
        if (id == :resume) {
            _view.resumeActivity();
            _view.setOptionsOpen(false);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :save) {
            _view.setOptionsOpen(false);
            _view.saveActivity();

            // Confirm the completed save before showing the activity recap.
            // RangeSavedView advances automatically to the existing summary.
            var savedView = new $.RangeSavedView(_view.getSummary());
            WatchUi.switchToView(savedView, new $.RangeSavedDelegate(), WatchUi.SLIDE_IMMEDIATE);
        } else if (id == :discard) {
            _view.setOptionsOpen(false);
            _view.discardActivity();
        }
    }

    function onBack() as Void {
        // Dismiss the menu but leave the activity paused. The user can reopen
        // the menu and explicitly choose Resume, Save, or Discard.
        _view.setOptionsOpen(false);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
