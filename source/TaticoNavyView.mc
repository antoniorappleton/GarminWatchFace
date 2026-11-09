import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

// Tático Navy — mostrador tático/militar para o Instinct 3 Solar.
// - Numeração que muda com o período do dia (manhã 12, 1–11 | tarde 12, 13–23):
//   eixos cardeais em tamanho grande, restantes em tamanho pequeno.
// - Ponteiros tipo espada com faixa interior ("lume").
// - Data e hora em formato militar DTG (Date-Time Group): DDHHMM + letra do fuso (ex.: 091652Z).
// - Subjanela: temperatura e probabilidade de precipitação.
// - Assinatura da marca por baixo do 12.
//
// Convenção de ângulos: 0° = 12 horas, a crescer no sentido dos ponteiros.
// Medidas em unidades do ecrã de referência (176 px), multiplicadas por s.
class TaticoNavyView extends WatchUi.WatchFace {

    // true = fundo preto e elementos brancos; false = fundo branco
    private var _dark = false;

    // Assinatura. Usar "®" só com a marca registada; caso contrário, "™".
    private var _brand = "APPLETON®";

    private var _fg = Graphics.COLOR_BLACK;  // cor dos elementos
    private var _bg = Graphics.COLOR_WHITE;  // cor do fundo
    private var _sleeping = false;
    private var _sub = null;  // área da subjanela (BoundingBox) ou null

    // Formas dos ponteiros: pares [distância ao centro, desvio lateral].
    // Distância negativa = cauda do ponteiro.
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

        _fg = _dark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        _bg = _dark ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
        dc.setColor(_bg, _bg);
        dc.clear();

        drawTicks(dc, cx, cy, s);
        drawNumerals(dc, cx, cy, s, t.hour >= 12);
        drawBrand(dc, cx, cy, s);
        drawDtg(dc, cx, cy, s);
        drawHands(dc, cx, cy, s, t);
        drawSubscreen(dc, cx, cy, s);  // por último: a subjanela tapa os ponteiros
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

    // Anel exterior: minutos finos, horas médias, eixos cardeais grossos.
    private function drawTicks(dc as Dc, cx, cy, s) as Void {
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        var rOut = 86 * s;
        for (var i = 0; i < 60; i++) {
            var rIn = 82 * s;
            var pen = 1;
            if (i % 15 == 0) {
                rIn = 75 * s;
                pen = 5;
            } else if (i % 5 == 0) {
                rIn = 78 * s;
                pen = 3;
            }
            var p1 = pt(cx, cy, i * 6, rIn, 0);
            var p2 = pt(cx, cy, i * 6, rOut, 0);
            if (insideSub(p1, 6 * s) || insideSub(p2, 6 * s)) {
                continue;
            }
            dc.setPenWidth(pw(pen, s));
            dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        }
    }

