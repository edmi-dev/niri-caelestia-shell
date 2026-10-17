# Контракт `services/Compositor.qml`

Единственный QML-файл, который знает про `NiriIpc` (модуль `Caelestia.Niri`). Весь остальной QML обращается только к `Compositor.*`.
Таблица построена в S4 по `rg -n '\bHypr\.|Hyprland\.|HyprlandMonitor|HyprlandToplevel|HyprlandWorkspace|Quickshell.Hyprland|GlobalShortcut' -g '*.qml'` (upstream a3a8fe59, 115 строк, 28 файлов).

Принцип: имена и семантика повторяют `Hypr.*`, где это возможно, чтобы правка места вызова сводилась к `Hypr.` → `Compositor.`.
Объекты — «сырые» JSON niri (`NiriIpc` отдаёт их как есть), а не `Hyprland*`-типы: `lastIpcObject.class` → `app_id`, `.workspace.id` → `workspace_id`, `.lastIpcObject.floating` → `is_floating`, `address` → `id`.

## Возможности (`Compositor.supports`)

| Флаг | Значение | Основание |
|---|---|---|
| `specialWorkspaces` | false | в niri нет спецворкспейсов (Q2) |
| `focusGrab` | false | нет протокола hyprland-focus-grab |
| `globalShortcuts` | false | нет протокола global-shortcuts; бинды через IPC |
| `runtimeOptions` | false | нет runtime-опций; только KDL + include |
| `windowTags` | false | в niri нет тегов окон (Q7) |
| `windowPin` | false | в niri нет «pin» (в `niri msg action --help` действия нет) |
| `cursorPos` | false | нет позиции курсора в IPC |
| `fullscreenFlag` | true (эвристика) | Q3(a): `window_size` == логический размер выхода; windowed fullscreen не виден |
| `toplevelCapture` | false до Q9 | проверить (Q9) |

## Свойства / функции / сигналы

Типы: `Workspace` = `{id, idx, name, output, is_active, is_focused, is_urgent, active_window_id}`;
`Window` = `{id, title, app_id, pid, workspace_id, is_focused, is_floating, is_urgent, layout{…}}` (фикстура `windows`).

