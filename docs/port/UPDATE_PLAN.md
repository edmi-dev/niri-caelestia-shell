# План обновления форка `output/` (niri) до upstream `shell-main/`

> **Статус документа (для агента).** Принято решение Q1 = «переносить upstream на niri» (ветка `niri-v2` от `upstream/main`).
> Этот файл — **справочник**: таблица соответствий Hyprland → niri (раздел 2.2), ID изменений с файлами и строками (раздел 3), открытые вопросы (раздел 5).
> Раздел 4 («График обновления») **заменён** шагами S0–S11 из `docs/port/PORT_AGENT_PROMPT.md`; при расхождении верен промпт.
> Пути `UP/…` = корень ветки `niri-v2`; пути `FK/…` = ветка `fork-legacy` (читать через `git show fork-legacy:<path>`).

> Документ — только анализ и план. Код не изменялся.
> Все пути даны относительно корней `shell-main/` (далее **UP**) и `output/` (далее **FK**).
> Сборка и запуск не выполнялись (нет niri/Quickshell в среде анализа): всё, что касается поведения в рантайме, помечено как «проверить».

---

## 1. Краткое резюме

**Что это за проекты.**
- **UP** — `caelestia-dots/shell`, Quickshell (QML) + C++-плагин `Caelestia.*` (Qt 6, CMake, Nix flake). Композитор — **Hyprland**, включая новый Lua-конфиг Hyprland (`Hyprland.usingLua`, см. `UP/services/Hypr.qml:17,47-53`).
- **FK** — «Niri-Caelestia Shell» (Ayushkr2003, форк форка jutraim). Тот же стек, композитор **niri**. В README форк помечен как архивный. Свой C++-клиент niri IPC: `FK/plugin/src/Caelestia/Internal/niriipc.{hpp,cpp}`, `nirisocket.{hpp,cpp}`, QML-фасад `FK/services/Niri.qml`.

**Точка расхождения.** Git-истории нет ни в одном архиве (`.git` отсутствует), коммит ответвления установить нельзя. Сравнение сделано по файлам и содержимому:

| Метрика | Значение |
|---|---|
| Файлов в UP / FK | 495 / 543 |
| Есть только в UP | **296** |
| Есть только в FK | **361** (из них ~150 — dotfiles, sddm-тема, setup и Python-бэкенды) |
| Общих файлов | 182, из них **побайтно совпадают только 11** |
| C++-файлов в UP / FK | 150 / 37 |

По содержимому форк отстаёт от одной крупной архитектурной итерации upstream, а не на «пару фич». Главные сдвиги в UP:
1. **Конфиг переехал из QML в C++**: `FK/config/*.qml` (`import qs.config`, 255 файлов) → `UP/plugin/src/Caelestia/Config` + `Settings` (`import Caelestia.Config`, `Config` / `GlobalConfig` / `Tokens`). Токены (`Tokens.*`, 1919 обращений) заменили `Appearance.*`. Изменение сквозное и затрагивает почти каждый QML-файл.
2. **I18n**: `qsTr` → `Tr.tr` (`Caelestia.I18n`, 865 вызовов).
3. **Новая модель экранов и окон**: `ShellState` / `ScreenState` / `Screens` вместо `visibilities`, единое окно `drawers/ContentWindow.qml` + `Regions.qml` с отрисовкой фона через SDF-шейдер `Caelestia.Blobs` вместо `drawers/Backgrounds.qml` + `Border.qml`.
4. **Новые модули**: `nexus` (новое приложение настроек; заменяет `controlcenter`), `sidebar` (центр уведомлений), `windowinfo`, лирика в медиа, карточки производительности на C++, запись экрана, GameMode, IdleMonitors.

**Инвентаризация**: 64 изменения upstream (раздел 3).

| Категория | Кол-во |
|---|---|
| A — не зависит от композитора | 38 |
| B — нужна адаптация под niri | 14 |
| C — уже перенесено (полностью или частично) | 7 |
| D — не переносится / неприменимо к niri | 5 |
| Доработки форка, которые нужно сохранить (F) | 15 |

**Общая оценка трудоёмкости:** **L+**, ориентировочно 30–45 человеко-дней для одного разработчика, знакомого с Quickshell. Оценка грубая: она не учитывает отладку на железе и решения по открытым вопросам.

**Ключевой вывод по стратегии.** Перенос «патчами в форк» нереалистичен: из-за переезда конфига и токенов почти каждый общий файл конфликтует целиком. Рекомендуется **обратная схема: новая ветка от UP → замена слоя Hyprland на слой niri из FK → перенос доработок форка поверх**. График в разделе 4 построен под эту схему. Окончательное решение остаётся за человеком (вопрос Q1).

---

## 2. Архитектурная карта

### 2.1. Где проходит граница с композитором

**UP (Hyprland):**

| Уровень | Файлы |
|---|---|
| C++ | `UP/plugin/src/Caelestia/Services/hyprextras.{hpp,cpp}` (сокеты `.socket.sock`/`.socket2.sock`: `message`, `batchMessage`, `applyOptions`, `refreshOptions`), `hyprdevices.{hpp,cpp}` (клавиатуры: `layout`, `activeKeymap`, `capsLock`, `numLock`) |
| QML-фасад | `UP/services/Hypr.qml` — обёртка над `Quickshell.Hyprland` (`toplevels`, `workspaces`, `monitors`, `dispatch`, `focusWorkspace` :47, `toggleSpecial` :51, `cycleSpecialWorkspace` :55, `monitorFor` :92, `toplevelsForWs` :100, `reloadDynamicConfs` :112, обработчик `rawEvent` :123–147, `IpcHandler target:"hypr"` :195, `HyprExtras` :220) |
| Прямые типы и вызовы | `HyprlandFocusGrab` (`drawers/ContentWindow.qml:112`, `bar/popouts/Wrapper.qml:93`), `GlobalShortcut` (`components/misc/CustomShortcut.qml`), `hyprctl` (`bar/popouts/kblayout/KbLayoutModel.qml:31`, `areapicker/Picker.qml:205`), `HyprlandMonitor`/`HyprlandToplevel`/`HyprlandWorkspace` в сигнатурах |
| Внешний CLI | `caelestia` CLI: `scheme`, `wallpaper`, `record` (`services/Colours.qml:82`, `services/Wallpapers.qml:33-117`, `services/Recorder.qml:54-61`, `launcher/services/Schemes.qml`, `M3Variants.qml:83`) |

Hyprland-зависимые QML-файлы UP (29 шт., плюс 4 C++-файла выше): `services/{Hypr,GameMode,Colours,Brightness,Notifs,NotifData,ShellState}.qml`, `modules/{Shortcuts,IdleMonitors}.qml`, `drawers/ContentWindow.qml`, `bar/Bar.qml`, `bar/components/{ActiveWindow,StatusIcons}.qml`, `bar/components/status/LockStatus.qml`, `bar/components/workspaces/{Workspaces,Workspace,SpecialWorkspaces}.qml`, `bar/popouts/{ActiveWindow,LockStatus,Wrapper}.qml`, `bar/popouts/kblayout/KbLayoutModel.qml`, `areapicker/Picker.qml`, `background/Visualiser.qml`, `lock/center/StateMessage.qml`, `windowinfo/{WindowInfo,Preview,Details,Buttons}.qml`, `components/misc/CustomShortcut.qml`.

**FK (niri):**

