# Журнал решений

Формат: `Qn — PENDING/DECIDED — кто — суть — последствия`. Подробности вариантов — `UPDATE_PLAN.md`, раздел 5.

## Вопросы

- **Q1** — DECIDED — человек — Стратегия: перенос upstream на niri (ветка `niri-v2` от `upstream/main`), доработки форка — опционально в S10. — Схема работ S0–S11.
- **Q2** — PENDING — Спецворкспейсы (U25): отказаться / эмулировать именованными воркспейсами. Рекомендация плана: отказаться (`supports.specialWorkspaces: false`). — Блокирует S6b (U25).
- **Q3** — DECIDED — человек (2026-10-16) — Вариант (a): эвристика. Окно считается фуллскринным, если `layout.window_size` совпадает (±1px) с логическим размером выхода его воркспейса; выход «в фуллскрине», если такое окно на его **активном** воркспейсе. Windowed fullscreen не детектируется. — `NiriIpc.fullscreenOutputs`, `hasFullscreen(output)`, `isWindowFullscreen(id)`, сигнал `fullscreenChanged`; в S4 → `Compositor.hasFullscreen(output)`, `supports.fullscreenFlag: true` (по эвристике). UNVERIFIED: допуск ±1px при дробном масштабе.
- **Q4** — PENDING — Совместимость `shell.json` со старым форком: миграция при загрузке / скрипт (bash/Go) / начать с чистого. — Актуально для S10/S8.
- **Q5** — PENDING — `bar.workspaces.perMonitor = false` на niri: показывать воркспейсы всех выходов / игнорировать опцию. — Блокирует S6b.
- **Q6** — PENDING — Мониторинг: C++-сервисы upstream (U11) или `sysmonitor` форка (F12). Рекомендация: upstream. — Актуально только для S10.
- **Q7** — PENDING — `ignoredTags`: убрать / заменить на regex по `app_id`/`title`. — Блокирует часть S6b.
- **Q8** — PENDING — Какое событие приходит при переключении раскладки (`KeyboardLayoutSwitched`?). Решается по фикстуре `kb-switch`. По src 26.4.0 событие `KeyboardLayoutSwitched{idx}` есть; осталось подтвердить фикстурой, что niri шлёт именно его. — S3c, S6c.
- **Q9** — PENDING — Живое превью окна (`ScreencopyView` по toplevel) на niri: превью / только иконка и заголовок. — Определяет `supports.toplevelCapture`, U26, U49.
- **Q10** — PENDING — Запись экрана (U45): `caelestia` CLI / прямой `gpu-screen-recorder` / не переносить. Зависит от аудита CLI. — S7 (U45).
- **Q11** — PENDING — `quicktoggles` (F05) vs `utilities/cards/Toggles` (U46). — Только S10.
- **Q12** — PENDING — Настройки: Nexus (upstream) или Control Center форка (F04). Рекомендация: Nexus. — Только S10.
- **Q13** — PENDING — `windowinfo` (U49) и `NiriThing` (F03): объединить / оставить оба. — U49 в S7 (базовая часть не блокируется).
- **Q14** — PENDING — `modules/keybinds` (F15): удалить / восстановить. — Только S10.
- **Q15** — PENDING — GameMode (U47): допустимо ли писать файлы в `~/.config/niri/` (генерируемый include). Рекомендация: да. — Блокирует U47.
- **Q-NIX1** — PENDING — HM: `shell.json` через `xdg.configFile` (read-only симлинк) ломает сохранение из UI. Варианты: (a) как есть; (b) seed — активационный скрипт копирует JSON, только если файла нет; (c) оба через опцию. — Блокирует S8 (hm-module).
- **Q-NIX2** — PENDING — Генерировать ли из HM-модуля KDL-сниппет биндов для `include` в конфиг niri, и как пользователь собирает конфиг niri. — Блокирует часть S8.

## Факты о niri

Источник «src 26.4.0» — `niri-ipc/src/lib.rs` из `nixpkgs#niri.src` (flake nixpkgs, niri 26.4.0); проверено чтением исходников, не запуском. Версию niri в живой сессии пользователя нужно сверить по фикстурам (`version.json`).

