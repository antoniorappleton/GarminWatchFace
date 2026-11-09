import Toybox.Activity;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

// Tático Navy — mostrador tático/militar para o Instinct 3 Solar.
// - Fundo branco ou preto, à escolha nas definições (no relógio ou no telemóvel).
// - Numeração que muda com o período do dia (manhã 12, 1–11 | tarde 12, 13–23):
//   eixos cardeais com a fonte do sistema, restantes com a fonte pequena própria.
// - Ponteiros tipo espada com faixa interior ("lume").
// - DTG: dia em grande + HHMM e letra do fuso (ex.: 09 2017Z).
// - Coordenadas em graus e minutos decimais, numa caixa de cantos chanfrados.
// - Subjanela: temperatura e probabilidade de precipitação.
// - Assinatura em minúsculas, sem tocar na subjanela.
//
// Convenção de ângulos: 0° = 12 horas, a crescer no sentido dos ponteiros.
// Medidas em unidades do ecrã de referência (176 px), multiplicadas por s.
class TaticoNavyView extends WatchUi.WatchFace {

    // Assinatura. Usar "®" só com a marca registada; caso contrário, "™".
    private var _brand = "appleton®";

    private var _small = Graphics.FONT_XTINY;  // substituída pela fonte própria em onLayout
    private var _fg = Graphics.COLOR_BLACK;    // cor dos elementos
    private var _bg = Graphics.COLOR_WHITE;    // cor do fundo
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
        _small = WatchUi.loadResource(Rez.Fonts.Small);
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

        var dark = Application.Properties.getValue("DarkMode") == true;
        _fg = dark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        _bg = dark ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
        dc.setColor(_bg, _bg);
        dc.clear();

        drawTicks(dc, cx, cy, s);
        drawNumerals(dc, cx, cy, s, t.hour >= 12);
        drawBrand(dc, cx, cy, s);
        drawDtg(dc, cx, cy, s);
        drawCoordinates(dc, cx, cy, s);
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

    // Numeração: manhã 12, 1–11; tarde 12, 13–23 (muda sozinha ao meio-dia e à meia-noite).
    // Eixos cardeais (12, 3, 6, 9) com a fonte do sistema; restantes com a fonte pequena.
    private function drawNumerals(dc as Dc, cx, cy, s, pm) as Void {
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i <= 12; i++) {
            var cardinal = (i % 3 == 0);
            var p = pt(cx, cy, i * 30, cardinal ? 63 * s : 70 * s, 0);
            if (insideSub(p, 8 * s)) {
                continue;
            }
            var label = i;
            if (pm && i != 12) {
                label = i + 12;
            }
            dc.drawText(p[0], p[1], cardinal ? Graphics.FONT_MEDIUM : _small,
                label.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Assinatura por baixo do 12. Se tocar na subjanela, desliza para a esquerda.
    private function drawBrand(dc as Dc, cx, cy, s) as Void {
        var y = cy - 32 * s;
        var w = dc.getTextWidthInPixels(_brand, _small);
        var h = dc.getFontHeight(_small);
        var x = cx;
        if (_sub != null && y + h / 2 > _sub.y && y - h / 2 < _sub.y + _sub.height) {
            var maxRight = _sub.x - 4 * s;
            if (x + w / 2 > maxRight) {
                x = maxRight - w / 2;
            }
        }
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, _small, _brand, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // DTG por baixo do centro: dia em grande + HHMM e letra do fuso em pequeno (ex.: 09 2017Z).
    // Usa sempre 24 horas e a hora local; a letra indica o fuso (Z = UTC).
    private function drawDtg(dc as Dc, cx, cy, s) as Void {
        var now = Time.now();
        var local = Gregorian.info(now, Time.FORMAT_SHORT);
        var utc = Gregorian.utcInfo(now, Time.FORMAT_SHORT);

        var day = local.day.format("%02d");
        var rest = local.hour.format("%02d") + local.min.format("%02d") + zoneLetter(local, utc);

        var bigFont = Graphics.FONT_MEDIUM;
        var smallFont = Graphics.FONT_XTINY;
        var gap = 4 * s;
        var wDay = dc.getTextWidthInPixels(day, bigFont);
        var wRest = dc.getTextWidthInPixels(rest, smallFont);
        var y = cy + 16 * s;
        var left = cx - (wDay + gap + wRest) / 2;

        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, y, bigFont, day, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(left + wDay + gap, y, smallFont, rest,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Coordenadas (graus e minutos decimais) numa caixa com os cantos de cima chanfrados.
    private function drawCoordinates(dc as Dc, cx, cy, s) as Void {
        var line1 = "N --°--.---'";
        var line2 = "W ---°--.---'";
        var loc = getLocation();
        if (loc != null) {
            line1 = formatDdm(loc[0], true);
            line2 = formatDdm(loc[1], false);
        }

        var lineStep = 10 * s;
        var pad = 3 * s;
        var textW = dc.getTextWidthInPixels(line2, _small);
        var w1 = dc.getTextWidthInPixels(line1, _small);
        if (w1 > textW) {
            textW = w1;
        }
        var bw = textW + 2 * pad + 2 * s;
        var top = cy + 28 * s;
        var bh = 2 * lineStep + 3 * s;
        var x0 = cx - bw / 2;
        var x1 = cx + bw / 2;
        var y1 = top + bh;
        var c = 4 * s;  // tamanho do chanfro

        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(x0 + c, top, x1 - c, top);
        dc.drawLine(x1 - c, top, x1, top + c);
        dc.drawLine(x1, top + c, x1, y1);
        dc.drawLine(x1, y1, x0, y1);
        dc.drawLine(x0, y1, x0, top + c);
        dc.drawLine(x0, top + c, x0 + c, top);

        // Texto alinhado à esquerda, para os valores ficarem em coluna
        var tx = cx - textW / 2;
        dc.drawText(tx, top + 1.5 * s + lineStep / 2, _small, line1,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(tx, top + 1.5 * s + lineStep * 1.5, _small, line2,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Subjanela: temperatura grande em cima, probabilidade de precipitação em baixo.
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

    // Última posição conhecida, em graus decimais [latitude, longitude], ou null.
    // Um mostrador não liga o GPS: usa a posição da última atividade e guarda-a,
    // para não a perder quando o relógio a descarta. Recurso final: a localização da meteorologia.
    private function getLocation() {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentLocation != null) {
            var deg = info.currentLocation.toDegrees();
            Application.Storage.setValue("loc", [deg[0], deg[1]]);
            return deg;
        }
        var saved = Application.Storage.getValue("loc");
        if (saved != null) {
            return saved;
        }
        var cond = getConditions();
        if (cond != null && cond.observationLocationPosition != null) {
            return cond.observationLocationPosition.toDegrees();
        }
        return null;
    }

    // Graus e minutos decimais, como nos GPS: "N 38°42.381'" / "W 009°10.714'".
    private function formatDdm(value, isLat) as String {
        var hemi;
        if (isLat) {
            hemi = value >= 0 ? "N" : "S";
        } else {
            hemi = value >= 0 ? "E" : "W";
        }
        var a = value < 0 ? -value : value;
        var deg = a.toNumber();
        var min = (a - deg) * 60.0;
        var minTxt = min.format("%.3f");
        if (min < 10) {
            minTxt = "0" + minTxt;
        }
        return hemi + " " + deg.format(isLat ? "%02d" : "%03d") + "°" + minTxt + "'";
    }

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
