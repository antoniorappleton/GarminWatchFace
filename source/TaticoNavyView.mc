import Toybox.Activity;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

// Tático Navy — mostradores táticos para o Instinct 3 Solar (176 x 176 px, 1 bit).
//
// Três estilos, escolhidos nas definições:
//   0 Navy  analógico, claro ou escuro
//   1 Zulu  digital, claro ou escuro
//   2 Surf  analógico, sempre escuro, com onda e duas linhas de dados
//
// As posições são as da folha de design (tatico-navy-folha.png), píxel a píxel.
// Todo o texto, ícones e marcas vêm de fontes de píxeis geradas por
// tools/gen_assets.py; só os ponteiros são polígonos.
//
// Campos (ids usados em value() e nas definições):
//   0 altitude  1 pressão  2 temperatura  3 chuva  4 vento
//   5 nascer do sol  6 pôr do sol  7 lua  8 azimute  9 vazio
//   10 coordenadas  13 rumo cardinal  14 dia UTC  15 HHMMZ  16 bateria
class TaticoNavyView extends WatchUi.WatchFace {

    private var _style = 0;
    private var _theme = 0;
    private var _dark = false;
    private var _fg = Graphics.COLOR_BLACK;
    private var _bg = Graphics.COLOR_WHITE;

    private var _showDTG = true;
    private var _showCoordinates = true;
    private var _coordFormat = 1;
    private var _showSignature = true;
    private var _temperatureUnit = 0;
    private var _altitudeUnit = 0;
    private var _pressureUnit = 0;
    private var _speedUnit = 0;
    private var _bubbleA = 2;
    private var _bubbleB = 3;
    private var _fieldA = 0;    // campos do Zulu ou linhas do Surf
    private var _fieldB = 1;

    private var _f9 = null;
    private var _f13 = null;
    private var _f17 = null;
    private var _icons = null;
    private var _ring = null;   // só nos estilos analógicos
    private var _f28 = null;    // só no Zulu
    private var _f46 = null;
    private var _topoLight = null;
    private var _topoDark = null;

    private var _sx = 113;      // canto da caixa da subjanela (62 x 62 px)
    private var _sy = 7;

    private var _cond = null;   // meteorologia e atividade, lidas uma vez por atualização
    private var _info = null;
    private var _loc = null;    // última posição conhecida [latitude, longitude]

    // Formas dos ponteiros: pares [distância ao centro, desvio lateral].
    private var _hourBlade = [[4.25, 4.6], [30.5, 4.6], [42, 0], [30.5, -4.6], [4.25, -4.6]];
    private var _hourLume = [[11, 2.4], [30.75, 2.4], [36, 0], [30.75, -2.4], [11, -2.4]];
    private var _minBlade = [[6.5, 3.8], [65, 3.8], [75, 0], [65, -3.8], [6.5, -3.8]];
    private var _minLume = [[12.5, 1.6], [64, 1.6], [69, 0], [64, -1.6], [12.5, -1.6]];
    private var _pommel = [[-10.75, 0], [-8, 3], [-5.25, 0], [-8, -3]];

