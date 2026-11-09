import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Tático Navy — variante militar do Tático Claro.
// - Numeração das horas que muda com o período do dia:
//   manhã (AM): 12, 1, 2 … 11   |   tarde (PM): 12, 13, 14 … 23
// - Ponteiros tipo espada, pretos, com faixa interior branca ("lume").
//
// Convenção de ângulos: 0° = 12 horas, a crescer no sentido dos ponteiros.
// Medidas em unidades do ecrã de referência (176 px), multiplicadas por s.
class TaticoNavyView extends WatchUi.WatchFace {

    private var _sleeping = false;
    private var _sub = null;  // área da subjanela (BoundingBox) ou null

    // Formas dos ponteiros: pares [distância ao centro, desvio lateral].
    // Valores negativos de distância = cauda do ponteiro.
    private var _hourShape = [[-9, -3], [-9, 3], [8, 5], [30, 5], [42, 0], [30, -5], [8, -5]];
    private var _hourLume  = [[11, -2.2], [11, 2.2], [29, 2.2], [36, 0], [29, -2.2]];
    private var _minShape  = [[-11, -2.5], [-11, 2.5], [10, 3.8], [62, 3.8], [75, 0], [62, -3.8], [10, -3.8]];
    private var _minLume   = [[13, -1.6], [13, 1.6], [61, 1.6], [69, 0], [61, -1.6]];

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
            drawThinHands(dc, cx, cy, s, t);
            return;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.clear();

        drawTicks(dc, cx, cy, s);
        drawNumerals(dc, cx, cy, s, t.hour >= 12);
        drawBattery(dc, cx, cy, s);
        drawHeartRate(dc, cx, cy, s);
        drawDate(dc, cx, cy, s);
        drawHands(dc, cx, cy, s, t);
        drawDigitalTime(dc, cx, cy, s, t);  // por último: a subjanela tapa os ponteiros
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

    // Anel exterior: minutos finos, horas médias. Omite o que cai na subjanela.
    private function drawTicks(dc as Dc, cx, cy, s) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        var rOut = 86 * s;
        for (var i = 0; i < 60; i++) {
            var hourTick = (i % 5 == 0);
            var p1 = pt(cx, cy, i * 6, hourTick ? 77 * s : 82 * s, 0);
            var p2 = pt(cx, cy, i * 6, rOut, 0);
            if (insideSub(p1, 6 * s) || insideSub(p2, 6 * s)) {
                continue;
            }
            dc.setPenWidth(pw(hourTick ? 3 : 1, s));
            dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        }
    }

    // Numeração das horas: AM 12, 1–11; PM 12, 13–23.
    private function drawNumerals(dc as Dc, cx, cy, s, pm) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i <= 12; i++) {
            var p = pt(cx, cy, i * 30, 65 * s, 0);
            if (insideSub(p, 10 * s)) {
                continue;
            }
            var label = i;
            if (pm && i != 12) {
                label = i + 12;
            }
            dc.drawText(p[0], p[1], Graphics.FONT_TINY, label.toString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Arco de bateria na parte inferior, mais curto para não colidir com o 5 e o 7.
    private function drawBattery(dc as Dc, cx, cy, s) as Void {
        var pct = System.getSystemStats().battery;  // 0–100
        var r = 48 * s;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pw(7, s));
        dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, 225, 315);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pw(4, s));
        dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, 225, 315);

        // drawArc com início = fim desenharia um círculo inteiro
        if (pct >= 1) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, 225, 225 + 90 * pct / 100);
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 30 * s, Graphics.FONT_XTINY, pct.format("%d") + "%",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Pulsação à esquerda, mais perto do centro para dar espaço ao 9/21.
    private function drawHeartRate(dc as Dc, cx, cy, s) as Void {
        var x = cx - 36 * s;
        var y = cy - 8 * s;
        var hr = getHeartRate();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        var r = 2.4 * s;
        dc.fillCircle(x - r, y - 1.5 * s, r);
        dc.fillCircle(x + r, y - 1.5 * s, r);
        dc.fillPolygon([[x - 2 * r, y - 0.8 * s], [x + 2 * r, y - 0.8 * s], [x, y + 4.5 * s]]);

        dc.drawText(x, y + 14 * s, Graphics.FONT_XTINY, hr == null ? "--" : hr.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Dia do mês numa caixa preta à direita.
    private function drawDate(dc as Dc, cx, cy, s) as Void {
        var day = Gregorian.info(Time.now(), Time.FORMAT_SHORT).day;
        var bw = 22 * s;
        var bh = 16 * s;
        var x = cx + 24 * s;
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

    // Ponteiros espada: contorno branco (separa do fundo), corpo preto, faixa branca.
    private function drawHands(dc as Dc, cx, cy, s, t) as Void {
        var hourAngle = (t.hour % 12 + t.min / 60.0) * 30;
        var minAngle = t.min * 6;

        drawSword(dc, cx, cy, hourAngle, _hourShape, _hourLume, s);
        drawSword(dc, cx, cy, minAngle, _minShape, _minLume, s);

        // Eixo central
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 6.5 * s);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 5 * s);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 1.5 * s);
    }

    private function drawSword(dc as Dc, cx, cy, angle, shape, lume, s) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(handPoints(cx, cy, angle, shape, s, 1.5));
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(handPoints(cx, cy, angle, shape, s, 0));
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(handPoints(cx, cy, angle, lume, s, 0));
    }

    // AMOLED em repouso: linhas finas cinzentas, sem áreas preenchidas.
    private function drawThinHands(dc as Dc, cx, cy, s, t) as Void {
        var hourAngle = (t.hour % 12 + t.min / 60.0) * 30;
        var minAngle = t.min * 6;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pw(2, s));
        var h = pt(cx, cy, hourAngle, 40 * s, 0);
        dc.drawLine(cx, cy, h[0], h[1]);
        dc.setPenWidth(pw(1, s));
        var m = pt(cx, cy, minAngle, 70 * s, 0);
        dc.drawLine(cx, cy, m[0], m[1]);
    }

    // Converte uma forma [distância, desvio] em pontos no ecrã.
    // grow > 0 alarga a forma em todas as direções (para o contorno).
    private function handPoints(cx, cy, angle, shape, s, grow) {
        var pts = [];
        for (var i = 0; i < shape.size(); i++) {
            var r = shape[i][0];
            var off = shape[i][1];
            r = r + (r < 0 ? -grow : grow);
            if (off > 0) {
                off = off + grow;
            } else if (off < 0) {
                off = off - grow;
            }
            pts.add(pt(cx, cy, angle, r * s, off * s));
        }
        return pts;
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

    // Ponto a uma distância r do centro no ângulo indicado, com desvio lateral off.
    private function pt(cx, cy, angle, r, off) {
        var a = Math.toRadians(angle);
        var sn = Math.sin(a);
        var cs = Math.cos(a);
        return [cx + r * sn + off * cs, cy - r * cs + off * sn];
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