    // Numeração: manhã 12, 1–11; tarde 12, 13–23.
    // Eixos cardeais (12, 3, 6, 9) grandes; restantes pequenos e mais perto da borda.
    private function drawNumerals(dc as Dc, cx, cy, s, pm) as Void {
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i <= 12; i++) {
            var cardinal = (i % 3 == 0);
            var p = pt(cx, cy, i * 30, cardinal ? 62 * s : 67 * s, 0);
            if (insideSub(p, 10 * s)) {
                continue;
            }
            var label = i;
            if (pm && i != 12) {
                label = i + 12;
            }
            dc.drawText(p[0], p[1], cardinal ? Graphics.FONT_MEDIUM : Graphics.FONT_XTINY,
                label.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Assinatura da marca por baixo do 12.
    private function drawBrand(dc as Dc, cx, cy, s) as Void {
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 36 * s, Graphics.FONT_XTINY, _brand,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Data e hora militar (DTG) abaixo do centro, numa linha: DD HHMM + letra do fuso.
    // Ex.: 091652Z = dia 09, 16h52, fuso Z (UTC).
    // O dia vai numa caixa invertida para se distinguir da hora (o ecrã MIP só tem preto e branco).
    // Usa sempre 24 horas e a hora local; a letra indica o fuso.
    private function drawDtg(dc as Dc, cx, cy, s) as Void {
        var now = Time.now();
        var local = Gregorian.info(now, Time.FORMAT_SHORT);
        var utc = Gregorian.utcInfo(now, Time.FORMAT_SHORT);

        var day = local.day.format("%02d");
        var rest = local.hour.format("%02d") + local.min.format("%02d") + zoneLetter(local, utc);

        var font = Graphics.FONT_SMALL;
        var pad = 2 * s;
        var gap = 2 * s;
        var wDay = dc.getTextWidthInPixels(day, font);
        var wRest = dc.getTextWidthInPixels(rest, font);
        var h = dc.getFontHeight(font);
        var y = cy + 28 * s;
        var left = cx - (wDay + 2 * pad + gap + wRest) / 2;

        // Dia: caixa cheia com texto na cor do fundo
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(left, y - h / 2, wDay + 2 * pad, h, 2 * s);
        dc.setColor(_bg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + pad, y, font, day, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Hora, minutos e fuso
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + wDay + 2 * pad + gap, y, font, rest,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Subjanela: temperatura grande em cima, probabilidade de precipitação em baixo.
    // Sem subjanela (outros modelos): meteorologia numa linha acima da assinatura.
    private function drawSubscreen(dc as Dc, cx, cy, s) as Void {
        var temp = "--°";
        var rain = "--%";
        var cond = getConditions();
        if (cond != null) {
            if (cond.temperature != null) {
                var tc = cond.temperature;  // sempre em graus Celsius
                if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
                    tc = tc * 9 / 5 + 32;
                }
                temp = tc.format("%d") + "°";
            }
            if (cond.precipitationChance != null) {
                rain = cond.precipitationChance.format("%d") + "%";
            }
        }

        if (_sub == null) {
            dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
            drawDropLine(dc, cx, cy - 48 * s, s, temp + " ", rain);
            return;
        }

        var sx = _sub.x + _sub.width / 2;
        var sy = _sub.y + _sub.height / 2;
        var sr = (_sub.width < _sub.height ? _sub.width : _sub.height) / 2;
        var u = sr / 30.0;  // escala relativa a uma subjanela de 30 px de raio

        // Fundo invertido em relação ao mostrador
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, sy, sr);
        dc.setColor(_bg, Graphics.COLOR_TRANSPARENT);

        dc.drawText(sx, sy - 6 * u, Graphics.FONT_MEDIUM, temp,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        drawDropLine(dc, sx, sy + 14 * u, u, "", rain);
    }

    // Texto opcional + gota + valor, centrado em (x, y). A cor vem do chamador.
    private function drawDropLine(dc as Dc, x, y, u, prefix, value) as Void {
        var font = Graphics.FONT_XTINY;
        var dropW = 5 * u;
        var gap = 2 * u;
        var w0 = prefix.length() > 0 ? dc.getTextWidthInPixels(prefix, font) : 0;
        var w1 = dc.getTextWidthInPixels(value, font);
        var left = x - (w0 + dropW + gap + w1) / 2;

        if (w0 > 0) {
            dc.drawText(left, y, font, prefix, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        drawDrop(dc, left + w0 + dropW / 2, y, u);
        dc.drawText(left + w0 + dropW + gap, y, font, value,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---------- Ponteiros ----------

    // Ponteiros espada: contorno na cor do fundo, corpo e faixa interior ("lume").
    private function drawHands(dc as Dc, cx, cy, s, t) as Void {
        var hourAngle = (t.hour % 12 + t.min / 60.0) * 30;
        var minAngle = t.min * 6;

        drawSword(dc, cx, cy, hourAngle, _hourShape, _hourLume, s);
        drawSword(dc, cx, cy, minAngle, _minShape, _minLume, s);

        // Eixo central
        dc.setColor(_bg, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 6.5 * s);
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 5 * s);
        dc.setColor(_bg, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 1.5 * s);
    }

    private function drawSword(dc as Dc, cx, cy, angle, shape, lume, s) as Void {
        dc.setColor(_bg, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(handPoints(cx, cy, angle, shape, s, 1.5));
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(handPoints(cx, cy, angle, shape, s, 0));
        dc.setColor(_bg, Graphics.COLOR_TRANSPARENT);
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

    // ---------- Ícones ----------

    // Gota de água: círculo em baixo, ponta em cima.
    private function drawDrop(dc as Dc, x, y, u) as Void {
        var r = 2.5 * u;
        dc.fillCircle(x, y + 1.5 * u, r);
        dc.fillPolygon([[x - r, y + 1.5 * u], [x + r, y + 1.5 * u], [x, y - 4 * u]]);
    }

    // ---------- Dados ----------

    // Letra militar do fuso horário a partir da diferença entre hora local e UTC.
    // Z = UTC; A–M (sem J) = UTC+1…+12; N–Y = UTC−1…−12; J = fuso não inteiro.
    private function zoneLetter(local, utc) as String {
        var diff = (local.hour * 60 + local.min) - (utc.hour * 60 + utc.min);
        if (diff > 720) {
            diff -= 1440;
        } else if (diff < -720) {
            diff += 1440;
        }
        if (diff % 60 != 0) {
            return "J";
        }
        var h = diff / 60;
        if (h == 0) {
            return "Z";
        }
        if (h > 0 && h <= 12) {
            return "ABCDEFGHIKLM".substring(h - 1, h);
        }
        if (h < 0 && h >= -12) {
            return "NOPQRSTUVWXY".substring(-h - 1, -h);
        }
        return "J";
    }

    // Condições meteorológicas atuais (vêm do telemóvel). null se indisponíveis.
    private function getConditions() {
        if (Toybox has :Weather) {
            return Weather.getCurrentConditions();
        }
        return null;
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
