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
}