| Член | Тип | Источник `NiriIpc` | Заменяет |
|---|---|---|---|
| `available` | bool | `available` | — |
| `supports` | object | константа (таблица выше) | — |
| `workspaces` | list\<Workspace\> | `workspaces` | `Hypr.workspaces.values` |
| `windows` | list\<Window\> | `windows` | `Hypr.toplevels.values` |
| `outputs` | map name→output | `outputs` | `Hypr.monitors` |
| `focusedMonitor` | string (имя выхода) | `focusedMonitorName` | `Hypr.focusedMonitor` (объект → имя) |
| `focusedWorkspace` | Workspace\|null | `workspaces` ∩ `focusedWorkspaceId` | `Hypr.focusedWorkspace` |
| `activeWsId` | int | `focusedWorkspace.idx` (позиция на выходе, 1-based) | `Hypr.activeWsId` |
| `activeToplevel` | Window\|null | `focusedWindow` (пустой map → null) | `Hypr.activeToplevel` |
| `inOverview` | bool | `inOverview` | — (niri) |
| `capsLock`, `numLock` | bool | `capsLock`, `numLock` (sysfs LED) | `Hypr.capsLock/numLock` |
| `kbLayouts` | list\<string\> | `kbLayoutsArray` | — |
| `kbLayoutIndex` | int | `kbLayoutIndex` | — |
| `kbLayoutFull` | string | `kbLayoutsArray[kbLayoutIndex]` | `Hypr.kbLayoutFull` |
| `kbLayout` | string | `kbMap` по `kbLayoutFull` (разбор xkb `base.lst`, как в upstream) | `Hypr.kbLayout` |
| `defaultKbLayout` | string | `kbMap` по `kbLayoutsArray[0]` | `Hypr.defaultKbLayout` |
| `fullscreenOutputs` | list\<string\> | `fullscreenOutputs` | — |
| signal `configReloaded(bool failed)` | | `configLoaded(failed)`; приходит и при переподключении | `Hypr.configReloaded` |
| `monitorFor(screen)` | string | `screen.name` | `Hypr.monitorFor` (сравнение `=== focusedMonitor` сохраняет смысл) |
| `workspacesFor(output)` | list\<Workspace\> | фильтр `workspaces` по `output`, сортировка по `idx` | `Hypr.workspaces.filter(w.monitor===…)` |
| `activeWorkspaceFor(output)` | Workspace\|null | `is_active && output===…` | `monitor.activeWorkspace` |
| `toplevelsForWs(wsId)` | list\<Window\> | `getWindowsByWorkspaceId` | `Hypr.toplevelsForWs` (теги игнорируются, Q7) |
| `isWindowFullscreen(winId)` | bool | `isWindowFullscreen(id)` (эвристика Q3; зависимость от `fullscreenOutputs`/`windows`) | `lastIpcObject.fullscreen` (U49) |
| `workspaceById(wsId)` | Workspace\|null | поиск в `workspaces` | `client.workspace` (U49) |
| `hasFullscreen(output?)` | bool | `hasFullscreen(output)`; без аргумента — `fullscreenOutputs.length>0` | разные `lastIpcObject.fullscreen > 1` |
| `outputRefresh(output?)` | int | частота текущего режима выхода в Гц (`modes[current_mode].refresh_rate` / 1000); без аргумента — максимум по выходам; 0 — неизвестно | `monitors[].refreshRate` (было в caelestia-cli) |
| `focusWorkspace(idx)` | void | `action("focus-workspace", [idx])` (Index на сфокусированном выходе) | `Hypr.focusWorkspace` |
| `focusWorkspaceId(id)` | void | `action("focus-workspace", ["--id", id])` (Id-ссылка) | — |
| `focusWorkspaceRelative(delta)` | void | `focus-workspace-up` / `focus-workspace-down` | `workspace r±1` |
| `moveWindowToWorkspace(winId, wsId, follow)` | void | `MoveWindowToWorkspace{window_id, reference:{Id}, focus}` | `movetoworkspace N,address:` |
| `toggleWindowFloating(winId)` | void | `toggle-window-floating --id` | `togglefloating address:` |
| `closeWindow(winId)` | void | `close-window --id` | `killwindow address:` |
| `focusWindow(winId)` | void | `focus-window --id` | — |
| `setDpms(on)` | void | `power-on-monitors` / `power-off-monitors` | `dpms on/off` |
| `switchKbLayout(idx)` | void | `SwitchLayout{layout:{Index:idx}}` | `hyprctl switchxkblayout` (U28) |
| `reloadConfig()` | void | `load-config-file` | `Hypr.extras.message("reload")` |

Аргументы действий сверены с `niri msg action <name> --help` (niri 26.04): `focus-workspace <REFERENCE>`, `move-window-to-workspace [--window-id] [--focus] <REFERENCE>`, `toggle-window-floating [--id]`, `close-window [--id]`, `focus-window --id`, `power-on-monitors`, `power-off-monitors`, `switch-layout <LAYOUT>`, `load-config-file [--path]`.

Формы вызова `NiriIpc.action` (S4-cpp, JSON сверен с `niri-ipc/src/lib.rs` 26.4.0, тесты `actionPayload`):
`action("move-window-to-workspace", ["--window-id", W, "--id", WS, "--focus", follow])` → `{window_id:W, reference:{Id:WS}, focus}`;
`action("switch-layout", [N])` → `{layout:{Index:N}}`, `["next"|"prev"]` → `{layout:"Next"|"Prev"}`.

Поведение overview: при открытии niri шлёт `WindowFocusChanged{id:null}` (фикстура `overview`) → `activeToplevel` = null на время overview. Upstream делает то же для пустого воркспейса, UI это переживает.

