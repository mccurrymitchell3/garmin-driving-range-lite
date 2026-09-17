import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class RangeSummaryView extends WatchUi.View {
    private const PAGE_COUNT = 5;

    private var _summary as Dictionary;
    private var _page as Number;

    function initialize(summary as Dictionary) {
        View.initialize();
        _summary = summary;
        _page = 0;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, width, height);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 8) / 100, Graphics.FONT_SMALL, "SAVED", Graphics.TEXT_JUSTIFY_CENTER);

        // Use one metric per page to keep the saved recap readable on small
        // round and square Garmin displays.
        if (_page == 0) {
            drawSingleMetric(dc, "SWINGS", (_summary[:swingCount] as Number).toString(), Graphics.COLOR_GREEN);
        } else if (_page == 1) {
            drawSingleMetric(dc, "CALORIES", formatNumber(_summary[:calories] as Number), Graphics.COLOR_ORANGE);
        } else if (_page == 2) {
            drawHeartRate(dc);
        } else if (_page == 3) {
            drawSingleMetric(dc, "TRAINING EFFECT", formatTrainingEffect(_summary[:trainingEffect] as Object?), Graphics.COLOR_BLUE);
        } else {
            drawSingleMetric(dc, "DURATION", formatDuration(_summary[:elapsedSeconds] as Number), Graphics.COLOR_YELLOW);
        }

        drawPageDots(dc);
    }

    function drawSingleMetric(dc as Dc, label as String, value as String, color as Number) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 31) / 100, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 48) / 100, Graphics.FONT_NUMBER_HOT, value, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawHeartRate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 23) / 100, Graphics.FONT_SMALL, "HEART RATE", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width * 0.30, (height * 43) / 100, Graphics.FONT_XTINY, "AVG", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width * 0.70, (height * 43) / 100, Graphics.FONT_XTINY, "MAX", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width * 0.30, (height * 55) / 100, Graphics.FONT_NUMBER_MEDIUM, formatNumber(_summary[:averageHeartRate] as Number), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width * 0.70, (height * 55) / 100, Graphics.FONT_NUMBER_MEDIUM, formatNumber(_summary[:maxHeartRate] as Number), Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawPageDots(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var spacing = 14;
        var startX = (width / 2) - ((PAGE_COUNT - 1) * spacing / 2);
        var y = (height * 87) / 100;

        // Small dots show the current recap page without needing text labels.
        for (var i = 0; i < PAGE_COUNT; i++) {
            var radius = (i == _page) ? 4 : 2;
            var color = (i == _page) ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(startX + (i * spacing), y, radius);
        }
    }

    function nextPage() as Void {
        _page = (_page + 1) % PAGE_COUNT;
        WatchUi.requestUpdate();
    }

    function previousPage() as Void {
        _page = (_page + PAGE_COUNT - 1) % PAGE_COUNT;
        WatchUi.requestUpdate();
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

    function formatNumber(value as Number) as String {
        if (value > 0) {
            return value.toString();
        }

        return "--";
    }

    function formatTrainingEffect(value as Object?) as String {
        if (value != null) {
            // Garmin exposes training effect as a nullable numeric value; keep
            // the display compact for the single-metric page.
            return (value as Numeric).format("%.1f");
        }

        return "--";
    }
}

class RangeSummaryDelegate extends WatchUi.BehaviorDelegate {
    private var _view as RangeSummaryView;

    function initialize(view as RangeSummaryView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.nextPage();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.previousPage();
        return true;
    }

    function onSelect() as Boolean {
        // Once an activity is saved and reviewed, any primary button exits.
        System.exit();
    }

    function onBack() as Boolean {
        System.exit();
    }

    function onMenu() as Boolean {
        System.exit();
    }

    function onKey(keyEvent as KeyEvent) as Boolean {
        var key = keyEvent.getKey();

        // Support button-only devices in addition to behavior page events.
        if (key == WatchUi.KEY_UP) {
            _view.previousPage();
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            _view.nextPage();
            return true;
        }

        System.exit();
    }

    function onTap(clickEvent as ClickEvent) as Boolean {
        return true;
    }

}
