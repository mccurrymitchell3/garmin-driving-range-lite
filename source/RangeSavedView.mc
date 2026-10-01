import Toybox.Graphics;
import Toybox.Timer;
import Toybox.WatchUi;

class RangeSavedView extends WatchUi.View {
    private const DISPLAY_MS = 1600;

    private var _summary as Dictionary;
    private var _timer as Timer.Timer?;

    function initialize(summary as Dictionary) {
        View.initialize();
        _summary = summary;
        _timer = null;
    }

    function onShow() as Void {
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:showSummary), DISPLAY_MS, false);
        }
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var centerY = height / 2;

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_GREEN);
        dc.clear();

        // Draw a scalable white checkmark rather than relying on a glyph that
        // may render differently across Garmin device fonts.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(8);
        dc.drawLine(
            centerX - (width * 17) / 100,
            centerY - (height * 7) / 100,
            centerX - (width * 4) / 100,
            centerY + (height * 6) / 100
        );
        dc.drawLine(
            centerX - (width * 4) / 100,
            centerY + (height * 6) / 100,
            centerX + (width * 21) / 100,
            centerY - (height * 18) / 100
        );
        dc.setPenWidth(1);

        dc.drawText(
            centerX,
            centerY + (height * 17) / 100,
            Graphics.FONT_MEDIUM,
            "SAVED",
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    function showSummary() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }

        var summaryView = new $.RangeSummaryView(_summary);
        WatchUi.switchToView(
            summaryView,
            new $.RangeSummaryDelegate(summaryView),
            WatchUi.SLIDE_IMMEDIATE
        );
    }
}

class RangeSavedDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    // The confirmation is intentionally non-interactive and advances
    // automatically so accidental input cannot interrupt the save feedback.
    function onBack() as Boolean {
        return true;
    }

    function onSelect() as Boolean {
        return true;
    }

    function onMenu() as Boolean {
        return true;
    }

    function onNextPage() as Boolean {
        return true;
    }

    function onPreviousPage() as Boolean {
        return true;
    }
}