## Таблица мест вызова: upstream `Hypr.*` → `Compositor.*` → niri IPC

«—» в колонке Compositor = функциональность отключается по `supports.*`.

| Вызов upstream | Файл:строка | Compositor | niri action / event | ID |
|---|---|---|---|---|
| `Hypr.extras.applyOptions({...})` | services/GameMode.qml:17 | — (`supports.runtimeOptions`) | include-файл KDL + `load-config-file` (Q15) | U47 |
| `Hypr.extras.message("reload")` | services/GameMode.qml:35 | `reloadConfig()` | `LoadConfigFile` | U47 |
| `Hypr.options["animations:enabled"]` | services/GameMode.qml:44 | — | состояние из наличия include-файла (Q15) | U47 |
| `Hypr.monitors.values` + `fullscreen > 1` | services/Notifs.qml:26 | `hasFullscreen()` | `fullscreenOutputs` (эвристика Q3) | U42 |
| `Hypr.focusedMonitor` + special ws + `fullscreen > 1` | services/NotifData.qml:57-60 | `hasFullscreen(focusedMonitor)` | эвристика Q3; спец-ветка удаляется | U42 |
| `Hypr.focusedMonitor`, `Hypr.monitorFor(s)` | services/ShellState.qml:24-26 | `focusedMonitor`, `monitorFor(s)` | `WorkspaceActivated` / `WorkspacesChanged` (`is_focused`) | U20 |
| `Hypr.focusedMonitor`, `Hypr.monitorFor(c)` | services/ShellState.qml:39-41 | `focusedMonitor`, `monitorFor(c)` | то же | U20 |
| `Hypr.usingLua`, `Hypr.extras.batchMessage(layerrule…)` | services/Colours.qml:87-94 | — (`supports.runtimeOptions`) | статичный `layer-rule` в KDL | U53 |
| `Hypr.monitorFor(m).focused` | services/Brightness.qml:29 | `monitorFor(m) === focusedMonitor` | `is_focused` воркспейса | U55 |
| `Hypr.monitorFor(m).id === id` | services/Brightness.qml:44 | `monitorFor(m) === id` (id → имя выхода) | `Outputs` | U55 |
| `import Quickshell.Hyprland` + `GlobalShortcut` | components/misc/CustomShortcut.qml:1-4 | — (`supports.globalShortcuts`) | файл удаляется; `IpcHandler` + бинд в KDL | U18 |
| `HyprlandToplevel client` | modules/windowinfo/Details.qml:3,12 | `property var client` (Window) | `Windows` | U49 |
| `HyprlandToplevel client` | modules/windowinfo/Preview.qml:6,17 | `property var client`; превью по Q9 | `supports.toplevelCapture` | U49 |
| `Hypr.activeWsId` (сетка 10 ws) | modules/windowinfo/Buttons.qml:95 | `workspacesFor(monitorFor(screen))` | `Workspaces` | U49 |
| `movetoworkspace N,address:` | modules/windowinfo/Buttons.qml:99 | `moveWindowToWorkspace(client.id, ws.id, true)` | `MoveWindowToWorkspace` | U49 |
| `togglefloating address:` | modules/windowinfo/Buttons.qml:122 | `toggleWindowFloating(client.id)` | `ToggleWindowFloating` | U49 |
| `pin address:` | modules/windowinfo/Buttons.qml:136 | — (`supports.windowPin`) | нет | U49 |
| `killwindow address:` | modules/windowinfo/Buttons.qml:144 | `closeWindow(client.id)` | `CloseWindow` | U49 |
| `HyprlandToplevel client` | modules/windowinfo/WindowInfo.qml:4,13 | `property var client` | `Windows` | U49 |
| `Hypr.focusedWorkspace…fullscreen > 1` | modules/Shortcuts.qml:13 | `hasFullscreen(focusedMonitor)` | эвристика Q3 | U51 |
| `HyprlandMonitor monitor: Hypr.monitorFor(screen)` | modules/drawers/ContentWindow.qml:7,24 | `property string monitor: monitorFor(screen)` | — | U21 |
| `hasSpecialWorkspace`, special ws lookup | modules/drawers/ContentWindow.qml:25-32 | — (`supports.specialWorkspaces` → false) | нет | U21 |
| `hasFullscreenOnNormalWs` | modules/drawers/ContentWindow.qml:26 | `hasFullscreen(monitor)` | эвристика Q3, `fullscreenChanged` | U21 |
| `monitorFor(screen).activeWorkspace.toplevels.every(floating)` | modules/background/Visualiser.qml:18 | `toplevelsForWs(activeWorkspaceFor(monitorFor(screen))?.id).every(w => w.is_floating)` | `is_floating` | U52 |
| `Hypr.kbLayout/defaultKbLayout/capsLock/numLock/kbLayoutFull` | modules/lock/center/StateMessage.qml:72-90 | одноимённые свойства | `KeyboardLayoutSwitched`, sysfs LED | U39 |
| `Hypr.monitorFor(screen)` + special ws | modules/bar/Bar.qml:82-85 | — (ветка удаляется, Q2) | нет | U23 |
| `workspace r±1` | modules/bar/Bar.qml:87 | `focusWorkspaceRelative(±1)` | `FocusWorkspaceUp/Down` | U23 |
| `dpms off/on` / прочий `action` | modules/IdleMonitors.qml:35 | `setDpms(on)`; прочие команды — UNVERIFIED (смотреть конфиг idle) | `PowerOffMonitors` / `PowerOnMonitors` | U56 |
| `Hypr.capsLock/numLock` | modules/bar/components/StatusIcons.qml:39 | одноимённые | sysfs LED | U27 |
| `Hypr.kbLayout` | modules/bar/components/StatusIcons.qml:113 | `kbLayout` | `KeyboardLayoutSwitched` | U27 |
| `Hypr.capsLock/numLock` | modules/bar/components/status/LockStatus.qml:12-75 | одноимённые | sysfs LED | U27 |
| `Hypr.capsLock/numLock` | modules/bar/popouts/LockStatus.qml:11,15 | одноимённые | sysfs LED | U27 |
| `Hypr.options["general:border_size"]`, `["decoration:rounding"]` | modules/areapicker/Picker.qml:21-22 | — (`supports.runtimeOptions`); константы/Config | нет | U62 |
| `Hypr.monitorFor(screen)` → активный ws | modules/areapicker/Picker.qml:38 | `activeWorkspaceFor(monitorFor(screen))` | `Workspaces` | U62 |
| `Hypr.toplevelsForWs(wsId)` + геометрия | modules/areapicker/Picker.qml:47 | `toplevelsForWs(id)`; геометрия — UNVERIFIED (`tile_pos_in_workspace_view` = null во вложенной сессии) | `WindowLayoutsChanged` | U62 |
| `Hypr.extras.refreshOptions()` | modules/areapicker/Picker.qml:104 | — | нет | U62 |
| `SpecialWorkspaces` целиком | modules/bar/components/workspaces/SpecialWorkspaces.qml:5-230 | — (`supports.specialWorkspaces`; Q2) | нет | U25 |
| `Hypr.activeToplevel?.title`, `.lastIpcObject.class` | modules/bar/components/ActiveWindow.qml:18,74 | `activeToplevel?.title`, `?.app_id` | `WindowFocusChanged` | U26 |
| `Hypr.activeToplevel` (+`.class`, `.title`) | modules/bar/popouts/ActiveWindow.qml:15-55 | `activeToplevel`, `.app_id`, `.title` | `WindowFocusChanged` | U26 |
| `Hypr.activeToplevel?.wayland` (ScreencopyView) | modules/bar/popouts/ActiveWindow.qml:92 | Q9 (`supports.toplevelCapture`) | — | U26 |
| `HyprlandMonitor monitor: Hypr.monitorFor(screen)` | modules/bar/components/workspaces/Workspaces.qml:6,19 | `property string monitor` | — | U24 |
| фильтр `Hypr.workspaces` по монитору + `isToplevelIgnored` | modules/bar/components/workspaces/Workspaces.qml:33 | `workspacesFor(monitor)` (+ `perMonitor` — Q5; теги — Q7) | `WorkspacesChanged` | U24 |
| `focusWorkspace(ws)` / `toggleSpecial("special")` | modules/bar/components/workspaces/Workspaces.qml:178-181 | `focusWorkspace(idx)` / — | `FocusWorkspace{Index}` | U24 |
| `HyprlandMonitor monitor` | modules/bar/components/workspaces/Workspace.qml:6,21 | `property string monitor` | — | U24 |
| `list<HyprlandToplevel> toplevels: toplevelsForWs(ws, ignoredTags)` | modules/bar/components/workspaces/Workspace.qml:30 | `property var toplevels: toplevelsForWs(id)` | `Windows*` | U24 |
| `Hypr.workspaces.find(id).monitor` | modules/bar/components/workspaces/Workspace.qml:40 | `.output` | — | U24 |
| `trimWsName`, `ws.name` | modules/bar/components/workspaces/Workspace.qml:131-132,254 | `name ?? idx` (имя воркспейса niri, без `special:`) | — | U24 |
| `HyprlandWorkspace wsObj` | modules/bar/components/workspaces/Workspace.qml:255 | `property var wsObj` | — | U24 |
| `Hypr.activeToplevel` → `client` | modules/bar/popouts/Wrapper.qml:5,126 | `activeToplevel` | — | U29 |

