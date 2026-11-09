import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Tático Claro — mostrador híbrido (analógico + complicações).
// Desenhado para o ecrã MIP monocromático de 176 px do Instinct 3 Solar,
// mas todas as medidas escalam com a largura do ecrã.
//
// Convenção de ângulos: 0° = 12 horas, a crescer no sentido dos ponteiros.
// Todas as medidas em "unidades de referência" (ecrã de 176 px) multiplicadas por s.
class TaticoClaroView extends WatchUi.WatchFace {

    private var _sleeping = false;
    private var _sub = null;  // área da subjanela (BoundingBox) ou null se não existir

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        if (WatchUi has :getSubscreen) {
            _sub = WatchUi.getSubscreen();
        }
    }

    // Desenha sempre o ecrã inteiro (evita artefactos na subjanela).
    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var cx = w / 2;
        var cy = dc.getHeight() / 2;
        var s = w / 176.0;
        var t = System.getClockTime();

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        // Modelos AMOLED em modo sempre ligado: só ponteiros finos (proteção burn-in)
        if (_sleeping && System.getDeviceSettings().requiresBurnInProtection) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();
            drawHands(dc, cx, cy, s, t, Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK, false);
            return;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.clear();

        drawTicks(dc, cx, cy, s);
        drawBattery(dc, cx, cy, s);
        drawHeartRate(dc, cx, cy, s);
        drawDate(dc, cx, cy, s);
        drawDigitalTime(dc, cx, cy, s, t);
        drawHands(dc, cx, cy, s, t, Graphics.COLOR_BLACK, Graphics.COLOR_WHITE, true);
    }

    function onEnterSleep() as Void {
        _sleeping = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _sleeping = false;
        WatchUi.requestUpdate();
    }

    // ---------- Elementos do mostrador ----------

    // 60 marcas: horas grossas, minutos finos. Omite as que caem na subjanela.
    private function drawTicks(dc as Dc, cx, cy, s) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        var rOut = 85 * s;
        for (var i = 0; i < 60; i++) {
            var rIn = 80 * s;
            var pen = 1;
            if (i % 15 == 0) {
                rIn = 68 * s;
                pen = 6;
            } else if (i % 5 == 0) {
                rIn = 68 * s;
                pen = 4;
            }
            var p1 = polar(cx, cy, i * 6, rIn);
            var p2 = polar(cx, cy, i * 6, rOut);
            if (insideSub(p1, 6 * s) || insideSub(p2, 6 * s)) {
                continue;
            }
            dc.setPenWidth(pw(pen, s));
            dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        }
    }

    // Arco de bateria na parte inferior (das 7h às 5h, passando pelas 6h).
    private function drawBattery(dc as Dc, cx, cy, s) as Void {
        var pct = System.getSystemStats().battery;  // 0–100
        var r = 58 * s;

        // Trilho: contorno preto com interior branco
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pw(7, s));
        dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, 230, 310);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pw(4, s));
        dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, 230, 310);

        // Preenchimento proporcional (drawArc com início = fim desenharia um círculo inteiro)
        if (pct >= 1) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, 230, 230 + 80 * pct / 100);
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 38 * s, Graphics.FONT_XTINY, pct.format("%d") + "%",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Pulsação à esquerda: ícone de coração + valor.
    private function drawHeartRate(dc as Dc, cx, cy, s) as Void {
        var x = cx - 44 * s;
        var y = cy - 8 * s;
        var hr = getHeartRate();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        var r = 2.6 * s;
        dc.fillCircle(x - r, y - 1.5 * s, r);
        dc.fillCircle(x + r, y - 1.5 * s, r);
        dc.fillPolygon([[x - 2 * r, y - 0.8 * s], [x + 2 * r, y - 0.8 * s], [x, y + 5 * s]]);

        dc.drawText(x, y + 15 * s, Graphics.FONT_TINY, hr == null ? "--" : hr.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Dia do mês numa caixa preta à direita.
    private function drawDate(dc as Dc, cx, cy, s) as Void {
        var day = Gregorian.info(Time.now(), Time.FORMAT_SHORT).day;
        var bw = 22 * s;
        var bh = 16 * s;
        var x = cx + 26 * s;
        var y = cy - bh / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, bw, bh, 2 * s);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + bw / 2, cy, Graphics.FONT_XTINY, day.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Hora digital: na subjanela, se existir; caso contrário, acima do centro.
    private function drawDigitalTime(dc as Dc, cx, cy, s, t) as Void {
        var txt = formatTime(t);
        if (_sub != null) {
            var sx = _sub.x + _sub.width / 2;
            var sy = _sub.y + _sub.height / 2;
            var r = (_sub.width < _sub.height ? _sub.width : _sub.height) / 2;
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy, r);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(sx, sy, Graphics.FONT_SMALL, txt,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 36 * s, Graphics.FONT_TINY, txt,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Ponteiros com contorno na cor do fundo, para se destacarem sobre marcas e complicações.
    private function drawHands(dc as Dc, cx, cy, s, t, fg, bg, outlined) as Void {
        var hourAngle = (t.hour % 12 + t.min / 60.0) * 30;
        var minAngle = t.min * 6;
        var hourPen = outlined ? 4.5 : 2;
        var minPen = outlined ? 2.5 : 1;

        drawHand(dc, cx, cy, hourAngle, -6 * s, 44 * s, pw(hourPen, s), fg, bg, outlined);
        drawHand(dc, cx, cy, minAngle, -8 * s, 70 * s, pw(minPen, s), fg, bg, outlined);

        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 4 * s);
        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 1.5 * s);
    }

    private function drawHand(dc as Dc, cx, cy, angle, rFrom, rTo, pen, fg, bg, outlined) as Void {
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

    // ---------- Dados ----------

    // Pulsação atual; se indisponível, a última amostra do histórico. null se não houver.
    private function getHeartRate() {
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

    // Respeita a definição de 12/24 horas do relógio.
    private function formatTime(t) as String {
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

    // ---------- Utilitários ----------

    // Ponto a uma distância r do centro, no ângulo indicado (0° = 12h, sentido horário).
    private function polar(cx, cy, angle, r) {
        var a = Math.toRadians(angle);
        return [cx + r * Math.sin(a), cy - r * Math.cos(a)];
    }

    // O ponto está dentro da área da subjanela (com margem)?
    private function insideSub(p, margin) as Boolean {
        if (_sub == null) {
            return false;
        }
        return p[0] >= _sub.x - margin && p[0] <= _sub.x + _sub.width + margin
            && p[1] >= _sub.y - margin && p[1] <= _sub.y + _sub.height + margin;
    }

    // Espessura de traço escalada, nunca inferior a 1 px.
    private function pw(base, s) as Number {
        var v = (base * s + 0.5).toNumber();
        return v < 1 ? 1 : v;
    }
}
