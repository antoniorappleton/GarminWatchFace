import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Ponto de entrada do mostrador: o sistema chama getInitialView ao arrancar.
class TaticoNavyApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [new TaticoNavyView()];
    }

    // Menu de definições no próprio relógio (personalizar mostrador).
    function getSettingsView() {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.SettingsTitle});
        menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.DarkModeTitle, null, "dark",
            Application.Properties.getValue("DarkMode") == true, null));
        return [menu, new TaticoNavySettingsDelegate()];
    }

    // Chamado quando as definições mudam (no relógio ou na app do telemóvel).
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}

// Grava a escolha do menu de definições.
class TaticoNavySettingsDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        if (item.getId().equals("dark")) {
            Application.Properties.setValue("DarkMode", item.isEnabled());
            WatchUi.requestUpdate();
        }
    }
}