Не переносится из `services/Hypr.qml`: `dispatch()`, `usingLua`, `extras`/`options`/`devices`, `toggleSpecial`, `cycleSpecialWorkspace`,
`lastSpecialWorkspace`, `reloadDynamicConfs` (бинды Caps/Num не нужны — LED читаются из sysfs), `IpcHandler{target:"hypr"}`, `CustomShortcut "refreshDevices"`.

## IPC (`IpcHandler`-цели, замена `CustomShortcut`)

Вызов: `caelestia-shell ipc call <target> <function> [args]`. Пример биндов — `nix/niri/caelestia.kdl` (`niri validate` OK).
Бинды на отпускание в niri 26.04 отсутствуют (`niri-config/src/binds.rs`: у `Bind` нет release-триггера).

| Бывший `CustomShortcut` | Файл | IPC target → функция |
|---|---|---|
| `nexus` | modules/Shortcuts.qml | `nexus open` |
| `showall` | modules/Shortcuts.qml | `drawers showAll` (новая, NIRI-PORT U18) |
| `dashboard`, `session`, `launcher`, `sidebar`, `utilities` | modules/Shortcuts.qml | `drawers toggle <name>` |
| `launcherInterrupt` | modules/Shortcuts.qml | — (нет release-биндов; launcher по нажатию) |
| `lock`, `unlock` | modules/lock/Lock.qml | `lock lock`, `lock unlock` |
| `screenshot`, `screenshotFreeze`, `screenshotClip`, `screenshotFreezeClip` | modules/areapicker/AreaPicker.qml | `picker open`, `openFreeze`, `openClip`, `openFreezeClip` |
| `mediaToggle`, `mediaPrev`, `mediaNext`, `mediaStop` | services/Players.qml | `mpris playPause`, `previous`, `next`, `stop` |
| `brightnessUp`, `brightnessDown` | services/Brightness.qml | `brightness increase`, `decrease` (новые, шаг из конфига) |
| `clearNotifs` | services/Notifs.qml | `notifs clear` |
| `refreshDevices` (Hypr.qml) | — | не нужен: Caps/Num из sysfs LED |

Отличие от upstream: шорткаты `sidebar`/`utilities` не срабатывали при фуллскрине, а `drawers toggle` блокирует только `launcher`/`session`/`dashboard`.