- VERIFIED(src 26.4.0) — у `Window` **нет** признака фуллскрина. Поля: `id, title?, app_id?, pid?, workspace_id?, is_focused, is_floating, is_urgent, layout, focus_timestamp?`. Есть только действия `FullscreenWindow` и `ToggleWindowedFullscreen`. → Q3: только эвристика (например, `layout.window_size` ≈ логический размер выхода) или отказ. Фикстура `fullscreen` нужна, чтобы проверить эвристику.
- VERIFIED(src 26.4.0) — `WindowLayout`: `pos_in_scrolling_layout?: (col, tile)` (1-based), `tile_size`, `window_size`, `tile_pos_in_workspace_view?`, `window_offset_in_tile`. Поле `tile_pos_in_workspace_view` есть.
- VERIFIED(src 26.4.0) — события: `WorkspacesChanged, WorkspaceUrgencyChanged, WorkspaceActivated{id,focused}, WorkspaceActiveWindowChanged{workspace_id,active_window_id?}, WindowsChanged, WindowOpenedOrChanged, WindowClosed, WindowFocusChanged{id?}, WindowFocusTimestampChanged, WindowUrgencyChanged, WindowLayoutsChanged{changes:[[id,layout]]}, KeyboardLayoutsChanged{keyboard_layouts{names,current_idx}}, KeyboardLayoutSwitched{idx}, OverviewOpenedOrClosed{is_open}, ConfigLoaded{failed}, ScreenshotCaptured, CastsChanged, CastStartedOrChanged, CastStopped`.
- VERIFIED(src 26.4.0) — события **`OutputsChanged` нет**. Ветка форка мёртвая → в S3c удалить; выходы перечитывать запросом `Outputs` (например, по `WorkspacesChanged`). Hotplug напрямую не отслеживается.
- VERIFIED(src 26.4.0) — `KeyboardLayoutSwitched{idx}` существует, форк его не обрабатывал → Q8: индикатор раскладки в форке не обновлялся при переключении (если niri не шлёт ещё и `KeyboardLayoutsChanged`). Исправление — S3c.
- VERIFIED(src 26.4.0) — `ConfigLoaded{failed}` приходит при каждом подключении к event-stream и при перезагрузке конфига.
- VERIFIED(src 26.4.0) — действия `PowerOffMonitors {}` и `PowerOnMonitors {}` есть; `Quit{skip_confirmation}`; `SwitchLayout{layout: "Next"|"Prev"|{"Index":N}}`; `FocusWorkspace{reference}`, `MoveWindowToWorkspace{window_id?, reference, focus}`, где `reference` — `{"Id":N}|{"Index":N}|{"Name":S}`; `FocusWorkspaceUp/Down {}`; `ToggleOverview {}`; `LoadConfigFile`.
- VERIFIED(src 26.4.0) — ответ `Outputs` — словарь `имя → Output{name, make, model, serial?, physical_size?, modes, current_mode?, is_custom_mode, vrr_supported, vrr_enabled, logical?{x,y,width,height,scale,transform}}`.
- UNVERIFIED — поведение `include` на отсутствующий файл.
- UNVERIFIED — blur для layer-shell поверхностей.
- UNVERIFIED — совпадает ли версия niri в сессии пользователя с 26.4.0.

## Окружение
- 2026-10-16 — S1: `nix build -L .#default` на чистом upstream (a3a8fe59) упал не из-за кода: quickshell 0.3.2 (input `quickshell`, нет в бинарном кэше) собирается из исходников и падает с `No space left on device`. На `/` (там же `/nix`, build-dir `/nix/var/nix/b`) свободно 650M из 125G. Нужно освободить место (решение человека: `nix-collect-garbage`, удаление старых поколений и т. п.), затем повторить сборку.
- 2026-10-16 — Правки flake (devShell-инструменты, `checks.package`) вычисляются (`nix eval` ок); сборка не проверена.
- 2026-10-16 — S1 закрыт: человек освободил место (на / 33G). `nix build .#default` (чистый upstream + правки flake) → `/nix/store/dv3mg159…-caelestia-shell-1.0.0`. `nix flake check -L` (x86_64-linux) — зелёный.
- `nix flake check --all-systems` падает на `armv6l-linux`: «cannot bootstrap GHC» (quickshell → pipewire → … → pandoc → ghc). Проблема upstream/nixpkgs, не порта; гейт — только x86_64-linux. Предупреждение `unknown flake output 'homeManagerModules'` — из upstream, не трогаем.
- devShell: niri 26.04 (nixpkgs), qmllint/qtdeclarative 6.11.2, clang-tools 21.1.8, cmake 4.4.3. Версия niri в живой сессии пользователя — записать по фикстурам (S2).
- 2026-10-16 — Агент работает от пользователя `claude-agent` без `NIRI_SOCKET`: L3a (вложенный niri) и запись фикстур агенту недоступны; всё рантайм-поведение — через человека (L3b).
- 2026-10-16 — S3a: `Services/hypr{extras,devices}` удалены (U10). До S4 рантайм шелла сломан: `services/Hypr.qml` ссылается на `HyprExtras`. Это ожидаемо по плану; сборка C++ и `nix flake check` зелёные.

