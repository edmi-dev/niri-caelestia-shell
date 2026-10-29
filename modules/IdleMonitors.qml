pragma ComponentBehavior: Bound

import "lock"
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.Services
import qs.services
// NIRI-PORT(F16): qualified, Quickshell.Wayland also exports an IdleInhibitor type
import qs.services as Services

Scope {
    id: root

    required property Lock lock
    readonly property bool hasPlayer: Players.list.some(p => p.isPlaying)
    readonly property bool isCharging: !UPower.onBattery
    readonly property bool enabled: {
        if (GlobalConfig.general.idle.inhibitWhenAudio && hasPlayer)
            return false;
        if (GlobalConfig.general.idle.inhibitWhenCharging && isCharging)
            return false;
        return true;
    }

    // NIRI-PORT(F16): keep awake "noSleep" skips idle timeouts whose action suspends or hibernates
    function isSleepAction(action: var): bool {
        let cmd = typeof action === "string" ? action.trim().split(/\s+/) : Array.from(action ?? []);
        if ((cmd[0] === "systemctl" || cmd[0] === "loginctl") && cmd.length === 2)
            cmd = cmd.slice(1);
        const name = String(cmd[0] ?? "").replace(/[-_]/g, "").toLowerCase();
        return ["suspend", "suspendthenhibernate", "hibernate", "hybridsleep"].includes(name);
    }

    function handleIdleAction(action: var): void {
        if (!action)
            return;

        if (action === "lock")
            lock.lock.locked = true;
        else if (action === "unlock")
            lock.lock.locked = false;
        // NIRI-PORT(U56): niri has no generic dispatcher; only the DPMS actions map to niri actions
        else if (action === "dpms off" || action === "dpms on")
            Compositor.setDpms(action === "dpms on");
        else if (typeof action === "string")
            console.warn("caelestia.idle: unsupported compositor action on niri:", action);
        else if (!SessionManager.exec(action))
            Quickshell.execDetached(action);
    }

    Connections {
        function onAboutToSleep(): void {
            if (GlobalConfig.general.idle.lockBeforeSleep)
                root.lock.lock.locked = true;
        }

        function onLockRequested(): void {
            root.lock.lock.locked = true;
        }

        function onUnlockRequested(): void {
            root.lock.lock.unlock();
        }

        target: SessionManager
    }

    Variants {
        // NIRI-PORT(F19): the current power-switch profile's timeouts replace shell.json on the laptop
        model: Services.PowerSwitch.idleTimeouts ?? GlobalConfig.general.idle.timeouts.values

        IdleMonitor {
            required property var modelData

            enabled: {
                if (!root.enabled || !(modelData.enabled ?? true))
                    return false;
                // NIRI-PORT(F16): keep awake "noLock" skips every timeout itself; niri honours the Wayland
                // inhibitor only while its surface is scanned out (src/niri.rs refresh_idle_inhibit), so it
                // stops working e.g. under a fullscreen window
                if (Services.IdleInhibitor.preventLock)
                    return false;
                if (modelData.inhibitWhenAudio && root.hasPlayer)
                    return false;
                if (modelData.inhibitWhenCharging && root.isCharging)
                    return false;
                if (Services.IdleInhibitor.preventSleep && root.isSleepAction(modelData.idleAction))
                    return false;
                return true;
            }
            timeout: modelData.timeout
            respectInhibitors: modelData.respectInhibitors ?? true
            onIsIdleChanged: root.handleIdleAction(isIdle ? modelData.idleAction : modelData.returnAction)
        }
    }
}
