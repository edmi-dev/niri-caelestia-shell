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
// NIRI-PORT(F19): `power-switch idle` gives the current profile's idle timeouts ("lock=N dpms=N sleep=N",
// seconds, 0 = never; empty when the profile has none). IdleMonitors uses them instead of the shell.json
// timeouts, so the shell is the only idle manager and keep awake still overrides them.
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
    property var idle: null // { lock, dpms, sleep } in seconds, null when the profile sets none
    // Same shape as GlobalConfig.general.idle.timeouts; null keeps the shell.json timeouts
    readonly property var idleTimeouts: {
        if (!available || !idle)
            return null;
        const t = [];
        if (idle.lock > 0)
            t.push({
                timeout: idle.lock,
                idleAction: "lock"
            });
        if (idle.dpms > 0)
            t.push({
                timeout: idle.dpms,
                idleAction: "dpms off",
                returnAction: "dpms on"
            });
        if (idle.sleep > 0)
            t.push({
                timeout: idle.sleep,
                idleAction: ["suspend"]
            });
        return t;
    }

    function refresh(): void {
        list.running = true;
        idleProc.running = true;
    }

    function parseIdle(text: string): void {
        const t = {};
        for (const m of text.matchAll(/(lock|dpms|sleep)=(\d+)/g))
            t[m[1]] = parseInt(m[2]);
        idle = Object.keys(t).length > 0 ? {
            lock: t.lock ?? 0,
            dpms: t.dpms ?? 0,
            sleep: t.sleep ?? 0
        } : null;
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

    Process {
        id: idleProc

        command: ["sh", "-c", "command -v power-switch >/dev/null && exec power-switch idle"]
        stdout: StdioCollector {
            onStreamFinished: root.parseIdle(text)
        }
    }

    // NIRI-PORT(F19): profile switched from the CLI or a keybind. power-tlp-apply replaces the file by rename;
    // UNVERIFIED that FileView keeps watching after that (see DECISIONS.md F19), the popout still refreshes on open
    FileView {
        path: "/var/lib/power-profiles/current"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            root.refresh();
        }
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
