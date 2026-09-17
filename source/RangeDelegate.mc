import Toybox.Lang;
import Toybox.WatchUi;

class RangeDelegate extends WatchUi.InputDelegate {
    private var _view as RangeView;

    function initialize(view as RangeView) {
        InputDelegate.initialize();
        _view = view;
    }

    function onTap(clickEvent as ClickEvent) as Boolean {
        // Consume touch input so accidental screen contact does not affect the
        // recording.
        return true;
    }

    function onHold(clickEvent as ClickEvent) as Boolean {
        return true;
    }

    function onRelease(clickEvent as ClickEvent) as Boolean {
        return true;
    }

    function onSwipe(swipeEvent as SwipeEvent) as Boolean {
        return true;
    }

    function onKey(keyEvent as KeyEvent) as Boolean {
        return handleKey(keyEvent);
    }

    function onKeyReleased(keyEvent as KeyEvent) as Boolean {
        return true;
    }

    function handleKey(keyEvent as KeyEvent) as Boolean {
        var key = keyEvent.getKey();

        // Map physical buttons to the small set of in-activity actions. Unknown
        // keys are consumed to keep the active recording screen stable.
        if ((key == WatchUi.KEY_START) || (key == WatchUi.KEY_ENTER) || (key == WatchUi.KEY_MENU)) {
            showOptions();
            return true;
        } else if (key == WatchUi.KEY_UP) {
            _view.addSwing();
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            _view.subtractSwing();
            return true;
        }

        return true;
    }

    function showOptions() as Void {
        if (_view.isOptionsOpen()) {
            return;
        }

        // Opening options pauses recording first, then hands control to the
        // menu delegate for resume/save/discard.
        _view.pauseActivity();
        _view.setOptionsOpen(true);

        var menu = new WatchUi.Menu2({:title => "Paused"});
        menu.addItem(new WatchUi.MenuItem("Resume", null, :resume, null));
        menu.addItem(new WatchUi.MenuItem("Save", null, :save, null));
        menu.addItem(new WatchUi.MenuItem("Discard", null, :discard, null));

        WatchUi.pushView(menu, new $.RangeMenuDelegate(_view), WatchUi.SLIDE_UP);
    }
}
