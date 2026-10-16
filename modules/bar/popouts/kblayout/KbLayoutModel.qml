pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.services

// NIRI-PORT(U28): layouts, active index and switching come from niri IPC via Compositor
// (KeyboardLayoutsChanged / KeyboardLayoutSwitched, SwitchLayout{Index}) instead of the previous compositor CLI and xkb XML parsing.
// niri reports full layout names ("English (US)"); codes come from Compositor.kbCode (xkb base.lst).

Item {
    id: model

    property alias visibleModel: visibleModel
    property string activeLabel: ""
    property int activeIndex: -1
    property bool _notifiedLimit: false

    function start() {
        _setLayouts();
    }

    function refresh() {
        _notifiedLimit = false;
        _setLayouts();
    }

    function switchTo(idx) {
        Compositor.switchKbLayout(idx);
    }

    function _short(desc) {
        const m = desc.match(/^(.*)\((.*)\)$/);
        if (!m)
            return desc;
        const lang = m[1].trim();
        const region = m[2].trim();
        const code = (region.split(/[,\s-]/)[0] || region).slice(0, 2).toUpperCase();
        // TRANSLATORS: %1 = language, %2 = layout code
        return Tr.trCtx("%1 (%2)", "keyboard layout language and code").arg(lang).arg(code);
    }

    // Indices must match niri's layout indices, so no deduplication here
    function _setLayouts() {
        layoutsModel.clear();
        Compositor.kbLayouts.forEach((name, idx) => layoutsModel.append({
                layoutIndex: idx,
                token: Compositor.kbCode(name),
                label: _pretty(name)
            }));
        _setActive();
    }

    function _setActive() {
        const idx = Compositor.kbLayoutIndex;
        model.activeIndex = idx >= 0 && idx < layoutsModel.count ? idx : -1;
        model.activeLabel = model.activeIndex >= 0 ? layoutsModel.get(idx).label : "";
        _rebuildVisible();
    }

    function _rebuildVisible() {
        visibleModel.clear();

        let arr = [];
        for (let i = 0; i < layoutsModel.count; i++)
            arr.push(layoutsModel.get(i));

        arr = arr.filter(i => i.layoutIndex !== activeIndex);
        arr.forEach(i => visibleModel.append(i));

        if (!GlobalConfig.utilities.toasts.kbLimit)
            return;

        if (layoutsModel.count > 4) {
            Toaster.toast(Tr.tr("Keyboard layout limit"), Tr.tr("XKB supports only 4 layouts at a time"), "warning");
        }
    }

    function _pretty(name) {
        // TRANSLATORS: %1 = layout code, %2 = layout name
        return Tr.trCtx("%1 - %2", "keyboard layout code and name").arg(Compositor.kbCode(name).toUpperCase()).arg(_short(name));
    }

    visible: false

    ListModel {
        id: visibleModel
    }

    ListModel {
        id: layoutsModel
    }

    Connections {
        function onKbLayoutsChanged(): void {
            model._setLayouts();
        }

        function onKbLayoutIndexChanged(): void {
            model._setActive();
        }

        function onKbMapRevisionChanged(): void {
            model._setLayouts();
        }

        target: Compositor
    }
}
