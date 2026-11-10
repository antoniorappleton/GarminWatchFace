import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

class TaticoClaroView extends WatchUi.WatchFace {

    private var _sleeping as Boolean = false;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var cx = w / 2;
        var cy = dc.getHeight() / 2;
        var s = w / 176.0;
        var t = System.getClockTime();
        var digital = getSetting("DisplayMode", 0) == 1;
        var dark = getSetting("Theme", 0) == 1;
        var fg = dark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var bg = dark ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;

        dc.setColor(bg, bg);
        dc.clear();

        if (_sleeping && System.getDeviceSettings().requiresBurnInProtection) {
            if (digital) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, cy, Graphics.FONT_LARGE, formatTime(t),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            } else {
                drawHands(dc, cx, cy, s, t, Graphics.COLOR_DK_GRAY, bg, false);
            }
            return;
        }

        if (digital) {
            drawDigital(dc, cx, cy, s, t, fg, bg);
        } else {
            drawAnalog(dc, cx, cy, s, t, fg, bg);
        }
    }

    function onEnterSleep() as Void {
        _sleeping = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _sleeping = false;
        WatchUi.requestUpdate();
    }

    private function drawAnalog(dc as Dc, cx as Lang.Numeric, cy as Lang.Numeric,
        s as Lang.Numeric, t as System.ClockTime, fg as Graphics.ColorValue,
        bg as Graphics.ColorValue) as Void {
        var weatherX = cx + 44 * s;
        var weatherY = cy - 45 * s;
        var weatherR = 19 * s;

        drawAnalogTicks(dc, cx, cy, s, fg, weatherX, weatherY, weatherR);

        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 65 * s, Graphics.FONT_SMALL, "12",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx + 65 * s, cy, Graphics.FONT_SMALL, "3",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx - 65 * s, cy, Graphics.FONT_SMALL, "9",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawHands(dc, cx, cy, s, t, fg, bg, true);
        drawWeatherBadge(dc, weatherX, weatherY, weatherR, s, fg, bg);
        drawDateBadge(dc, cx, cy + 24 * s, s, fg, bg);
        drawAnalogBottomFields(dc, cx, cy + 54 * s, s, fg);
    }

    private function drawAnalogTicks(dc as Dc, cx as Lang.Numeric, cy as Lang.Numeric,
        s as Lang.Numeric, fg as Graphics.ColorValue, weatherX as Lang.Numeric,
        weatherY as Lang.Numeric, weatherR as Lang.Numeric) as Void {
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        var rOut = 85 * s;
        var exclude = weatherR + 2 * s;
        for (var i = 0; i < 60; i++) {
            var rIn = 80 * s;
            var pen = 1;
            if (i % 15 == 0) {
                rIn = 68 * s;
                pen = 5;
            } else if (i % 5 == 0) {
                rIn = 70 * s;
                pen = 3;
            }
            var p1 = polar(cx, cy, i * 6, rIn);
            var p2 = polar(cx, cy, i * 6, rOut);
            if (insideRectangle(p1, weatherX - exclude, weatherY - exclude,
                    2 * exclude, 2 * exclude) ||
                insideRectangle(p2, weatherX - exclude, weatherY - exclude,
                    2 * exclude, 2 * exclude)) {
                continue;
            }
            dc.setPenWidth(pw(pen, s));
            dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        }
    }

    private function drawDigital(dc as Dc, cx as Lang.Numeric, cy as Lang.Numeric,
        s as Lang.Numeric, t as System.ClockTime, fg as Graphics.ColorValue,
        bg as Graphics.ColorValue) as Void {
        drawDigitalIndices(dc, cx, cy, s, fg);

        var date = getMetricValue("date");
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 54 * s, cy - 66 * s, Graphics.FONT_XTINY, date,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        drawBatteryBar(dc, cx - 54 * s, cy - 48 * s, s, fg);
        drawDigitalTopField(dc, cx + 51 * s, cy - 48 * s, s, fg, bg,
            getMetricSetting("DigitalTop", "solar"));

        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pw(1, s));
        dc.drawLine(13 * s, cy - 27 * s, 163 * s, cy - 27 * s);
        dc.drawText(cx, cy - 1 * s, Graphics.FONT_NUMBER_HOT, formatTime(t),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawLine(13 * s, cy + 24 * s, 163 * s, cy + 24 * s);

        drawMetricCell(dc, cx - 50 * s, cy + 37 * s, s,
            getMetricSetting("DigitalBottomLeft", "heart_rate"), fg);
        drawMetricCell(dc, cx, cy + 37 * s, s,
            getMetricSetting("DigitalBottomCenter", "body_battery"), fg);
        drawMetricCell(dc, cx + 50 * s, cy + 37 * s, s,
            getMetricSetting("DigitalBottomRight", "altitude"), fg);

        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(13 * s, cy + 61 * s, 163 * s, cy + 61 * s);
        dc.drawText(cx, cy + 72 * s, Graphics.FONT_XTINY, "Appleton",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawDigitalIndices(dc as Dc, cx as Lang.Numeric, cy as Lang.Numeric,
        s as Lang.Numeric, fg as Graphics.ColorValue) as Void {
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pw(2, s));
        dc.drawLine(cx, 2 * s, cx, 8 * s);
        dc.drawLine(cx, 168 * s, cx, 174 * s);
        dc.drawLine(2 * s, cy, 8 * s, cy);
        dc.drawLine(168 * s, cy, 174 * s, cy);
    }

    private function drawBatteryBar(dc as Dc, x as Lang.Numeric, y as Lang.Numeric,
        s as Lang.Numeric, fg as Graphics.ColorValue) as Void {
        var pct = System.getSystemStats().battery;
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, "BAT " + pct.format("%d") + "%",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var barY = y + 7 * s;
        var barW = 48 * s;
        var barH = 5 * s;
        dc.setPenWidth(pw(1, s));
        dc.drawRectangle(x, barY, barW, barH);
        var fillW = (barW - 2 * s) * pct / 100;
        if (fillW > 0) {
            dc.fillRectangle(x + s, barY + s, fillW, barH - 2 * s);
        }
    }

    private function drawDigitalTopField(dc as Dc, x as Lang.Numeric, y as Lang.Numeric,
        s as Lang.Numeric, fg as Graphics.ColorValue, bg as Graphics.ColorValue,
        metric as String) as Void {
        var r = 21 * s;
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y - 4 * s, Graphics.FONT_XTINY, getMetricLabel(metric),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x, y + 5 * s, Graphics.FONT_TINY, getMetricValue(metric),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawWeatherBadge(dc as Dc, x as Lang.Numeric, y as Lang.Numeric,
        r as Lang.Numeric, s as Lang.Numeric, fg as Graphics.ColorValue,
        bg as Graphics.ColorValue) as Void {
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y - 5 * s, Graphics.FONT_TINY, getMetricValue("temperature"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x, y + 6 * s, Graphics.FONT_XTINY, getMetricValue("precipitation"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawDateBadge(dc as Dc, cx as Lang.Numeric, y as Lang.Numeric,
        s as Lang.Numeric, fg as Graphics.ColorValue, bg as Graphics.ColorValue) as Void {
        var w = 72 * s;
        var h = 15 * s;
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - w / 2, y - h / 2, w, h);
        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL, getMetricValue("date"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawAnalogBottomFields(dc as Dc, cx as Lang.Numeric, y as Lang.Numeric,
        s as Lang.Numeric, fg as Graphics.ColorValue) as Void {
        drawMetricCell(dc, cx - 48 * s, y, s,
            getMetricSetting("AnalogBottomLeft", "battery"), fg);
        drawMetricCell(dc, cx, y, s,
            getMetricSetting("AnalogBottomCenter", "solar"), fg);
        drawMetricCell(dc, cx + 48 * s, y, s,
            getMetricSetting("AnalogBottomRight", "altitude"), fg);
    }

    private function drawMetricCell(dc as Dc, x as Lang.Numeric, y as Lang.Numeric,
        s as Lang.Numeric, metric as String, fg as Graphics.ColorValue) as Void {
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, getMetricLabel(metric),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x, y + 10 * s, Graphics.FONT_TINY, getMetricValue(metric),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawHands(dc as Dc, cx as Lang.Numeric, cy as Lang.Numeric,
        s as Lang.Numeric, t as System.ClockTime, fg as Graphics.ColorValue,
        bg as Graphics.ColorValue, outlined as Boolean) as Void {
        var hourAngle = (t.hour % 12 + t.min / 60.0) * 30;
        var minAngle = t.min * 6;
        var hourPen = outlined ? 4.5 : 2;
        var minPen = outlined ? 2.5 : 1;

        drawHand(dc, cx, cy, hourAngle, -6 * s, 36 * s, pw(hourPen, s), fg, bg, outlined);
        drawHand(dc, cx, cy, minAngle, -8 * s, 60 * s, pw(minPen, s), fg, bg, outlined);

        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 4 * s);
        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 1.5 * s);
    }

    private function drawHand(dc as Dc, cx as Lang.Numeric, cy as Lang.Numeric,
        angle as Lang.Numeric, rFrom as Lang.Numeric, rTo as Lang.Numeric,
        pen as Lang.Numeric, fg as Graphics.ColorValue, bg as Graphics.ColorValue,
        outlined as Boolean) as Void {
        var p1 = polar(cx, cy, angle, rFrom);
        var p2 = polar(cx, cy, angle, rTo);
        if (outlined) {
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(pen + 3);
            dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        }
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pen);
        dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
    }

    private function getMetricLabel(metric as String) as String {
        switch (metric) {
            case "date": return "DATA";
            case "battery": return "BAT";
            case "heart_rate": return "BPM";
            case "body_battery": return "BB";
            case "altitude": return "ALT";
            case "steps": return "PASSOS";
            case "temperature": return "TEMP";
            case "precipitation": return "CHUVA";
            case "solar": return "SOL";
        }
        return "";
    }

    private function getMetricValue(metric as String) as String {
        if (metric == "date") {
            return formatDate();
        }
        if (metric == "battery") {
            return System.getSystemStats().battery.format("%d") + "%";
        }
        if (metric == "solar") {
            var pct = System.getSystemStats().solarIntensity;
            return pct == null ? "--" : pct.format("%d") + "%";
        }
        if (metric == "temperature") {
            var weather = getCurrentWeather();
            if (weather != null && weather.temperature != null) {
                return weather.temperature.format("%d") + "°";
            }
            return "--";
        }
        if (metric == "precipitation") {
            var weather = getCurrentWeather();
            if (weather != null && weather.precipitationChance != null) {
                return weather.precipitationChance.format("%d") + "%";
            }
            return "--";
        }
        if (metric == "heart_rate") {
            var heartRate = getHeartRate();
            return heartRate == null ? "--" : heartRate.toString();
        }
        if (metric == "steps") {
            var steps = ActivityMonitor.getInfo().steps;
            return steps == null ? "--" : steps.toString();
        }
        if (metric == "body_battery") {
            var value = latestSensorSample((Toybox has :SensorHistory &&
                SensorHistory has :getBodyBatteryHistory) ?
                SensorHistory.getBodyBatteryHistory({:period => 1}) : null);
            return value == null ? "--" : value.format("%d") + "%";
        }
        if (metric == "altitude") {
            var value = latestSensorSample((Toybox has :SensorHistory &&
                SensorHistory has :getElevationHistory) ?
                SensorHistory.getElevationHistory({:period => 1}) : null);
            return value == null ? "--" : value.format("%d") + "m";
        }
        return "--";
    }

    private function latestSensorSample(
        iterator as SensorHistory.SensorHistoryIterator?) as Numeric? {
        if (iterator == null) {
            return null;
        }
        var sample = iterator.next();
        return sample == null ? null : sample.data;
    }

    private function getCurrentWeather() as Weather.CurrentConditions? {
        if (Toybox has :Weather && Toybox.Weather has :getCurrentConditions) {
            return Weather.getCurrentConditions();
        }
        return null;
    }

    private function getHeartRate() as Number? {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate;
        }
        if (ActivityMonitor has :getHeartRateHistory) {
            var sample = ActivityMonitor.getHeartRateHistory(1, true).next();
            if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                return sample.heartRate;
            }
        }
        return null;
    }

    private function formatDate() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var months = ["JAN", "FEV", "MAR", "ABR", "MAI", "JUN",
            "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"];
        var month = info.month.toNumber();
        if (month == null || month < 1 || month > 12) {
            return info.day.format("%d");
        }
        return info.day.format("%d") + " " + months[month - 1];
    }

    private function formatTime(t as System.ClockTime) as String {
        var hour = t.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
            return hour.format("%d") + ":" + t.min.format("%02d");
        }
        return hour.format("%02d") + ":" + t.min.format("%02d");
    }

    private function getSetting(key as String, fallback as Number) as Number {
        var value = Properties.getValue(key);
        return value instanceof Number ? value : fallback;
    }

    private function getMetricSetting(key as String, fallback as String) as String {
        var value = getSetting(key, -1);
        switch (value) {
            case 0: return "date";
            case 1: return "battery";
            case 2: return "heart_rate";
            case 3: return "body_battery";
            case 4: return "altitude";
            case 5: return "steps";
            case 6: return "temperature";
            case 7: return "precipitation";
            case 8: return "solar";
        }
        return fallback;
    }

    private function insideRectangle(point as Array<Lang.Numeric>, x as Lang.Numeric,
        y as Lang.Numeric, width as Lang.Numeric, height as Lang.Numeric) as Boolean {
        return point[0] >= x && point[0] <= x + width &&
            point[1] >= y && point[1] <= y + height;
    }

    private function polar(cx as Lang.Numeric, cy as Lang.Numeric,
        angle as Lang.Numeric, r as Lang.Numeric) as Array<Lang.Numeric> {
        var a = Math.toRadians(angle);
        return [cx + r * Math.sin(a), cy - r * Math.cos(a)];
    }

    private function pw(base as Lang.Numeric, s as Lang.Numeric) as Number {
        var v = (base * s + 0.5).toNumber();
        return v < 1 ? 1 : v;
    }
}