## Отличия `Caelestia.Niri` от fork-legacy (S3a)
- Пространство имён `caelestia::niri`, URI `Caelestia.Niri`, логирование через категории `caelestia.niri.{socket,ipc}`.
- `NiriRequestSocket`: колбэк и `processQueue()` вызывались дважды, когда приходили и `errorOccurred`, и `disconnected` → теперь ровно один раз.
- `handleWindowClosed`: при закрытии сфокусированного окна индекс фокуса указывал на чужое окно → фокус сбрасывается.
- `handleWindowsChanged` / `handleWindowOpenedOrChanged`: индекс фокуса пересчитывается после сортировки (был устаревшим).
- `handleWindowFocusChanged`: `focusedWindowChanged` эмитился дважды → один раз.
- Для тестов: публичные `processEvent()`, `applyResponse()`, статический `actionPayload()`, конструктор `NiriIpc(autoConnect=false, parent)`.
- Ветка `OutputsChanged` оставлена с пометкой UNVERIFIED (решится по фикстурам в S3c).
- 2026-10-16 — S3b: тесты `plugin/tests/niri/tst_niriipc.cpp`. `replayFixtures` автоматически берёт **каждый** каталог `tests/fixtures/niri/*` с `workspaces.after.json`: снимок → проигрывание `event-stream.jsonl` → сравнение с `*.after.json` (воркспейсы: output/idx/is_active/is_focused; порядок окон по воркспейсам; фокус окна; раскладка). Пока есть только `synthetic-basic` (ручная, по схеме src 26.4.0). Тесты: `CAELESTIA_BUILD_TESTS=ON` (по умолчанию OFF, чтобы не трогать сборку пакета), `checks.unit` во flake.
- Формат: `niri msg --json <query>` печатает **развёрнутый** ответ (массив/объект/null), event-stream — по одному событию `{"Type":{...}}` на строку (src 26.4.0, `src/ipc/client.rs`).
- Известный долг для S3c: `actionPayload("switch-layout", {"next"})` строит `{"SwitchLayout":"next"}`, а нужен `{"SwitchLayout":{"layout":"Next"}}`; generic-числовой аргумент превращается в `{"id":N}` — для многих действий это неверно. Разобрать вместе с API `Compositor` (S4).

## Фикстуры (S2, записаны 2026-10-16)
Как записаны: `scripts/port/record-niri-fixtures.sh` — изолированный headless sway (pixman) → вложенный niri 26.04 (winit) с `tests/fixtures/niri/config.kdl`; к сессии пользователя не подключается (свой `XDG_RUNTIME_DIR`, сброшены `WAYLAND_DISPLAY`/`NIRI_SOCKET`/`DBUS_SESSION_BUS_ADDRESS`). Окна — `foot --app-id fixture-N sleep 3600`. Сценарии: idle, windows, workspaces, fullscreen, kb-switch, overview, config-reload.
- VERIFIED(fixture kb-switch) — **Q8**: `switch-layout` даёт только `KeyboardLayoutSwitched{idx}`, `KeyboardLayoutsChanged` не приходит. Баг форка воспроизведён: `replayFixtures(kb-switch)` падает (индекс остаётся 0) → исправление в S3c.
- VERIFIED(fixture fullscreen) — **Q3, данные для эвристики**: в настоящем фуллскрине `layout.window_size` и `tile_size` **в точности** равны логическому размеру выхода (1276×693; без фуллскрина 626×677). `toggle-windowed-fullscreen` в IPC никак не виден (layout не меняется). Флага в IPC нет. Решение по Q3 всё ещё за человеком.
- VERIFIED(fixtures) — event-stream при подключении сначала присылает полное состояние: `WorkspacesChanged, WindowsChanged, OverviewOpenedOrClosed, KeyboardLayoutsChanged, ConfigLoaded, CastsChanged`.
- VERIFIED(fixture overview) — при открытии overview приходит `WindowFocusChanged{id:null}`, при закрытии фокус возвращается (`WindowFocusChanged{id:3}`). UI, завязанный на фокусное окно, будет «мигать» на время overview.
- VERIFIED(fixture config-reload) — `load-config-file` даёт `ConfigLoaded{failed:false}`.
- VERIFIED(fixture windows) — смена фокуса и перестановка колонок дают `WorkspaceActiveWindowChanged` и `WindowLayoutsChanged`; новое окно — `WindowOpenedOrChanged`, закрытие — `WindowClosed`.
- UNVERIFIED(nested) — `tile_pos_in_workspace_view` во вложенной сессии всегда `null` (вероятно, headless sway не присылает кадры, и niri не считает вид). Проверить в живой сессии или не опираться на поле.
- UNVERIFIED(nested) — multi-monitor: у winit-бэкенда niri ровно один выход, сценарий в изоляции не записать.
- 2026-10-16 — S3c: ветка `OutputsChanged` удалена (события нет в niri 26.04). `Outputs` перезапрашивается при каждом `WorkspacesChanged`, если сокет подключён (воркспейсы меняются при hotplug выходов). UNVERIFIED: что niri шлёт `WorkspacesChanged` при hotplug — в изоляции не проверить (winit, один выход).
- 2026-10-16 — `ConfigLoaded{failed}` → сигнал `NiriIpc.configLoaded(bool failed)`. Он приходит и при каждом переподключении event-stream, поэтому потребители (GameMode, U47) должны быть идемпотентны.