| Уровень | Файлы |
|---|---|
| C++ | `FK/plugin/src/Caelestia/Internal/nirisocket.cpp` (`$NIRI_SOCKET`, :14; event-stream + request-сокет), `niriipc.cpp` (811 строк): начальный снимок `Workspaces`/`Windows`/`FocusedWindow`/`Outputs`/`KeyboardLayouts` (:370–420), события `WorkspacesChanged`, `WorkspaceActivated`, `WindowsChanged`, `WindowOpenedOrChanged`, `WindowClosed`, `WindowFocusChanged`, `WindowLayoutsChanged`, `KeyboardLayoutsChanged`, `OverviewOpenedOrClosed`, `OutputsChanged` (:294–356), `action(name,args)` с JSON-сериализацией (:150–240), LED-watcher для Caps/Num Lock |
| QML-фасад | `FK/services/Niri.qml` (503 строки): воркспейсы по выходам, окна, сортировка по `pos_in_scrolling_layout`, группировка, действия (`focusWindow`, `closeWindow`, `toggleWindowFloating`, `moveColumnToIndex`, `toggleOverview`, `toggleFullscreen`, `toggleWindowedFullscreen` …) |
| Фокус клавиатуры | Без focus-grab: `WlrLayershell.keyboardFocus: Exclusive/None` (`FK/modules/drawers/Drawers.qml:32`, `bar/popouts/Wrapper.qml:80`) |
| Горячие клавиши | Без `GlobalShortcut`: `IpcHandler` в `FK/modules/Shortcuts.qml` + бинды niri `spawn-sh "qs -c niri-caelestia-shell ipc call …"` (`FK/dotfiles/.config/niri/niri/caelestia.kdl:5-36`) |
| Цвета и обои | Без `caelestia` CLI: `FK/scripts/colors/*`, `FK/services/{Colours,Wallpapers,Schemes,M3Variants}.qml`, шаблон matugen `dotfiles/.config/matugen/templates/niri.kdl` → `~/.config/niri/colors.kdl` |

### 2.2. Таблица соответствия «механизм UP → аналог в niri»

