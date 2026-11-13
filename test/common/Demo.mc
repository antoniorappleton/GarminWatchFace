import Toybox.Lang;

// Dados fixos para validar os mostradores contra a folha de produção.
(:mock)
function demoValue(id, style, dark) {
    if (id == -1) {
        return DEMO_STYLE;
    } else if (id == -2) {
        return DEMO_DARK;
    }
    var navyMorning = style == 0 && !dark;
    var navyEvening = style == 0 && dark;
    if (id == 15) {
        if (style == 1) {
            return "1654Z";
        }
        if (navyMorning) {
            return "0240Z";
        }
        if (navyEvening) {
            return "1950Z";
        }
        return "1633Z";
    } else if (id == 16) {
        if (navyMorning) {
            return 2;
        }
        if (navyEvening) {
            return 19;
        }
        return 16;
    } else if (id == 17) {
        if (navyMorning) {
            return 40;
        }
        if (navyEvening) {
            return 50;
        }
        return 33;
    } else if (id == 18) {
        return "85%";
    }
    return ["112m", "1018", "14", "30%", "12KT", "07:24", "17:28", "62%", "352", "",
        "N3843.5 W00911.1", "H", "O", "N", "10"][id];
}
