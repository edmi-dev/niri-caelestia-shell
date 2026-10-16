pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n
import Caelestia.Niri

// NIRI-PORT(S4): compositor facade, the only QML file that talks to NiriIpc.
// Contract: docs/port/COMPOSITOR_API.md. Workspaces and windows are raw niri JSON objects.
Singleton {
    id: root

    readonly property bool available: NiriIpc.available

    // Features that niri does not have; callers disable the matching UI instead of emulating it
    readonly property var supports: ({
            specialWorkspaces: false,
            focusGrab: false,
            globalShortcuts: false,
            runtimeOptions: false,
            windowTags: false,
            windowPin: false,
            cursorPos: false,
            // Heuristic (Q3 = a): window size equals the output's logical size; windowed fullscreen is invisible
            fullscreenFlag: true,
            // UNVERIFIED (Q9): toplevel capture via ScreencopyView on niri
            toplevelCapture: false
        })

    // Workspace: {id, idx, name, output, is_active, is_focused, is_urgent, active_window_id}
    readonly property var workspaces: NiriIpc.workspaces
    // Window: {id, title, app_id, pid, workspace_id, is_focused, is_floating, is_urgent, layout}
    readonly property var windows: NiriIpc.windows
    // Output name -> niri output object
    readonly property var outputs: NiriIpc.outputs

    readonly property string focusedMonitor: NiriIpc.focusedMonitorName
    readonly property var focusedWorkspace: workspaces.find(w => w.id === NiriIpc.focusedWorkspaceId) ?? null
    // Position of the focused workspace on its output (1-based), like the bar's workspace numbers
    readonly property int activeWsId: focusedWorkspace?.idx ?? 1
    // null while nothing is focused, including while the overview is open (niri sends WindowFocusChanged{id: null})
    readonly property var activeToplevel: NiriIpc.focusedWindow.id !== undefined ? NiriIpc.focusedWindow : null
    readonly property bool inOverview: NiriIpc.inOverview

    readonly property list<string> fullscreenOutputs: NiriIpc.fullscreenOutputs

    // Caps/Num lock come from /sys/class/leds (niri IPC does not expose them)
    readonly property bool capsLock: NiriIpc.capsLock
    readonly property bool numLock: NiriIpc.numLock
    readonly property var kbLayouts: NiriIpc.kbLayoutsArray
    readonly property int kbLayoutIndex: NiriIpc.kbLayoutIndex
    readonly property string kbLayoutFull: kbLayouts[kbLayoutIndex] ?? Tr.trCtx("Unknown", "keyboard layout")
    readonly property string kbLayout: kbCode(kbLayoutFull)
    readonly property string defaultKbLayout: kbCode(kbLayouts[0] ?? "")
    readonly property var kbMap: new Map()
    property int kbMapRevision: 0

    // Sent on every config (re)load and once on each event-stream (re)connect, so handlers must be idempotent
    signal configReloaded(failed: bool)

    function monitorFor(screen: ShellScreen): string {
        return screen?.name ?? "";
    }

    function workspacesFor(output: string): var {
        return workspaces.filter(w => w.output === output).sort((a, b) => a.idx - b.idx);
    }

    function activeWorkspaceFor(output: string): var {
        return workspaces.find(w => w.output === output && w.is_active) ?? null;
    }

    function toplevelsForWs(wsId: int): var {
        return windows.filter(w => w.workspace_id === wsId);
    }

    function hasFullscreen(output: string): bool {
        return output ? fullscreenOutputs.includes(output) : fullscreenOutputs.length > 0;
    }

    function isWindowFullscreen(windowId: int): bool {
        void fullscreenOutputs; // Re-evaluate bindings on fullscreen changes
        void windows;
        return NiriIpc.isWindowFullscreen(windowId);
    }

    function workspaceById(wsId: int): var {
        return workspaces.find(w => w.id === wsId) ?? null;
    }

    // Index on the focused output
    function focusWorkspace(idx: int): void {
        NiriIpc.action("focus-workspace", [idx]);
    }

    function focusWorkspaceId(id: int): void {
        NiriIpc.action("focus-workspace", ["--id", id]);
    }

    function focusWorkspaceRelative(delta: int): void {
        NiriIpc.action(delta < 0 ? "focus-workspace-up" : "focus-workspace-down");
    }

    function moveWindowToWorkspace(windowId: int, wsId: int, follow: bool): void {
        NiriIpc.action("move-window-to-workspace", ["--window-id", windowId, "--id", wsId, "--focus", follow]);
    }

    function toggleWindowFloating(windowId: int): void {
        NiriIpc.action("toggle-window-floating", ["--id", windowId]);
    }

    function closeWindow(windowId: int): void {
        NiriIpc.action("close-window", ["--id", windowId]);
    }

    function focusWindow(windowId: int): void {
        NiriIpc.action("focus-window", ["--id", windowId]);
    }

    function setDpms(on: bool): void {
        NiriIpc.action(on ? "power-on-monitors" : "power-off-monitors");
    }

    // Index into kbLayouts, or "next"/"prev"
    function switchKbLayout(target: var): void {
        NiriIpc.action("switch-layout", [target]);
    }

    function reloadConfig(): void {
        NiriIpc.action("load-config-file");
    }

    // Full xkb layout name ("English (US)") -> short code ("us"), falls back to the first two letters
    function kbCode(name: string): string {
        void kbMapRevision; // Re-evaluate bindings once base.lst is parsed
        return kbMap.get(name) ?? (name.length >= 2 ? name.slice(0, 2).toLowerCase() : "??");
    }

    Connections {
        function onConfigLoaded(failed: bool): void {
            root.configReloaded(failed);
        }

        target: NiriIpc
    }

    FileView {
        id: kbLayoutFile

        path: Quickshell.env("CAELESTIA_XKB_RULES_PATH") || "/usr/share/X11/xkb/rules/base.lst"
        onLoaded: {
            const layoutMatch = text().match(/! layout\n([\s\S]*?)\n\n/);
            if (layoutMatch) {
                const lines = layoutMatch[1].split("\n");
                for (const line of lines) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;

                    const match = line.match(/^\s*([a-z]{2,})\s+([a-zA-Z() ]+)$/);
                    if (match)
                        root.kbMap.set(match[2], match[1]);
                }
            }

            const variantMatch = text().match(/! variant\n([\s\S]*?)\n\n/);
            if (variantMatch) {
                const lines = variantMatch[1].split("\n");
                for (const line of lines) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;

                    const match = line.match(/^\s*([a-zA-Z0-9_-]+)\s+([a-z]{2,}): (.+)$/);
                    if (match)
                        root.kbMap.set(match[3], match[2]);
                }
            }
            root.kbMapRevision++;
        }
    }
}
