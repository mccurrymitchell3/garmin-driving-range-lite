import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class RangeSummaryView extends WatchUi.View {
    private var _summary as Dictionary;
    private var _golferIcon as BitmapResource;

    function initialize(summary as Dictionary) {
        View.initialize();
        _summary = summary;
        _golferIcon = WatchUi.loadResource($.Rez.Drawables.GolferIcon) as BitmapResource;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        dc.drawBitmap(
            centerX - (_golferIcon.getWidth() / 2),
            ((height * 12) / 100) - (_golferIcon.getHeight() / 2),
            _golferIcon
        );

        var titleFont = Graphics.FONT_MEDIUM;
        if (dc.getTextWidthInPixels("Driving Range", titleFont) > (width * 72) / 100) {
            titleFont = Graphics.FONT_SMALL;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 20) / 100, titleFont, "Driving Range", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine((width * 10) / 100, (height * 34) / 100, (width * 90) / 100, (height * 34) / 100);
        dc.setPenWidth(1);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            (height * 46) / 100,
            Graphics.FONT_NUMBER_MEDIUM,
            (_summary[:swingCount] as Number).toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(centerX, (height * 55) / 100, Graphics.FONT_SMALL, "Swings", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine((width * 10) / 100, (height * 69) / 100, (width * 90) / 100, (height * 69) / 100);
        dc.drawLine(centerX, (height * 69) / 100, centerX, (height * 97) / 100);
        dc.setPenWidth(1);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText((width * 31) / 100, (height * 71) / 100, Graphics.FONT_XTINY, "Time", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText((width * 69) / 100, (height * 71) / 100, Graphics.FONT_XTINY, "Calories", Graphics.TEXT_JUSTIFY_CENTER);

        var duration = formatDuration(_summary[:elapsedSeconds] as Number);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (dc.getTextWidthInPixels(duration, Graphics.FONT_SMALL) > (width * 31) / 100) {
            dc.drawText((width * 31) / 100, (height * 80) / 100, Graphics.FONT_XTINY, duration, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText((width * 31) / 100, (height * 78) / 100, Graphics.FONT_SMALL, duration, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.drawText((width * 69) / 100, (height * 78) / 100, Graphics.FONT_SMALL, (_summary[:calories] as Number).toString(), Graphics.TEXT_JUSTIFY_CENTER);
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

}

class RangeSummaryDelegate extends WatchUi.BehaviorDelegate {
    function initialize(view as RangeSummaryView) {
        BehaviorDelegate.initialize();
    }

    function onNextPage() as Boolean {
        return true;
    }

    function onPreviousPage() as Boolean {
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

        // Page keys are consumed because the recap now fits on one screen.
        if (key == WatchUi.KEY_UP) {
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            return true;
        }

        System.exit();
    }

    function onTap(clickEvent as ClickEvent) as Boolean {
        return true;
    }

}
