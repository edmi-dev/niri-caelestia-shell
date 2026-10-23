pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// NIRI-PORT(F17): port-only service — the user's TLP profile switcher `power-switch` (nixos-config input
// power-switch) replaces power-profiles-daemon on the laptop. Talks only to its CLI:
// `power-switch list` prints one profile per line ("▸ name: label" for the current one, "  name: label"
// otherwise), `power-switch <name>` applies a profile. Available only when the CLI answers and the
// machine has a laptop battery, so desktops keep the upstream PowerProfiles switch.
Singleton {
    id: root

    // Low to high power; profiles the switcher reports but this map does not know go last
    readonly property var knownIcons: ({
            supersave: "energy_savings_leaf",
            powersave: "eco",
            balanced: "balance",
            stationary: "power"
        })

    property list<var> profiles: [] // [{ name, label, icon }]
    property string current
    readonly property bool available: profiles.length > 0 && UPower.displayDevice.isLaptopBattery
    readonly property bool busy: apply.running
    readonly property var currentProfile: profiles.find(p => p.name === current) ?? null

    function refresh(): void {
        list.running = true;
    }

    function set(name: string): void {
        if (apply.running || !profiles.some(p => p.name === name))
            return;
        current = name; // Optimistic, corrected by the refresh after apply
        apply.command = ["power-switch", name];
        apply.running = true;
    }

    function parse(text: string): void {
        const names = Object.keys(knownIcons);
        const found = [];
        let cur = "";
        for (const line of text.split("\n")) {
            const m = line.match(/^\s*(▸)?\s*([\w.-]+):\s*(.*)$/);
            if (!m)
                continue;
            found.push({
                name: m[2],
                label: m[3].trim(),
                icon: knownIcons[m[2]] ?? "tune"
            });
            if (m[1])
                cur = m[2];
        }
        const rank = n => names.includes(n) ? names.indexOf(n) : names.length;
        found.sort((a, b) => rank(a.name) - rank(b.name));
        profiles = found;
        current = cur;
    }

    Component.onCompleted: refresh()

    Process {
        id: list

        command: ["sh", "-c", "command -v power-switch >/dev/null && exec power-switch list"] // Silent where it is not installed
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Process {
        id: apply

        onExited: root.refresh()
    }

    IpcHandler {
        function get(): string {
            return root.current;
        }

        function set(name: string): void {
            root.set(name);
        }

        function list(): string {
            return root.profiles.map(p => p.name).join("\n");
        }

        target: "powerSwitch"
    }
}
