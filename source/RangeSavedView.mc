import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

class RangeSavedView extends WatchUi.View {
    private const DISPLAY_MS = 1600;
    private const ANIMATION_INTERVAL_MS = 80;
    private const SPIN_STEP_DEGREES = 18;
    private const SPIN_ARC_DEGREES = 110;

    private var _summary as Dictionary;
    private var _summaryTimer as Timer.Timer?;
    private var _animationTimer as Timer.Timer?;
    private var _ringAngle as Number;

    function initialize(summary as Dictionary) {
        View.initialize();
        _summary = summary;
        _summaryTimer = null;
        _animationTimer = null;
        _ringAngle = 0;
    }

    function onShow() as Void {
        if (_summaryTimer == null) {
            _summaryTimer = new Timer.Timer();
            _summaryTimer.start(method(:showSummary), DISPLAY_MS, false);
        }

        if (_animationTimer == null) {
            _animationTimer = new Timer.Timer();
            _animationTimer.start(method(:advanceRing), ANIMATION_INTERVAL_MS, true);
        }
    }

    function onHide() as Void {
        if (_summaryTimer != null) {
            _summaryTimer.stop();
            _summaryTimer = null;
        }

        if (_animationTimer != null) {
            _animationTimer.stop();
            _animationTimer = null;
        }
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var centerY = height / 2;
        var diameter = (width < height) ? width : height;
        var ringWidth = (diameter * 3) / 100;
        if (ringWidth < 4) {
            ringWidth = 4;
        }
        var ringRadius = (diameter / 2) - ringWidth;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // A dim track keeps the full perimeter visible while the brighter arc
        // rotates to provide Garmin-style save progress feedback.
        dc.setPenWidth(ringWidth);
        dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(centerX, centerY, ringRadius);
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        drawSpinnerArc(dc, centerX, centerY, ringRadius);
        dc.setPenWidth(1);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            centerY,
            Graphics.FONT_MEDIUM,
            "SAVED",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function drawSpinnerArc(dc as Dc, centerX as Number, centerY as Number, radius as Number) as Void {
        var endAngle = _ringAngle + SPIN_ARC_DEGREES;

        if (endAngle <= 360) {
            dc.drawArc(
                centerX,
                centerY,
                radius,
                Graphics.ARC_CLOCKWISE,
                _ringAngle,
                endAngle
            );
        } else {
            dc.drawArc(
                centerX,
                centerY,
                radius,
                Graphics.ARC_CLOCKWISE,
                _ringAngle,
                360
            );
            dc.drawArc(
                centerX,
                centerY,
                radius,
                Graphics.ARC_CLOCKWISE,
                0,
                endAngle - 360
            );
        }
    }

    function advanceRing() as Void {
        _ringAngle = (_ringAngle + SPIN_STEP_DEGREES) % 360;
        WatchUi.requestUpdate();
    }

    function showSummary() as Void {
        if (_summaryTimer != null) {
            _summaryTimer.stop();
            _summaryTimer = null;
        }

        if (_animationTimer != null) {
            _animationTimer.stop();
            _animationTimer = null;
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