    // Numerais das 3 às 12: centro x, topo y, cardeal (1 = fonte de 17 px).
    // Os das posições 1 e 2 ficam sempre por baixo da subjanela.
    private var _numerals = [150, 78, 1, 148, 116, 0, 122, 142, 0, 88, 140, 1, 53, 142, 0,
        28, 117, 0, 26, 78, 1, 28, 47, 0, 53, 22, 0, 88, 16, 1];

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _f9 = WatchUi.loadResource(Rez.Fonts.F9);
        _f13 = WatchUi.loadResource(Rez.Fonts.F13);
        _f17 = WatchUi.loadResource(Rez.Fonts.F17);
        _icons = WatchUi.loadResource(Rez.Fonts.Icons);
        _topoLight = WatchUi.loadResource(Rez.Drawables.TopoLight);
        _topoDark = WatchUi.loadResource(Rez.Drawables.TopoDark);
        if (WatchUi has :getSubscreen) {
            var sub = WatchUi.getSubscreen();
            if (sub != null) {
                _sx = sub.x;
                _sy = sub.y;
            }
        }
        loadSettings();
    }

    private function autoDark() as Boolean {
        var local = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return local.hour < 6 || local.hour >= 18;
    }

    private function applyTheme() as Void {
        _dark = _style == 2 || _theme == 2 || (_theme == 0 && autoDark());
        if (_style != 2 && _theme == 1) {
            _dark = false;
        }
        _fg = _dark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        _bg = _dark ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
    }

    // Lê as definições e carrega só as fontes do estilo ativo (a memória é curta).
    function loadSettings() as Void {
        _style = setting("Style", 2);
        var demo = demoValue(-1, 0, false);
        if (demo != null) {
            _style = demo;
        }
        _theme = setting("Theme", 2);
        demo = demoValue(-2, 0, false);
        if (demo != null) {
            _theme = demo ? 2 : 1;
        }
        applyTheme();
        _showDTG = propertyEnabled("ShowDTG", true);
        _showCoordinates = propertyEnabled("ShowCoordinates", true);
        _coordFormat = setting("CoordFormat", 1);
        _showSignature = propertyEnabled("ShowSignature", true);
        _temperatureUnit = setting("TemperatureUnit", 2);
        _altitudeUnit = setting("AltitudeUnit", 2);
        _pressureUnit = setting("PressureUnit", 1);
        _speedUnit = setting("SpeedUnit", 1);
        var bubbleFields = [2, 3, 4, 7, 18, 0, 8, 13];
        var bubbleA = setting(["NavyBubble1", "ZuluBubble1", "SurfBubble1"][_style], 7);
        var bubbleB = setting(["NavyBubble2", "ZuluBubble2", "SurfBubble2"][_style], 7);
        _bubbleA = bubbleFields[bubbleA];
        _bubbleB = bubbleFields[bubbleB];
        _fieldA = setting(_style == 2 ? "SurfLine1" : "ZuluField1", 9);
        _fieldB = setting(_style == 2 ? "SurfLine2" : "ZuluField2", 9);

        _ring = null;
        _f28 = null;
        _f46 = null;
        if (_f9 == null) {
            return;  // ainda sem onLayout
        }
        if (_style == 1) {
            _f28 = WatchUi.loadResource(Rez.Fonts.F28);
            _f46 = WatchUi.loadResource(Rez.Fonts.F46);
        } else {
            _ring = WatchUi.loadResource(Rez.Fonts.Ring);
        }
    }

    // Desenha sempre o ecrã inteiro (evita artefactos na subjanela).
    function onUpdate(dc as Dc) as Void {
        if (_style != 2 && _theme == 0) {
            applyTheme();
        }
        _cond = Weather.getCurrentConditions();
        _info = Activity.getActivityInfo();
        dc.setColor(_bg, _bg);
        dc.clear();
        if (_style == 0 && demoValue(-1, 0, false) == null) {
            dc.drawBitmap(0, 0, _dark ? _topoDark : _topoLight);
        }
        if (_style == 1) {
            drawZulu(dc);
        } else {
            drawAnalog(dc);
        }
        drawSubscreen(dc);
        _cond = null;
        _info = null;
    }

    // ---------- Navy e Surf ----------

    private function drawAnalog(dc as Dc) as Void {
        var clock = System.getClockTime();
        var hour = clock.hour;
        var min = clock.min;
        var demo = demoValue(16, _style, _dark);
        if (demo != null) {
            hour = demo;
            min = demoValue(17, _style, _dark);
        }

        // Anel das marcas (4 mosaicos); as marcas junto à subjanela não se desenham.
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            text(dc, 88 * (i % 2), 88 * (i / 2), _ring, i.toString());
        }
        dc.setColor(_bg, _bg);
        dc.fillRectangle(_sx - 6, 0, 182 - _sx, _sy + 68);

        drawSword(dc, (hour % 12 + min / 60.0) * 30, _hourBlade, _hourLume);
        drawSword(dc, min * 6, _minBlade, _minLume);
        dc.setColor(_bg, _bg);
        dc.fillCircle(88, 88, 6);
        dc.setColor(_fg, _bg);
        dc.fillCircle(88, 88, 5);
        dc.setColor(_bg, _bg);
        dc.fillCircle(88, 88, 1);

        // Texto acima dos ponteiros para preservar a leitura dos dados e da escala.
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        for (var i = 3; i <= 12; i++) {
            var k = (i - 3) * 3;
            var label = (hour >= 12 && i != 12) ? i + 12 : i;
            centered(dc, _numerals[k], _numerals[k + 1],
                _numerals[k + 2] == 1 ? _f17 : _f9, label.toString());
        }
        if (_showSignature) {
            text(dc, 67, 36, _f9, "appleton");
        }
        if (_style == 2) {
            text(dc, 64, 52, _icons, "~");
            drawSurfLine(dc, 57, _fieldA);
            drawSurfLine(dc, 68, _fieldB);
        }
        if (_showDTG) {
            var day = value(14);
            var time = value(15);
            var left = (151 - dc.getTextWidthInPixels(time, _f13)) / 2;
            outlined(dc, left, 97, _f17, day);
            outlined(dc, left + 26, 100, _f13, time);
        }
        var line = dataLine();
        if (line.length() > 0) {
            outlined(dc, (177 - dc.getTextWidthInPixels(line, _f9)) / 2, 118, _f9, line);
        }
    }

    // Linha de dados do Surf: triângulo + hora para o sol, sigla + valor para o resto.
    private function drawSurfLine(dc as Dc, y, id) as Void {
        if (id == 9) {
            return;
        }
        if (id == 5 || id == 6) {
            text(dc, 40, y + 3, _icons, id == 5 ? "^" : "v");
            text(dc, 50, y, _f9, value(id));
        } else {
            text(dc, 40, y, _f9, fieldLabel(id) + " " + fieldText(id));
        }
    }

    // Espada: contorno na cor do fundo, lâmina com faixa interior e pomo na cauda.
    private function drawSword(dc as Dc, angle, blade, lume) as Void {
        dc.setColor(_bg, _bg);
        dc.fillPolygon(handPoints(angle, _pommel, 1.5));
        dc.fillPolygon(handPoints(angle, blade, 1.5));
        dc.setColor(_fg, _bg);
        dc.fillPolygon(handPoints(angle, _pommel, 0));
        dc.fillPolygon(handPoints(angle, blade, 0));
        dc.setColor(_bg, _bg);
        dc.fillPolygon(handPoints(angle, lume, 0));
    }

    // Converte uma forma [distância, desvio] em pontos no ecrã (0° = 12 horas).
    // grow > 0 alarga a forma em todas as direções (para o contorno).
    private function handPoints(angle, shape, grow) {
        var a = Math.toRadians(angle);
        var sn = Math.sin(a);
        var cs = Math.cos(a);
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
            pts.add([88 + r * sn + off * cs, 88 - r * cs + off * sn]);
        }
        return pts;
    }

    // ---------- Zulu ----------

    private function drawZulu(dc as Dc) as Void {
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        drawZuluField(dc, 46, _fieldA);
        drawZuluField(dc, 88, _fieldB);
        dc.fillRectangle(8, 68, 101, 1);
        dc.fillRectangle(4, 117, 168, 1);

        if (_showDTG) {
            // Dia em xadrez: o conjunto de dígitos depende da paridade da posição.
            var day = value(14);
            for (var i = 0; i < 2; i++) {
                var digit = day.substring(i, i + 1);
                if (i == 0) {
                    digit = ((digit.toNumber() + 97).toChar()).toString();
                }
                text(dc, 13 + 29 * i, 66, _f46, digit);
            }
            // HHMMZ: avanço de 17,5 px, arredondado letra a letra.
            var time = value(15);
            for (var i = 0; i < time.length(); i++) {
                text(dc, 76 + (35 * i + 1) / 2, 83, _f28, time.substring(i, i + 1));
            }
        }

        if (_showCoordinates) {
            centered(dc, 88, 121, _f13, value(10));
        }
        if (_showSignature) {
            text(dc, 58, 143, _icons, "r");
            text(dc, 67, 152, _f9, "appleton");
        }
    }

    private function drawZuluField(dc as Dc, cx, id) as Void {
        if (id != 9) {
            centered(dc, cx, 30, _f9, fieldLabel(id));
            centered(dc, cx, 40, _f13, fieldText(id));
        }
    }

    // ---------- Subjanela ----------

    // Fundo invertido em relação ao mostrador.
    private function drawSubscreen(dc as Dc) as Void {
        var cx = _sx + 31;
        dc.setColor(_fg, _fg);
        dc.fillCircle(cx, _sy + 31, 31);
        dc.setColor(_bg, Graphics.COLOR_TRANSPARENT);

        if (_style == 2) {
            var wind = fieldText(_bubbleA);
            var left = (2 * cx - 11 - dc.getTextWidthInPixels(wind, _f13)) / 2;
            text(dc, left, _sy + 17, _icons, value(11));
            text(dc, left + 12, _sy + 14, _f13, wind);
            var moon = fieldText(_bubbleB);
            left = (2 * cx - 14 - dc.getTextWidthInPixels(moon, _f9)) / 2;
            text(dc, left, _sy + 37, _icons, value(12));
            text(dc, left + 15, _sy + 36, _f9, moon);
            return;
        }
        centered(dc, cx, _sy + 11, _f17, fieldText(_bubbleA));
        centered(dc, cx, _sy + 34, _f13, fieldText(_bubbleB));
    }

    // ---------- Texto ----------

    private function text(dc as Dc, x, y, font, str) as Void {
        dc.drawText(x, y, font, str, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Centra em cx; com largura ímpar, o píxel a mais fica à esquerda (como na folha).
    private function centered(dc as Dc, cx, y, font, str) as Void {
        text(dc, (2 * cx + 1 - dc.getTextWidthInPixels(str, font)) / 2, y, font, str);
    }

    private function outlined(dc as Dc, x, y, font, str) as Void {
        if (str.length() == 0) {
            return;
        }
        dc.setColor(_bg, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 9; i++) {
            if (i != 4) {
                text(dc, x + i % 3 - 1, y + i / 3 - 1, font, str);
            }
        }
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        text(dc, x, y, font, str);
    }

    // ---------- Campos ----------

    private function fieldLabel(id) as String {
        if (id == 1 && _pressureUnit == 1) {
            return "INHG";
        }
        return ["ALT", "HPA", "TEMP", "CHUVA", "VENTO", "NASCER", "OCASO", "LUA",
            "AZ", "", "", "", "RUMO", "", "", "", "", "", "BATT"][id];
    }

    // Valor de um campo com a unidade (acrescenta o grau à temperatura e ao azimute).
    private function fieldText(id) as String {
        var v = value(id);
        return (id == 2 || id == 8) ? v + "°" : v;
    }

    private function dataLine() as String {
        return _showCoordinates ? value(10) : "";
    }

    // Texto de um dado. Os ids 10 e 13–16 são dados compostos do mostrador.
    private function value(id) {
        var demo = demoValue(id, _style, _dark);
        if (demo != null) {
            return demo;
        }
        var c = _cond;
        var v = null;
        if (id == 0) {
            v = altitude();
            if (v != null) {
                var feet = _altitudeUnit == 2 || (_altitudeUnit == 0
                    && System.getDeviceSettings().elevationUnits == System.UNIT_STATUTE);
                if (feet) {
                    return round(v * 3.28084).toString() + "ft";
                }
                return round(v).toString() + "m";
            }
        } else if (id == 1) {
            v = pressure();
            if (v != null) {
                if (_pressureUnit == 1) {
                    var hundredths = round(v / 3386.39 * 100);
                    return (hundredths / 100).format("%d") + "."
                        + (hundredths % 100).format("%02d");
                }
                return round(v / 100.0).toString();
            }
        } else if (id == 2) {
            if (c != null && c.temperature != null) {
                v = c.temperature;  // sempre em graus Celsius
                var fahrenheit = _temperatureUnit == 2 || (_temperatureUnit == 0
                    && System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE);
                if (fahrenheit) {
                    v = v * 9.0 / 5 + 32;
                }
                return round(v).toString();
            }
        } else if (id == 3) {
            if (c != null && c.precipitationChance != null) {
                return c.precipitationChance.format("%d") + "%";
            }
            return "--%";
        } else if (id == 4) {
            if (c != null && c.windSpeed != null) {
                if (_speedUnit == 1) {
                    return round(c.windSpeed * 3.6).toString() + "km/h";
                }
                return round(c.windSpeed * 1.94384).toString() + "KT";
            }
            return _speedUnit == 1 ? "--km/h" : "--KT";
        } else if (id == 5 || id == 6) {
            return sunTime(id == 5);
        } else if (id == 7 || id == 12) {
            // Idade da lua desde a lua nova de 6 de janeiro de 2000 (mês sinódico em segundos).
            var p = (Time.now().value() - 947182440) / 2551442.9;
            p = p - Math.floor(p);
            if (id == 12) {
                return (77 + (p * 8 + 0.5).toNumber() % 8).toChar().toString();
            }
            return round((1 - Math.cos(2 * Math.PI * p)) * 50).toString() + "%";
        } else if (id == 8 || id == 13) {
            v = _info != null ? _info.currentHeading : null;
            if (v != null) {
                var deg = (round(Math.toDegrees(v)) + 360) % 360;
                if (id == 8) {
                    return deg.format("%03d");
                }
                return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][((deg + 22) / 45) % 8];
            }
            return id == 8 ? "---" : "";
        } else if (id == 10) {
            v = location();
            if (v != null) {
                return formatDdm(v[0], "N", "S", "%02d") + " "
                    + formatDdm(v[1], "E", "W", "%03d");
            }
            return _coordFormat == 0 ? "N-- -- W--- --" : "N----.- W-----.-";
        } else if (id == 11) {
            // A seta aponta para onde o vento sopra (o rumo dado é de onde vem).
            if (c != null && c.windBearing != null) {
                return (65 + ((c.windBearing + 202) / 45) % 8).toChar().toString();
            }
            return "";
        } else if (id == 14 || id == 15) {
            var now = Time.now();
            var utc = Gregorian.utcInfo(now, Time.FORMAT_SHORT);
            if (id == 14) {
                return utc.day.format("%02d");
            }
            return utc.hour.format("%02d") + utc.min.format("%02d") + "Z";
        } else if (id == 18) {
            return System.getSystemStats().battery.format("%d") + "%";
        } else {
            return "";
        }
        return "--";
    }

    // ---------- Dados ----------

    private function round(x) as Number {
        return Math.round(x).toNumber();
    }

    // Altitude em metros: atividade em curso ou último registo do sensor.
    private function altitude() {
        if (_info != null && _info.altitude != null) {
            return _info.altitude;
        }
        if ((Toybox has :SensorHistory) && (SensorHistory has :getElevationHistory)) {
            var sample = SensorHistory.getElevationHistory({:period => 1}).next();
            if (sample != null) {
                return sample.data;
            }
        }
        return null;
    }

    // Pressão em pascais, de preferência reduzida ao nível do mar.
    private function pressure() {
        var i = _info;
        if (i != null && (i has :meanSeaLevelPressure) && i.meanSeaLevelPressure != null) {
            return i.meanSeaLevelPressure;
        }
        if (i != null && (i has :ambientPressure) && i.ambientPressure != null) {
            return i.ambientPressure;
        }
        if ((Toybox has :SensorHistory) && (SensorHistory has :getPressureHistory)) {
            var sample = SensorHistory.getPressureHistory({:period => 1}).next();
            if (sample != null) {
                return sample.data;
            }
        }
        return null;
    }

    // Última posição conhecida, em graus decimais [latitude, longitude], ou null.
    // Um mostrador não liga o GPS nem corre durante as atividades, por isso usa,
    // por ordem: a atividade em curso, o último ponto GPS do sistema, a posição
    // guardada e, por fim, o local da meteorologia vinda do telemóvel.
    private function location() {
        var fix = _info != null ? _info.currentLocation : null;
        if (fix == null) {
            var pos = Position.getInfo();
            if (pos != null && pos.accuracy != Position.QUALITY_NOT_AVAILABLE) {
                fix = pos.position;
            }
        }
        if (fix != null) {
            var deg = fix.toDegrees();
            // Sem ponto GPS, alguns relógios devolvem valores fora do globo.
            if (deg[0].abs() <= 90 && deg[1].abs() <= 180 && (_loc == null
                || (deg[0] - _loc[0]).abs() + (deg[1] - _loc[1]).abs() > 0.0005)) {
                _loc = [deg[0], deg[1]];
                Application.Storage.setValue("loc", _loc);
            }
        }
        if (_loc == null) {
            _loc = Application.Storage.getValue("loc");
        }
        if (_loc == null && _cond != null && _cond.observationLocationPosition != null) {
            return _cond.observationLocationPosition.toDegrees();
        }
        return _loc;
    }

    // Graus e minutos compactos: decimal ("N3843.5") ou inteiros ("N38 43").
    private function formatDdm(value, positive, negative, degFormat) as String {
        var tenths = round((value < 0 ? -value : value) * 600);  // décimos de minuto
        var degrees = tenths / 600;
        var minutes = tenths % 600;
        if (_coordFormat == 0) {
            var wholeMinutes = (minutes + 5) / 10;
            if (wholeMinutes == 60) {
                degrees += 1;
                wholeMinutes = 0;
            }
            return (value < 0 ? negative : positive) + degrees.format(degFormat)
                + " " + wholeMinutes.format("%02d");
        }
        return (value < 0 ? negative : positive) + degrees.format(degFormat)
            + (minutes / 10).format("%02d") + "." + (minutes % 10).toString();
    }

    // Hora local do nascer ou do pôr do sol na última posição conhecida ("HH:MM").
    // Equação do nascer do sol, em dias desde 1 de janeiro de 2000 às 12h UTC.
    private function sunTime(rise) as String {
        var loc = location();
        if (loc == null) {
            return "--:--";
        }
        var lat = Math.toRadians(loc[0]);
        var lonDays = loc[1] / 360.0d;
        // Dia do calendário local, para a meia-noite não trocar para a véspera.
        var days = (Time.now().value() + System.getClockTime().timeZoneOffset - 946728000) / 86400.0d;
        var noon = Math.floor(days + 0.5) - lonDays;          // meio-dia solar de hoje
        var m = Math.toRadians(357.5291d + 0.98560028d * noon);
        var l = m + Math.toRadians(1.9148 * Math.sin(m) + 0.02 * Math.sin(2 * m) + 282.9372);
        var transit = noon + 0.0053 * Math.sin(m) - 0.0069 * Math.sin(2 * l);
        var sinDec = Math.sin(l) * 0.39779;
        var cosHour = (-0.01454 - Math.sin(lat) * sinDec) / (Math.cos(lat) * Math.sqrt(1 - sinDec * sinDec));
        if (cosHour > 1 || cosHour < -1) {
            return "--:--";  // sol sempre acima ou abaixo do horizonte
        }
        var half = Math.acos(cosHour) / (2 * Math.PI);
        var when = 946728000 + ((rise ? transit - half : transit + half) * 86400 + 30).toNumber();
        var t = Gregorian.info(new Time.Moment(when), Time.FORMAT_SHORT);
        return t.hour.format("%02d") + ":" + t.min.format("%02d");
    }

    // Definição numérica entre 0 e max; qualquer outro valor conta como 0.
    private function setting(key, max) as Number {
        var v = Application.Properties.getValue(key);
        if (v instanceof Number && v >= 0 && v <= max) {
            return v;
        }
        return 0;
    }

    private function propertyEnabled(key, defaultValue) as Boolean {
        var value = Application.Properties.getValue(key);
        return value == null ? defaultValue : value == true;
    }
}

// Valores fixos da folha de design, para comparar o ecrã com ela.
// Só existem na build de teste (test.jungle); aqui não fazem nada.
(:live)
function demoValue(id, style, dark) {
    return null;
}