| Механизм UP (Hyprland) | Где используется | Аналог в niri | Статус в FK |
|---|---|---|---|
| `Hyprland.workspaces` + `refreshWorkspaces` по `rawEvent` | `Hypr.qml`, workspaces/* | Запрос `Workspaces` + события `WorkspacesChanged`, `WorkspaceActivated` | Есть (`NiriIpc.workspaces`, `Niri.workspacesForOutput`) |
| `Hyprland.toplevels`, `toplevelsForWs(id)` | бар, areapicker, windowinfo | `Windows` + `WindowsChanged` / `WindowOpenedOrChanged` / `WindowClosed`; фильтр по `workspace_id` | Есть (`Niri.getWindowsByWorkspaceId`) |
| `Hyprland.monitorFor(screen)` / `HyprlandMonitor` | ContentWindow, Bar, ShellState, Brightness, Visualiser | Нет объекта монитора: сопоставление `ShellScreen.name` ↔ `output` у воркспейса / ключ в `Outputs` | Частично (`Niri.focusedMonitorName`, `workspacesForOutput(name)`) |
| `Hyprland.focusedMonitor` | ShellState.forActive, NotifData | Выход воркспейса с `is_focused: true` | Есть (`NiriIpc.focusedMonitorName`) |
| `Hyprland.activeToplevel` | бар ActiveWindow, popouts | `FocusedWindow` + `WindowFocusChanged` | Есть (`Niri.focusedWindow`) |
| `dispatch workspace N` / `hl.dsp.focus` | Workspaces.qml:179 | action `FocusWorkspace {reference: Id/Index/Name}` (`niri msg action focus-workspace`) | Есть (`focusWorkspaceById`, `switchToWorkspaceByNumber`) |
| `dispatch workspace r±1` (скролл бара) | Bar.qml:85-88 | `focus-workspace-up` / `focus-workspace-down` | Есть (`switchToWorkspaceUpDown`) |
| `movetoworkspace N,address:…` | windowinfo/Buttons.qml:99 | `MoveWindowToWorkspace {window_id, reference, focus}` | Есть (`NiriIpc.action`, ветка с id, `niriipc.cpp:153-165`) |
| Спецворкспейсы `special:*`, `togglespecialworkspace` | SpecialWorkspaces.qml, Hypr.cycleSpecialWorkspace, ContentWindow/NotifData | **Аналога нет** (в niri нет scratchpad и спецворкспейсов) | — |
| Фуллскрин: `lastIpcObject.fullscreen > 1` | ContentWindow:26-37, Notifs:24, NotifData:56, Shortcuts:13 | Явного флага в IPC niri, насколько известно, нет. **Проверить** на целевой версии niri (`niri msg --json windows`). FK обращается к `client.is_fullscreen` (`FK/modules/dashboard/NiriThing.qml:100`), но эмитит ли niri это поле, не подтверждено. Запасной вариант — сравнение `layout.window_size` с логическим размером выхода | Не реализовано |
| `HyprlandFocusGrab` (закрытие по клику вне) | ContentWindow:112, popouts/Wrapper:93 | Протокола нет; `WlrLayershell.keyboardFocus` + обработка клика вне области | Реализован обходной путь (Drawers.qml:32) |
| `GlobalShortcut` (hyprland-global-shortcuts) | CustomShortcut.qml, Shortcuts.qml, Hypr.qml:212 | Протокола нет; `IpcHandler` + бинд niri `spawn "qs" … "ipc" "call" …` | Реализовано |
| `HyprDevices.keyboards` (layout, capsLock, numLock) | Hypr.qml:26-33, StatusIcons, LockStatus, StateMessage | `KeyboardLayouts` + `KeyboardLayoutsChanged` и **`KeyboardLayoutSwitched`**; Caps/Num — через LED в sysfs | Частично: `KeyboardLayoutSwitched` в `niriipc.cpp` **не обрабатывается** (см. U27/Q8) |
| `hyprctl switchxkblayout all N` | KbLayoutModel.qml:31 | action `SwitchLayout {layout: Index(N) / Next / Prev}` (`niri msg action switch-layout`) | Нет |
| `hyprctl cursorpos` | areapicker/Picker.qml:205 | **Аналога нет** в IPC | В FK обходится без него |
| `Hypr.options` (`general:border_size`, `decoration:rounding`) | Picker.qml:20-21 | **Нет** чтения опций по IPC | В FK константы (`FK/modules/areapicker/Picker.qml:18`) |
| `HyprExtras.applyOptions` / `keyword …` в рантайме | GameMode.qml:16-27, Colours.qml:86-95 (layerrule blur/ignore_alpha) | **Нет** runtime-опций. Эмуляция: генерировать KDL-файл и подключать через `include` (FK уже использует `include`, `dotfiles/.config/niri/config.kdl`); niri перечитывает конфиг сам | Нет |
| `configreloaded` → `configReloaded` | Hypr.qml:127, GameMode | Событие `ConfigLoaded` | Не обрабатывается в `niriipc.cpp` |
| `dispatch dpms off/on` | IdleMonitors.qml:35 | `niri msg action power-off-monitors` (+ `power-on-monitors`: **проверить** наличие в версии) | Нет |
| Window tags (`ignoredTags`, `hide_in_bar`) | Hypr.isToplevelIgnored, barconfig.hpp | **Нет тегов** в niri; можно фильтровать по `app_id`/`title` regex | Нет |
| `ScreencopyView { captureSource: HyprlandToplevel.wayland }` | popouts/ActiveWindow.qml:89, windowinfo/Preview.qml:67 | Нужен `Toplevel` из `ToplevelManager` (wlr-foreign-toplevel), сопоставленный с окном niri по `app_id`+`title`; поддержку захвата отдельного окна в niri **проверить** | Нет |
| Logout | SessionManager (logind `Terminate`) | logind работает и на niri; альтернатива — `niri msg action quit --skip-confirmation` | FK: `config/SessionConfig.qml:12` → `niri msg action quit -s` |

---

## 3. Таблица изменений upstream

Сложность: S ≤ 0,5 дня, M ≈ 1–3 дня, L > 3 дней. Риск: Н/С/В.

### 3.1. Фундамент: сборка, C++, конфиг

| ID | Описание | Файлы (UP) | Кат. | Зависит от | Слож. | Риск | Примечание по niri |
|---|---|---|---|---|---|---|---|
| U01 | Перестройка CMake: pch, `qml_module`, `sensorslib.cmake`, новые подмодули, строгие `-W` флаги, версия в `caelestia-core` | `CMakeLists.txt`, `plugin/CMakeLists.txt`, `plugin/cmake/*`, `plugin/src/Caelestia/CMakeLists.txt` | A | — | M | С | Из `Services/CMakeLists.txt` исключить `hyprdevices.cpp`, `hyprextras.cpp` (U10) и добавить `Internal/niri*` из FK. Новая зависимость — lm_sensors |
| U02 | Nix: `m3shapes` и `qtimageformats` в quickshell, `lm_sensors`, `cmakeBuildType`, howdy, `shouldGenerate` в hm-module | `nix/default.nix`, `nix/hm-module.nix`, `flake.nix` | A | U01 | S | Н | Убрать `hyprland` из runtimeDeps (`default.nix:16,51`). Сохранить из FK `pythonEnv`, `ffmpeg`, `qtmultimedia`, `qt5compat`, `QML2_IMPORT_PATH` |
| U03 | Фреймворк настроек C++ (узлы, списки, схема, quarantine, атомарная запись, debounce) | `plugin/src/Caelestia/Settings/*` | A | U01 | L | С | — |
| U04 | Конфиг в C++ (`Config`, `GlobalConfig`, attached `Config` по экрану, `forScreen`), `Tokens` вместо `Appearance` | `plugin/src/Caelestia/Config/*` | A | U03 | L | **В** | Ломает схему `shell.json` (U04-миграция, Q4). В схему нужно добавить ключи форка: `bar.workspaces.{windowIconImage, groupIconsByApp, groupingRespectsLayout, focusedWindowBlob, windowRighClickContext, pagerActive, doubleClickToCenter, …}` (`FK/config/BarConfig.qml:74-93`), конфиги manga/novel/quicktoggles/extra. Убрать или скрыть Hyprland-ключи (`ignoredTags`, `specialWorkspaceIcons`, `showWindowsOnSpecialWorkspaces`) |
| U05 | I18n: `Tr.tr`/`trCtx`, правила множественного числа, `Units` | `plugin/src/Caelestia/I18n/*`, все QML | A | U01 | M | Н | — |
| U06 | C++-компоненты: `AnimatedRepeater`, `LazyListView`, `ButtonRow`, индикаторы, `SparklineItem`, `VisualiserBars`, `WavyLine` | `plugin/src/Caelestia/Components/*` | A | U01 | M | Н | `circularindicatormanager` уже есть в FK (`Internal/`), заменить версией UP |
| U07 | Модуль Images: caching provider, cacher, analyser | `plugin/src/Caelestia/Images/*` | C | U01 | S | Н | В FK аналоги лежат в `Internal/cachingimagemanager.*` и `imageanalyser.*` в корне плагина; заменить версией UP |
| U08 | `Models/appdb` | `plugin/src/Caelestia/Models/appdb.*` | C | U01 | S | Н | В FK `appdb.*` в корне плагина, используется `FK/modules/controlcenter/launcher/AppDb.qml` |
| U09 | `Caelestia.Blobs` — SDF-фигуры и шейдер (`blob.frag/vert`) | `plugin/src/Caelestia/Blobs/*` | A | U01 | L | С | Нужен `qtshadertools` при сборке. От композитора не зависит |
| U10 | `HyprExtras` / `HyprDevices` | `plugin/src/Caelestia/Services/hypr*.{hpp,cpp}` | **D** | — | — | — | Hyprland-сокеты. Замена — `FK/plugin/src/Caelestia/Internal/niriipc.*`, `nirisocket.*` (F01) |
| U11 | C++-сервисы мониторинга: cpu/gpu (sysfs drm + nvidia-smi)/memory/storage/diskinfo/networkusage/sensors/ticking | `plugin/src/Caelestia/Services/{cpu,gpu,memory,storage,diskinfo,networkusage,sensorslib,tickingservice}.*` | A | U01, U04 | M | С | Конфликтует с F12 (`FK/.../Services/sysmonitor.*`, `services/SysMonitorService.qml`, `SystemUsage.qml`, `NetworkUsage.qml`) — Q6 |
| U12 | `SessionManager` (logind D-Bus: logout/suspend/hibernate/…) | `Services/sessionmanager.*` | A | U01 | S | Н | logind `Terminate` для сессии niri работает; сохранить возможность `niri msg action quit -s` из `FK/config/SessionConfig.qml:12` |
| U13 | Сервис лирики (LRCLIB, NetEase) | `Services/lyrics.*`, `lyriccandidate.*` | A | U01, U04 | M | Н | — |
| U14 | Утилиты: `circularbuffer`, `ringbuffer`, `metaenum`, `i18n.hpp` | `plugin/src/Caelestia/circularbuffer.*`, `plugin/include/util/*` | A | U01 | S | Н | — |
| U15 | Обновления `cutils`, `qalculator`, `requests`, `toaster`, `audiocollector`, `cavaprovider`, `beattracker`, `service(ref)`, `filesystemmodel` | `plugin/src/Caelestia/*.cpp`, `Services/*`, `Models/filesystemmodel.*` | A | U01 | M | С | `qalculator.cpp`: UP 144 строки, FK 52; сверить API, на котором держится калькулятор лаунчера форка |

### 3.2. Каркас оболочки и компоненты

| ID | Описание | Файлы (UP) | Кат. | Зависит от | Слож. | Риск | Примечание по niri |
|---|---|---|---|---|---|---|---|
| U16 | Переписанные базовые компоненты под `Tokens` и типизированный `Anim` | `components/{Anim,CAnim,StateLayer,StyledText,MaterialIcon,…}.qml`, `components/controls/*`, `effects/*`, `filedialog/*`, `containers/*` | A | U04 | L | **В** | Компоненты форка (`Card`, `Chip`, `CollapsibleSection`, `SwitchRow`, `ToggleRow`, `Tooltip`, `CornerPiece`, `ElevationGlow`, `InnerBorder`, `behaviors/*` …) нужно перевести на `Tokens` |
| U17 | Новые компоненты: `AnchorAnim`, `AnimLoader`, `ScreenState`, `VerticalFade*`, `ButtonBase`, `LoadingIndicator`, `SearchBar`, `StyledProgressBar`, `StyledSpinBox`, `TextFieldBase`, `Mask`, `FadeImage`, `CoverArt`, `WavyTopRect` | `components/**` | A | U16 | M | Н | — |
| U18 | `CustomShortcut` (hyprland global shortcuts) | `components/misc/CustomShortcut.qml`, использование в `modules/Shortcuts.qml`, `services/Hypr.qml:212` | **B** | — | S | С | Протокола в niri нет → каждый `CustomShortcut` заменить на `IpcHandler` и бинд в `caelestia.kdl` (`spawn-sh "qs -c … ipc call <target> <fn>"`) |
| U19 | `shell.qml` + `ServiceLoader`, `GSFLoader` (Google Sans Flex), `BatteryMonitor`, `IdleMonitors` | `shell.qml`, `modules/{ServiceLoader,GSFLoader}.qml`, `assets/google-sans-flex/*` | A | U04 | S | С | Сохранить из FK `Backdrop`, `QuickTogglesPanel`, `PolkitDialog`, `ReloadPopup`. `ServiceLoader` грузит `GameMode` (U47) |
| U20 | `ShellState` / `Screens` / `ScreenState` вместо `visibilities` | `services/{ShellState,Screens}.qml`, `components/ScreenState.qml` | **B** | U04 | M | **В** | `forActive()` / `componentsForActive()` (`ShellState.qml:23-44`): `Hypr.monitorFor(s)===focusedMonitor` → `s.modelData.name === Niri.focusedMonitorName`. В `ScreenState` добавить флаги форка: `manga`, `novel`, `quicktoggles`, `editingWeatherLocation` (`FK/modules/drawers/Drawers.qml:32,108`) |
| U21 | Единое окно drawers: `ContentWindow` + `Regions` + Blobs, анимация скрытия рамки при фуллскрине | `modules/drawers/{ContentWindow,Regions,Drawers,Exclusions,Interactions,Panels}.qml` | **B** | U09, U20 | L | **В** | (1) `HyprlandMonitor monitor` (:24) → имя выхода; (2) `hasSpecialWorkspace` (:25) → всегда `false`; (3) `hasFullscreen` (:26-37) → детектор фуллскрина niri (Q3); (4) `HyprlandFocusGrab` (:112) → `WlrLayershell.keyboardFocus` + закрытие по клику вне (схема FK `Drawers.qml:32`). Удаляет `FK/modules/drawers/{Backgrounds,Border}.qml` и все `*/Background.qml` форка |
| U22 | Обновления `Exclusions`, `Interactions`, `Panels` | `modules/drawers/*` | A | U21 | M | С | Добавить панели форка (manga, novel, quicktoggles) |

### 3.3. Бар

| ID | Описание | Файлы (UP) | Кат. | Зависит от | Слож. | Риск | Примечание по niri |
|---|---|---|---|---|---|---|---|
| U23 | Бар: список `entries`, `statusIcons`, `handleWheel` | `modules/bar/{Bar,BarWrapper}.qml` | **B** | U04, U21 | M | С | Скролл по воркспейсам (`Bar.qml:80-88`): ветку спецворкспейсов убрать, `workspace r±1` → `Niri.switchToWorkspaceUpDown("up"/"down")` (`focus-workspace-up/down`) |
| U24 | Переписанные воркспейсы: `Workspaces`, `Workspace`, `ActiveIndicator` (trail), `OccupiedBg`, `GapMarkers`, иконки окон по правилам `windowIcons` | `modules/bar/components/workspaces/*` | **B** | U04, U06, F01 | L | **В** | `Hypr.workspaces.filter(w.monitor===…)` (`Workspaces.qml:33`) → `Niri.workspacesForOutput(screen.name)`; `perMonitor=false` в niri не имеет прямого смысла (воркспейсы всегда принадлежат выходу) — Q5. `toplevelsForWs` (`Workspace.qml:30`) → `Niri.getWindowsByWorkspaceId`; `focusWorkspace` (:179) → `Niri.focusWorkspaceById`; `ignoredTags` → тегов нет (Q7). Главный конфликт — с F02 (Pager, drag колонок, контекстные меню) |
| U25 | Спецворкспейсы: виджет, `cycleSpecialWorkspace`, IPC `hypr` | `bar/components/workspaces/SpecialWorkspaces.qml`, `services/Hypr.qml:55-86,195-208` | **D** | — | — | — | В niri нет спецворкспейсов и scratchpad. Не переносить (Q2 — эмулировать ли именованными воркспейсами) |
| U26 | Активное окно в баре и popout с живым превью | `bar/components/ActiveWindow.qml`, `bar/popouts/ActiveWindow.qml` | **B** | U24 | M | С | Заголовок и иконка из `Niri.focusedWindow` (`title`, `app_id`). Превью `ScreencopyView` (:89) требует `Toplevel` из `ToplevelManager`, сопоставленного по `app_id`+`title`; захват окна в niri **не проверен** (Q9). FK-версия бара: `FK/modules/bar/components/ActiveWindow.qml` |
| U27 | Статус-иконки как список + `status/{Battery,Bluetooth,Lock}Status.qml`, `LockStatus` popout | `bar/components/StatusIcons.qml`, `bar/components/status/*`, `bar/popouts/LockStatus.qml` | C | U04 | M | С | `Hypr.capsLock/numLock/kbLayout` → `Niri.capsLock/numLock/kbLayout` (есть в FK). **Баг FK:** `niriipc.cpp` не обрабатывает событие `KeyboardLayoutSwitched`, только `KeyboardLayoutsChanged` (:351). Если niri не шлёт второе при переключении, индикатор не обновится — **проверить** |
| U28 | Popout раскладок с переключением | `bar/popouts/kblayout/{KbLayout,KbLayoutModel}.qml` | **B** | U27 | M | Н | `hyprctl switchxkblayout all N` (:31) → `NiriIpc.action("switch-layout", …)` (`SwitchLayout {layout: {Index: N}}`); список — `Niri.kbLayoutsArray`. Разбор `xkb base.xml` переносится как есть. В FK есть только текст (`FK/modules/bar/popouts/KbLayout.qml`) |
| U29 | Popouts: `AudioPopout`, `ClipWrapper`, `PopoutState`, обновлённые `Content`/`Wrapper` | `bar/popouts/*` | A | U21 | M | С | В `Wrapper.qml` убрать `HyprlandFocusGrab` (:93), `Hypr.activeToplevel` (:126) → `Niri.focusedWindow`. Сохранить popouts форка `WorkspacesPopout`, `WsContextPopout` и `Audio.qml` (сравнить с `AudioPopout`) |
| U30 | Обновления Battery/Bluetooth/Network/WirelessPassword/TrayMenu | `bar/popouts/*` | A | U16 | M | Н | — |
| U31 | Clock, Tray, TrayItem, OsIcon, Power | `bar/components/*` | A | U16 | S | Н | — |

### 3.4. Dashboard, лаунчер, lock

| ID | Описание | Файлы (UP) | Кат. | Зависит от | Слож. | Риск | Примечание по niri |
|---|---|---|---|---|---|---|---|
| U32 | Новая структура вкладок, `WeatherTab`, `dash/SmallWeather` | `modules/dashboard/{Content,Tabs,Wrapper,WeatherTab}.qml`, `dash/SmallWeather.qml` | A | U16 | M | С | Конфликт с `FK/modules/dashboard/{WeatherPanel,NiriThing,ActiveWindow}.qml`: вкладки форка добавить в новую `Tabs` |
| U33 | Медиа: обложка-визуализатор, фигуры, детали, лирика | `dashboard/media/*`, `dashboard/Media.qml` | A | U06, U09, U13 | M | Н | FK `Media.qml` (606 строк) переписан — сверить доработки |
| U34 | Производительность: `HeroCard`, `MemoryCard`, `NetworkCard`, `StorageCard`, `BatteryTank` | `dashboard/performance/*`, `Performance.qml` | A | U11 | M | С | Конфликт с FK `Performance.qml` (969 строк, на `SysMonitorService`) — Q6 |
| U35 | `dash/{User,Calendar,DateTime,Resources,Media}` | `dashboard/dash/*` | A | U16 | M | Н | — |
| U36 | Схемы и варианты через `caelestia scheme …` | `launcher/services/{Schemes,M3Variants}.qml` | **D** | — | — | — | FK намеренно ушёл от `caelestia-cli` (README: «not required for Niri»), бэкенд — `FK/services/{Schemes,M3Variants}.qml` + `scripts/colors/*`. Переносить только UI-часть (U37) |
| U37 | Лаунчер: `Content`, `AppList`, `ContentList`, `WallpaperList`, items | `modules/launcher/**` | A | U16 | M | С | Сохранить режимы форка: `ClipItem`, `ClipPreview`, `WebItem`, `EmojiList` (F08) |
| U38 | `launcher/services/Actions.qml` | — | C | U37 | S | Н | В FK уже niri-действия (`Actions.qml:190` → `niri msg action quit -s`). Взять новые действия UP, проверить отсутствие `hyprctl` |
| U39 | Переделанный центр lock: `center/{Clock,InputField,PasswordInput,ProfilePic,StateMessage}`, `weather/{BriefInfo,Forecast}`, M3Shapes | `modules/lock/**` | A | U02 (m3shapes), U16 | M | С | `StateMessage.qml:72-75` (`Hypr.capsLock`, `kbLayout`, `kbLayoutFull`) → `Niri.*`; `kbLayoutFull` в FK нет, взять из `kbLayoutsArray[kbLayoutIndex]`. FK `Center.qml` (504 строки) и `LockSurface.qml` (428) сильно переписаны — сверить |
| U40 | PAM howdy | `assets/pam.d/howdy`, `lock/Pam.qml` | A | — | S | Н | — |
| U41 | `lock/{Fetch,Resources,Media,NotifDock,NotifGroup,Content,Lock}` | `modules/lock/*` | A | U16 | M | Н | Lock на `WlSessionLock` (ext-session-lock), niri его поддерживает |

### 3.5. Уведомления, sidebar, утилиты, окна

| ID | Описание | Файлы (UP) | Кат. | Зависит от | Слож. | Риск | Примечание по niri |
|---|---|---|---|---|---|---|---|
| U42 | `NotifData` (персистентность) и рефактор `Notifs` | `services/{NotifData,Notifs}.qml` | **B** | U20 | M | С | `hasFullscreen` (`Notifs.qml:24-30`, `NotifData.qml:56-64`) → детектор фуллскрина niri по воркспейсам с `is_active` на каждом выходе (Q3). `ShellState.anySidebarOpen()` после U20 |
| U43 | Модуль sidebar (центр уведомлений, группы, dock) | `modules/sidebar/*` | A | U20, U21, U42 | M | Н | — |
| U44 | `notifications/{Content,Notification,Wrapper}` | `modules/notifications/*` | A | U16 | M | С | FK `Notification.qml` 610 строк — сверить |
| U45 | Запись экрана: `Recorder`, `cards/Record`, `RecordingList`, `RecordingDeleteModal` | `services/Recorder.qml`, `modules/utilities/**` | **B** | U46 | M | С | UP вызывает `caelestia record` (`Recorder.qml:54-61`), а FK от CLI отказался. Варианты: вызывать `gpu-screen-recorder` напрямую (`-w <имя выхода из Niri.focusedMonitorName>` или `-w region` по геометрии от `slurp`) либо вернуть зависимость от CLI. Использует ли CLI `hyprctl` внутри, не проверено — его нет в архивах (Q10) |
| U46 | Карточки утилит `IdleInhibit`, `Toggles`; обновлённые `Content`/`Wrapper` | `modules/utilities/**` | A | U16 | S | Н | В `Toggles.qml:130` кнопка GameMode (U47). Конфликт с F05 (`quicktoggles`) — дублирование функций (Q11) |
| U47 | GameMode: на лету выключить анимации, blur, gaps, тени, скругления | `services/GameMode.qml`, `background/DesktopClock.qml:20` | **B** | F01 (событие `ConfigLoaded`) | M | С | `applyOptions`/`message reload` недоступны. Эмуляция: писать `~/.config/niri/niri/gamemode.kdl` (`animations { off }`, `layout { gaps 0; focus-ring { off } … }`) с `include` в `config.kdl`, а при выключении записывать пустой файл; niri перечитает конфиг. `allow_tearing` — аналог не проверен. Состояние считать из наличия файла, а не из `Hypr.options` |
| U48 | Тосты | `utilities/toasts/*` | A | U16 | S | Н | — |
| U49 | Модуль `windowinfo` (превью, детали, перенос на воркспейс) | `modules/windowinfo/*` | **B** | U26, F01 | M | С | `Details`: поля `HyprlandToplevel.lastIpcObject` → JSON окна niri (`id`, `title`, `app_id`, `pid`, `workspace_id`, `is_floating`, `layout`). `Buttons.qml:95-99`: сетка 10 воркспейсов по `activeWsId` → воркспейсы текущего выхода, действие `MoveWindowToWorkspace` с `window_id`. «Pin» в niri нет. Пересекается с F03 (`NiriThing`) |

### 3.6. Настройки (nexus), фон, сервисы, утилиты

| ID | Описание | Файлы (UP) | Кат. | Зависит от | Слож. | Риск | Примечание по niri |
|---|---|---|---|---|---|---|---|
| U50 | Nexus — новое приложение настроек (~70 файлов, страницы About, Apps, Audio, Bluetooth, Language, Network, Panels, Services, Wallpaper&Style) | `modules/nexus/**` | A | U04, U05, U09, U16 | L | **В** | В `pages/panels/taskbar/BarWorkspaces.qml` скрыть Hyprland-опции (спецворкспейсы, теги). Переименование IPC `controlCenter` → `nexus` ломает бинд `caelestia.kdl:9`. Конфликт с F04 (Q1, Q12) |
| U51 | `Shortcuts.qml`: `nexus`, `showall`, `sidebar`, `launcherInterrupt`, IPC `drawers`/`nexus`/`toaster` | `modules/Shortcuts.qml` | **B** | U18, U20 | S | С | `CustomShortcut` → `IpcHandler` (U18). `hasFullscreen` (:13) → детектор niri. Сохранить IPC форка `clipboard`, `mangaReader`, `novelReader`, `quicktoggles`, `picker` |
| U52 | Фон: `Background`, `Wallpaper`, `DesktopClock`, `Visualiser` | `modules/background/*` | **B** | U04 | M | С | `Visualiser.qml:18` autoHide: «все окна активного ws плавающие» → `Niri.getWindowsByWorkspaceId(<активный ws выхода>).every(w => w.is_floating)`. FK `Wallpaper.qml` (285 строк, видеообои) и `Backdrop.qml` сохранить |
| U53 | `Colours`: `reloadHyprRules` (layerrule blur, ignore_alpha), `setMode` через CLI | `services/Colours.qml:81-110` | **D** | — | — | — | Layer-rules в niri статичны (KDL), runtime-API нет. Прозрачность и blur — через `layer-rule { match namespace="caelestia-drawers" … }` в `caelestia.kdl`; поддержку blur для layer-shell проверить по версии niri. Генерацию палитры оставить на пайплайне форка (F10) |
| U54 | `Wallpapers` через `caelestia wallpaper` | `services/Wallpapers.qml` | **D** | — | — | — | В FK свой пайплайн (видео, matugen, `switchwall.sh`). Взять только UI и API-изменения |
| U55 | `Brightness`: монитор «active», `model:`/`serial:`, apple display | `services/Brightness.qml` | C | U20 | S | Н | FK уже адаптирован (`FK/services/Brightness.qml:30` → `Niri.focusedMonitorName`). Взять остальные улучшения UP, `Hypr.monitorFor(...).focused` (:29) не переносить |
| U56 | `IdleMonitors` на `IdleMonitor` (ext-idle-notify) с таймаутами из конфига, lockBeforeSleep | `modules/IdleMonitors.qml` | **B** | U04, U12 | S | Н | `dpms off/on` (:35) → `niri msg action power-off-monitors` / `power-on-monitors` (проверить второе). Заменяет `FK/services/IdleService.qml`: он опрашивает `xprintidle`/`qdbus` раз в 30 с, а это X11-ориентированный способ |
| U57 | `BatteryMonitor` как модуль | `modules/BatteryMonitor.qml` | C | U04 | S | Н | В FK `services/BatteryMonitor.qml` с настраиваемыми порогами — смержить (сохранить пороги форка) |
| U58 | `Nmcli`, `VPN` (переписан, 838 строк), `utils/NetworkConnection` | `services/{Nmcli,VPN}.qml`, `utils/NetworkConnection.qml` | A | U04 | M | С | В FK есть `services/Network.qml` и state-объекты controlcenter — проверить потребителей |
| U59 | `Weather` (переписан) | `services/Weather.qml` | A | U04 | M | С | В FK редактирование локации (`editingWeatherLocation`) — сверить |
| U60 | `Audio`, `Players`, `IdleInhibitor`, `Time` | `services/*` | A | U04 | S | Н | — |
| U61 | Утилиты: `Icons`, `SysInfo`, `Strings`, `Paths`, `Searcher` | `utils/*` | A | U04 | S | Н | `Icons`: правила `windowIcons` применяются к `app_id` niri так же, как к `class` |
| U62 | areapicker: опции бордера и скругления, список окон, позиция курсора | `modules/areapicker/{Picker,AreaPicker}.qml` | C | — | M | С | FK уже адаптирован (`FK/.../Picker.qml:18,40-66,244`). `hyprctl cursorpos` аналога нет. Из UP брать только независимые улучшения UI. Абсолютные координаты окон FK оценивает приблизительно (:64-65) — проверить `layout.tile_pos_in_workspace_view` в своей версии niri |
| U63 | Инструменты: `.clang-format`, `.clang-tidy`, `.editorconfig`, `scripts/{qml-lint-conventions.py,trs-check.py,trs.fish}`, CI `.github/workflows/*` | — | A | — | S | Н | Опционально |
| U64 | Ассеты: `assets/wallpaper.webp`, шрифт GSF | `assets/*` | A | — | S | Н | — |

### 3.7. Доработки форка, которые нужно сохранить (F)

При схеме «новая ветка от UP» это главный объём работ по переносу и главный источник конфликтов.

| ID | Что | Файлы (FK) | С чем конфликтует | Примечание |
|---|---|---|---|---|
| F01 | Клиент niri IPC | `plugin/src/Caelestia/Internal/{niriipc,nirisocket}.*`, `services/Niri.qml` | U01, U10 | Ядро порта. Расширить: `KeyboardLayoutSwitched`, `ConfigLoaded`, `WorkspaceActiveWindowChanged`. Ветка `OutputsChanged` (:355): **проверить**, существует ли такое событие в niri. Если нет — выходы читаются только при старте, и hotplug не отслеживается |
| F02 | Воркспейсы под колонки niri: Pager, перетаскивание колонок, контекстные меню, группировка по приложению | `bar/components/workspaces/{Pager,DraggableWindowColumn,WindowIcon,WorkspaceIcon}.qml`, `workspaces/context/*`, `bar/popouts/{WorkspacesPopout,WsContextPopout}.qml` | U24 | Q5 |
| F03 | Панель управления niri: overview, фуллскрин, float, center, ширина колонки | `dashboard/NiriThing.qml`, `dashboard/ActiveWindow.qml`, `components/widgets/WindowDecorations.qml` | U49 | Q13 |
| F04 | Control Center + редактор конфига, web-обои (wallhaven, uhdpaper) | `modules/controlcenter/**` (~80 файлов) | U50 | Q12 |
| F05 | Quick toggles | `modules/quicktoggles/*` | U46 | Q11 |
| F06 | Читалки манги и новелл + Python-бэкенды | `modules/{manga,novel}/**`, `services/{Manga,Novel}.qml`, `scripts/{manga,novel}/*` | U20, U21 | Переносятся как отдельные панели |
| F07 | Polkit-агент | `modules/polkit/PolkitDialog.qml`, `services/PolkitService.qml` | — | Независим |
| F08 | Лаунчер: буфер обмена (cliphist), эмодзи, веб-поиск | `launcher/items/{ClipItem,ClipPreview,WebItem}.qml`, `launcher/EmojiList.qml`, `assets/emoji.json` | U37 | — |
| F09 | Area picker: OCR (tesseract), Google Lens | `scripts/areaPicker/*`, `Picker.qml` | U62 | — |
| F10 | Пайплайн цветов и обоев без caelestia-cli, видеообои, шаблон matugen для niri | `scripts/colors/*`, `services/{Colours,Wallpapers,Schemes,M3Variants}.qml`, `dotfiles/.config/matugen/**` | U36, U53, U54 | — |
| F11 | Backdrop для overview niri (`place-within-backdrop`) | `modules/background/Backdrop.qml`, `caelestia.kdl` (layer-rule) | U52 | Niri-специфично, сохранить |
| F12 | Сервисы форка: `SysMonitorService`, `SystemUsage`, `NetworkUsage`, `Fonts`, `Cava`, `BeatDetector`, `IdleService`, `BatteryMonitor` | `services/*`, `plugin/.../Services/sysmonitor.*` | U11, U56, U57 | Q6 |
| F13 | Dotfiles niri, sddm-тема, setup | `dotfiles/**`, `scripts/setup/**` | U50, U51 (имена IPC) | Обновить бинды после переименований IPC |
| F14 | `ReloadPopup`, эффекты, behaviors | `components/ReloadPopup.qml`, `components/{effects,behaviors}/*` | U16 | Перевести на `Tokens` |
| F15 | `modules/keybinds` — только Python-скрипты, без QML | `modules/keybinds/scripts/*` | — | Мёртвый код: флаг `visibilities.keybinds` есть (`Drawers.qml:32,108`), а модуля нет. Удалить или восстановить — Q14 |

---

## 4. График обновления

Схема: **новая ветка `niri-v2` от UP**. FK остаётся рабочим до завершения этапа 5. Каждый этап заканчивается состоянием, которое запускается на niri.

Общие команды проверки (для всех этапов):
```
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo && cmake --build build   # или nix build .#
qs -p <путь_к_ветке>                    # из сессии niri, лог в терминале
niri msg --json workspaces | jq .       # эталон для сверки со значениями в шелле
niri msg --json windows | jq .
niri msg event-stream                   # наблюдать события параллельно с действиями в шелле
qs -p <путь> ipc show                   # список IpcHandler-ов
```

### Этап 0. Подготовка (S, ~1 день)
- **Цель:** зафиксировать базу и эталоны.
- **ID:** —
- **Предусловия:** решения по Q1 и Q4.
- **Работы:** завести git-репозиторий: импорт FK как `fork-legacy`, импорт UP как `upstream` и ветка `niri-v2` от него. Записать версию niri (`niri --version`) и снять эталонные дампы `niri msg --json {workspaces,windows,outputs,keyboard-layouts}`, включая окно в фуллскрине — это закрывает Q3. Сохранить текущий `~/.config/caelestia/shell.json`.
- **Проверка:** FK запускается на niri как прежде (контрольная точка для сравнения).
- **Готово, когда:** есть ветки и дампы, известно, отдаёт ли niri признак фуллскрина.

### Этап 1. Сборка UP без Hyprland (M, 2–3 дня)
- **Цель:** собрать C++-плагин UP с выключенным Hyprland-кодом и подключённым niri-клиентом.
- **ID:** U01, U02, U03, U10, U14, F01 (только перенос и сборка), U06, U07, U08, U15
- **Предусловия:** этап 0.
- **Работы:** исключить `hyprextras/hyprdevices` из `Services/CMakeLists.txt`. Перенести `Internal/niri*` как модуль (например `Caelestia.Niri`) под новый `qml_module` и strict-флаги: возможны предупреждения `-Wconversion`/`-Wshadow`, превращённые в ошибки. Nix: добавить `lm_sensors`, `m3shapes`, `qtimageformats`, убрать `hyprland`.
- **Проверка на niri:** `nix build` / `cmake --build` проходит без ошибок. В `qs` проверочный QML-файл c `import Caelestia.Niri` выводит `NiriIpc.workspaces.length > 0`, а `available === true`.
- **Готово, когда:** плагин собирается и `NiriIpc` доступен из QML.

### Этап 2. Слой композитора niri (M–L, 3–5 дней)
- **Цель:** расширить `services/Niri.qml` до объёма, нужного коду UP, и убрать `services/Hypr.qml`.
- **ID:** F01 (расширение), U18, U20
- **Предусловия:** этап 1.
- **Работы:**
  - В `niriipc.cpp`: обработка `KeyboardLayoutSwitched`, `ConfigLoaded` (сигнал `configReloaded`), `WorkspaceActiveWindowChanged`; проверить и исправить `OutputsChanged`.
  - В `Niri.qml` добавить функции под вызовы UP (явно, **без** имитации Hyprland-объектов): `outputForScreen(screen)`, `activeWorkspaceForOutput(name)`, `windowsForWorkspace(id, filter)`, `hasFullscreenOnOutput(name)`, `isFocusedScreen(screen)`, `switchKbLayout(idx)`, `kbLayoutFull`.
  - `ShellState.forActive()` / `componentsForActive()` перевести на `Niri.focusedMonitorName`.
  - `CustomShortcut` удалить, все шорткаты оформить через `IpcHandler`.
  - Удалить `services/Hypr.qml`; каждое место вызова будет адаптировано на своём этапе.
- **Проверка на niri:** `grep -rn 'Hypr\b\|Quickshell.Hyprland\|hyprctl' --include=*.qml` даёт только ещё не адаптированные модули (список вести в трекере). Переключение раскладки (`niri msg action switch-layout next`) меняет `Niri.kbLayout` в течение ~100 мс. Фокус на другом мониторе меняет `ShellState.forActive()`.
- **Готово, когда:** API `Niri` покрывает таблицу 2.2 и проверено на живых событиях.

### Этап 3. Каркас: конфиг, токены, drawers, бар (L, 6–9 дней)
- **Цель:** базовая оболочка UP (бар, рамка, drawers) работает на niri.
- **ID:** U04, U05, U09, U16, U17, U19, U21, U22, U23, U24, U27, U29, U31
- **Предусловия:** этап 2; решения по Q3, Q4, Q5, Q7.
- **Работы:** в `ContentWindow.qml` ветку спецворкспейсов убрать, фуллскрин брать из `Niri.hasFullscreenOnOutput`, `HyprlandFocusGrab` заменить на `keyboardFocus` + клик вне. Workspaces UP адаптировать по U24, пока **без** функций F02. Ключи форка добавить в C++-схему `barconfig.hpp`.
- **Проверка на niri:**
  - Бар на каждом выходе; воркспейсы соответствуют `niri msg --json workspaces` для этого выхода. Новый воркспейс, появившийся динамически, отображается.
  - Клик по воркспейсу переключает его, скролл по бару работает как `focus-workspace-up/down`.
  - Окно в фуллскрине (`Mod+F`) убирает рамку; при выходе рамка возвращается.
  - Открытие и закрытие launcher/session/dashboard; Esc и клик вне закрывают панель; фокус клавиатуры не «залипает».
  - Caps/Num Lock и раскладка в статус-иконках.
  - Правка `~/.config/caelestia/shell.json` применяется на лету, ключи форка не теряются после сохранения из UI.
- **Готово, когда:** сутки обычной работы без ошибок `TypeError`/`ReferenceError` в логе `qs`.

### Этап 4. Независимые модули UP (M–L, 5–7 дней)
- **Цель:** догнать UP по композитор-независимой функциональности.
- **ID:** U11, U12, U13, U30, U32, U33, U34, U35, U37, U38, U39, U40, U41, U43, U44, U46, U48, U55, U57, U58, U59, U60, U61, U63, U64
- **Предусловия:** этап 3; решения по Q6, Q11.
- **Проверка на niri:** вкладки dashboard (медиа с лирикой при играющем плеере; карточки CPU/GPU/RAM/диск/сеть сверены с `btop`). Sidebar уведомлений (`notify-send` ×5, группировка, DND). Lock (`loginctl lock-session` или IPC `lock`): пароль, раскладка в `StateMessage`. VPN/Wi-Fi/Bluetooth popouts. Logout через `SessionManager` завершает сессию niri.
- **Готово, когда:** все пункты пройдены, регрессий этапа 3 нет.

### Этап 5. Адаптация зависимой от композитора функциональности (L, 5–7 дней)
- **Цель:** перенести функции UP, которым нужна логика niri.
- **ID:** U26, U28, U42, U45, U47, U49, U51, U52, U56, U62
- **Предусловия:** этап 4; решения по Q3, Q9, Q10, Q13.
- **Работы:** детали по каждому ID — в колонке «Примечание по niri». GameMode: добавить `include "niri/gamemode.kdl"` в `dotfiles/.config/niri/config.kdl` и создать пустой файл при установке.
- **Проверка на niri:**
  - Popout раскладок: выбор пункта ↔ `niri msg keyboard-layouts`.
  - Активное окно: заголовок меняется при `focus-column-left/right`; превью — если Q9 решён положительно.
  - windowinfo: перенос окна на воркспейс 2 подтверждает `niri msg --json windows` (`workspace_id`).
  - GameMode: при включении пропадают анимации и gaps, при выключении всё возвращается; после `niri msg action load-config-file` (или правки конфига) состояние сохраняется.
  - Idle: короткий таймаут из конфига → lock, затем `power-off-monitors`; любой ввод возвращает экран. Инхибитор при играющем плеере.
  - Уведомления при фуллскрине ведут себя по `notifs.fullscreen`.
  - Запись экрана: старт, пауза, стоп, файл в списке.
- **Готово, когда:** все B-изменения закрыты или явно отложены с записью в Q.

### Этап 6. Перенос доработок форка (L, 6–9 дней)
- **Цель:** вернуть в `niri-v2` всё уникальное из FK.
- **ID:** F02–F15, U50 (по решению Q12), U53/U54 (UI-часть поверх F10)
- **Предусловия:** этапы 3–5; решения по Q1, Q11–Q14.
- **Порядок:** F10, F11 (цвета и обои) → F02 (воркспейсы, самая хрупкая часть: drag колонок через `moveColumnToIndex`) → F03 → F08, F09 → F05 → F06, F07 → F04 / U50 → F12, F14, F15 → F13 (бинды и dotfiles под новые имена IPC).
- **Проверка на niri:** перетаскивание иконки окна в баре меняет порядок колонок (сверить `pos_in_scrolling_layout`). Контекстное меню окна. Смена обоев → обновлены `colors.kdl` и палитра шелла. Backdrop виден в overview (`toggle-overview`). Manga/novel/polkit (`pkexec true`)/clipboard (`Mod+V`)/OCR/Lens работают. Все бинды из `caelestia.kdl` вызывают существующие IPC-цели (`qs ipc show`).
- **Готово, когда:** функциональный паритет с FK по чек-листу из README форка («My Changes»).

### Этап 7. Миграция конфигов, упаковка, финальная проверка (M, 2–3 дня)
- **Цель:** безопасно обновить пользовательские установки.
- **ID:** U02 (финал), U04 (миграция), F13
- **Предусловия:** этап 6.
- **Работы:** миграция `shell.json` по решению Q4 (переименования вроде `bar.workspaces.perMonitorWorkspaces` → `perMonitor`, `bar.status.show*` → список `bar.statusIcons`). Обновить README: зависимости (`lm_sensors`, `m3shapes`), бинды. Отдельно проверить hm-module на NixOS.
- **Проверка на niri:** чистый профиль (пустой `~/.config/caelestia`) и профиль со старым `shell.json` из FK — оба запускаются без ошибок, пользовательские значения сохранены. `nixos-rebuild`/`home-manager switch` с модулем.
- **Готово, когда:** ветка `niri-v2` заменяет FK; FK заархивирован как `fork-legacy`.

**Сводка по времени (оценка):** этап 0 — 1 д.; 1 — 2–3 д.; 2 — 3–5 д.; 3 — 6–9 д.; 4 — 5–7 д.; 5 — 5–7 д.; 6 — 6–9 д.; 7 — 2–3 д. Итого ≈ **30–45 человеко-дней**.

### Критический путь и риски
- **U04 → U16 → всё остальное.** Без конфига и токенов не собирается ни один QML-модуль UP. Это самый рискованный этап (смена схемы `shell.json`).
- **U21 (ContentWindow + Blobs)** заменяет всю отрисовку фона панелей. Панели форка (manga, novel, quicktoggles) рисуют свои `Background.qml` по старой схеме — их придётся переписать под `Regions`/Blobs.
- **U24 ↔ F02**: максимальная вероятность конфликта логики. Upstream-воркспейсы рассчитаны на линейные воркспейсы Hyprland, форк — на колонки niri.
- **Переименование IPC** (`controlCenter` → `nexus`, новые `sidebar`/`showall`) ломает пользовательские бинды niri. Нужна совместимость: старые цели как алиасы на переходный период.
- **Фуллскрин (Q3)** влияет на U21, U42, U51 — решить на этапе 0.
- **Внешние CLI**: UP по-прежнему опирается на `caelestia` CLI (scheme, wallpaper, record), форк от него отказался. Каждое место — явное решение (U36, U45, U53, U54).

---

## 5. Открытые вопросы

| № | Вопрос | Варианты | Рекомендация |
|---|---|---|---|
| Q1 | Стратегия: новая ветка от UP с переносом доработок форка или поэтапный перенос изменений UP в FK? | (a) от UP; (b) в FK | (a): 171 из 182 общих файлов отличаются, конфиг и токены переписаны целиком |
| Q2 | Спецворкспейсы (U25) | отказаться; эмулировать именованными воркспейсами niri (`workspace "music"` в KDL + `focus-workspace music`) | Отказаться. Именованные воркспейсы в niri привязаны к выходу и участвуют в прокрутке — это не scratchpad |
| Q3 | Детектор фуллскрина | поле из IPC (если есть в вашей версии niri); эвристика по `layout.window_size` ≈ размер выхода; не детектировать | Решить по дампу этапа 0 |
| Q4 | Совместимость `shell.json` | скрипт миграции (bash/Go, не Python); миграция в C++ при загрузке; «начать с чистого» | Миграция при загрузке. Нужно проверить, сохраняет ли `Settings/quarantine` неизвестные ключи при записи (по коду `ObjectQuarantine::apply` похоже, что да; не проверено запуском) |
| Q5 | `bar.workspaces.perMonitor = false` в niri | показывать воркспейсы всех выходов; игнорировать опцию | Решить вместе с F02: Pager форка уже работает по выходам |
| Q6 | Мониторинг: C++-сервисы UP (U11) или `sysmonitor` форка (F12)? | UP; форк; гибрид | UP (`gpu.cpp` читает `/sys/class/drm`, есть шанс поддержки Intel, которой нет у форка). Проверить на вашей GPU (RTX 3070 → ветка `nvidia-smi`) |
| Q7 | `ignoredTags` (`hide_in_bar`, `xwl_popup`) | убрать; заменить на regex по `app_id`/`title` | Заменить на список regex по `app_id` в C++-схеме |
| Q8 | Обновляется ли раскладка в FK сейчас (нет `KeyboardLayoutSwitched`)? | — | Проверить на этапе 0; исправление в любом случае на этапе 2 |
| Q9 | Живое превью окна (U26, U49): поддерживает ли ваша версия niri захват отдельного toplevel через Quickshell `ScreencopyView`? | превью; только иконка и заголовок | Проверить; если нет — без превью |
| Q10 | Запись экрана (U45) | вернуть зависимость от `caelestia` CLI; прямой `gpu-screen-recorder`; не переносить | Прямой `gpu-screen-recorder`, если CLI внутри опирается на `hyprctl` (не проверено — CLI нет в архивах) |
| Q11 | `quicktoggles` (F05) и `utilities/cards/Toggles` (U46) дублируют друг друга | оставить оба; влить F05 в utilities; оставить F05 | Нужен ваш выбор UX |
| Q12 | Настройки: Nexus (UP) или Control Center форка (F04, редактор конфига, web-обои)? | Nexus + перенос уникальных панелей форка как страниц; оставить CC; оба | Nexus как основа (на нём завязаны C++-конфиг и i18n) + перенос страниц форка. Объём L |
| Q13 | `windowinfo` (U49) и `NiriThing` (F03) | объединить; оставить оба | Объединить: действия niri из F03 добавить кнопками в windowinfo |
| Q14 | `modules/keybinds` (F15): мёртвый код | удалить; восстановить просмотр биндов niri | Удалить; при необходимости восстановить отдельной задачей |
| Q15 | GameMode (U47): допустимо ли, что шелл пишет файлы в `~/.config/niri/`? | да (генерируемый include); нет — только переключать набор правил вручную | Да — тот же подход, что у `colors.kdl` в форке |

---

## Приложение: что осталось непроверенным

- Сборка и запуск обоих проектов (нет niri, Quickshell и GPU в среде анализа).
- Точные имена и наличие действий и полей niri для вашей версии: `power-on-monitors`, признак фуллскрина окна, `layout.tile_pos_in_workspace_view`, событие `OutputsChanged`, blur для layer-shell. Проверить через `niri msg action --help` и `niri msg --json …`.
- Содержимое `caelestia` CLI (`scheme`, `wallpaper`, `record`) — его нет в архивах.
- Модули UP, просмотренные по структуре, а не построчно: `modules/nexus/**` (~70 файлов), `modules/sidebar/**`, `dashboard/media/**`, `dashboard/performance/**`, `lock/center/**`, C++ `Settings/*` и `Config/*` (кроме `barconfig.hpp`, `rootnodes.cpp`). В них Hyprland-зависимости искались grep'ом по `Hypr`, `Quickshell.Hyprland`, `hyprctl`, `GlobalShortcut`, `HyprlandFocusGrab`; совпадения есть только в файлах, перечисленных в разделе 2.1.
- Доработки внутри общих файлов FK (например `Media.qml`, `Notification.qml`, `Center.qml`) сверены по объёму diff, но не построчно. Перед переносом каждого из них нужен ручной трёхсторонний просмотр.
- Python-скрипты форка (manga/novel/colors/webWallpaper) не анализировались: они не зависят от композитора и переносятся как есть.
