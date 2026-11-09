import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Ponto de entrada do mostrador: o sistema chama getInitialView ao arrancar.
class TaticoClaroApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [new TaticoClaroView()];
    }
}
