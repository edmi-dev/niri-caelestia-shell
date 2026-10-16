pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.services

Singleton {
    id: root

    property alias enabled: props.enabled

    // NIRI-PORT(U47): niri has no runtime options; game mode is a generated KDL include (Q15 = a), see Compositor
    function setDynamicConfs(): void {
        Compositor.setGameMode(true);
    }

    onEnabledChanged: {
        // NIRI-PORT(U47): the include file persists across reloads; only act on a real change
        if (enabled === Compositor.gameMode)
            return;
        if (enabled) {
            setDynamicConfs();
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(Tr.tr("Game mode enabled"), Tr.tr("Disabled niri animations, blur, gaps and shadows"), "gamepad");
        } else {
            Compositor.setGameMode(false);
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(Tr.tr("Game mode disabled"), Tr.tr("niri settings restored"), "gamepad");
        }
    }

    PersistentProperties {
        id: props

        property bool enabled: Compositor.gameMode

        reloadableId: "gameMode"
    }


    IpcHandler {
        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
        }

        function enable(): void {
            props.enabled = true;
        }

        function disable(): void {
            props.enabled = false;
        }

        target: "gameMode"
    }
}
