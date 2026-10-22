pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    // NIRI-PORT(F16): three-state keep awake. "off" — normal power management; "noSleep" — idle timeouts
    // with a sleep action are skipped (lock and DPMS still happen, see IdleMonitors.qml); "noLock" — a
    // Wayland idle inhibitor, nothing happens on idle. `enabled` (any mode but "off") and
    // the enable/disable IPC stay for upstream callers; enabling maps to "noLock".
    readonly property list<string> modes: ["off", "noSleep", "noLock"]
    property alias mode: props.mode
    readonly property bool enabled: props.mode !== "off"
    readonly property bool preventSleep: props.mode !== "off"
    readonly property bool preventLock: props.mode === "noLock"
    readonly property alias enabledSince: props.enabledSince

    onEnabledChanged: {
        if (enabled)
            props.enabledSince = new Date();
    }

    function setEnabled(enable: bool): void {
        props.mode = enable ? "noLock" : "off";
    }

    PersistentProperties {
        id: props

        property string mode: "off"
        property date enabledSince

        onModeChanged: {
            if (!root.modes.includes(mode))
                mode = "off";
        }

        reloadableId: "idleInhibitor"
    }

    IdleInhibitor {
        enabled: root.preventLock
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            mask: Region {}
        }
    }

    IpcHandler {
        function isEnabled(): bool {
            return root.enabled;
        }

        function toggle(): void {
            root.setEnabled(!root.enabled);
        }

        function enable(): void {
            root.setEnabled(true);
        }

        function disable(): void {
            root.setEnabled(false);
        }

        function getMode(): string {
            return props.mode;
        }

        // mode: off | noSleep | noLock
        function setMode(mode: string): string {
            if (!root.modes.includes(mode))
                return `Invalid mode "${mode}", expected one of: ${root.modes.join(", ")}`;
            props.mode = mode;
            return props.mode;
        }

        // Cycles off -> noSleep -> noLock -> off
        function cycle(): string {
            props.mode = root.modes[(root.modes.indexOf(props.mode) + 1) % root.modes.length];
            return props.mode;
        }

        target: "idleInhibitor"
    }
}
