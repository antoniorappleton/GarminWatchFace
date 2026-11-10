import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Ponto de entrada do mostrador: o sistema chama getInitialView ao arrancar.
class TaticoNavyApp extends Application.AppBase {

    private var _view = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        _view = new TaticoNavyView();
        return [_view];
    }

    // Menu de definições no próprio relógio (personalizar mostrador).
    // Cada linha mostra a opção atual; selecionar passa à opção seguinte.
    function getSettingsView() {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.AppName});
        var defs = settingDefs();
        for (var i = 0; i < defs.size(); i++) {
            var options = defs[i][2];
            if (defs[i][3]) {
                var enabled = Application.Properties.getValue(defs[i][0]) == true;
                menu.addItem(new WatchUi.ToggleMenuItem(defs[i][1], null, i, enabled, null));
            } else {
                var v = Application.Properties.getValue(defs[i][0]);
                if (!(v instanceof Number) || v < 0 || v >= options.size()) {
                    v = 0;
                }
                menu.addItem(new WatchUi.MenuItem(defs[i][1], options[v], i, null));
            }
        }
        return [menu, new TaticoNavySettingsDelegate()];
    }

    // Chamado quando as definições mudam (no relógio ou na app do telemóvel).
    function onSettingsChanged() as Void {
        if (_view != null) {
            _view.loadSettings();
        }
        WatchUi.requestUpdate();
    }
}

// Definições com lista de opções: [chave, título, nomes das opções].
function settingDefs() {
    var themes = [Rez.Strings.ThemeAuto, Rez.Strings.ThemeLight, Rez.Strings.ThemeDark];
    var coordinateFormats = [Rez.Strings.CoordDegreesMinutes, Rez.Strings.CoordDecimalMinutes];
    var bubbleFields = [Rez.Strings.FieldTemp, Rez.Strings.FieldRain, Rez.Strings.FieldWind,
        Rez.Strings.FieldMoon, Rez.Strings.FieldBattery, Rez.Strings.FieldAlt,
        Rez.Strings.FieldAzimuth, Rez.Strings.FieldCardinal];
    var fields = [Rez.Strings.FieldAlt, Rez.Strings.FieldPressure, Rez.Strings.FieldTemp,
        Rez.Strings.FieldRain, Rez.Strings.FieldWind, Rez.Strings.FieldSunrise,
        Rez.Strings.FieldSunset, Rez.Strings.FieldMoon, Rez.Strings.FieldAzimuth, Rez.Strings.None];
    return [
        ["Style", Rez.Strings.StyleTitle, [Rez.Strings.StyleNavy, Rez.Strings.StyleZulu,
            Rez.Strings.StyleSurf], false],
        ["Theme", Rez.Strings.ThemeTitle, themes, false],
        ["ShowDTG", Rez.Strings.ShowDTGTitle, [], true],
        ["ShowCoordinates", Rez.Strings.ShowCoordinatesTitle, [], true],
        ["CoordFormat", Rez.Strings.CoordFormatTitle, coordinateFormats, false],
        ["ShowSignature", Rez.Strings.ShowSignatureTitle, [], true],
        ["TemperatureUnit", Rez.Strings.TemperatureUnitTitle,
            [Rez.Strings.UnitDevice, Rez.Strings.UnitCelsius, Rez.Strings.UnitFahrenheit], false],
        ["AltitudeUnit", Rez.Strings.AltitudeUnitTitle,
            [Rez.Strings.UnitDevice, Rez.Strings.UnitMeters, Rez.Strings.UnitFeet], false],
        ["PressureUnit", Rez.Strings.PressureUnitTitle,
            [Rez.Strings.UnitHpa, Rez.Strings.UnitInHg], false],
        ["SpeedUnit", Rez.Strings.SpeedUnitTitle,
            [Rez.Strings.UnitKnots, Rez.Strings.UnitKmh], false],
        ["NavyBubble1", Rez.Strings.NavyBubble1Title, bubbleFields, false],
        ["NavyBubble2", Rez.Strings.NavyBubble2Title, bubbleFields, false],
        ["ZuluBubble1", Rez.Strings.ZuluBubble1Title, bubbleFields, false],
        ["ZuluBubble2", Rez.Strings.ZuluBubble2Title, bubbleFields, false],
        ["SurfBubble1", Rez.Strings.SurfBubble1Title, bubbleFields, false],
        ["SurfBubble2", Rez.Strings.SurfBubble2Title, bubbleFields, false],
        ["ZuluField1", Rez.Strings.ZuluField1Title, fields, false],
        ["ZuluField2", Rez.Strings.ZuluField2Title, fields, false],
        ["SurfLine1", Rez.Strings.SurfLine1Title, fields, false],
        ["SurfLine2", Rez.Strings.SurfLine2Title, fields, false]
    ];
}

// Grava a escolha do menu de definições.
class TaticoNavySettingsDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        var def = settingDefs()[id];
        if (def[3]) {
            Application.Properties.setValue(def[0], (item as WatchUi.ToggleMenuItem).isEnabled());
        } else {
            var options = def[2];
            var v = Application.Properties.getValue(def[0]);
            v = (v instanceof Number) ? (v + 1) % options.size() : 0;
            Application.Properties.setValue(def[0], v);
            item.setSubLabel(options[v]);
        }
        Application.getApp().onSettingsChanged();
    }
}
