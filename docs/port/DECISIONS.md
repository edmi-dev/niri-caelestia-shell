# Журнал решений

Формат: `Qn — PENDING/DECIDED — кто — суть — последствия`. Подробности вариантов — `UPDATE_PLAN.md`, раздел 5.

## Вопросы

- **Q1** — DECIDED — человек — Стратегия: перенос upstream на niri (ветка `niri-v2` от `upstream/main`), доработки форка — опционально в S10. — Схема работ S0–S11.
- **Q2** — DECIDED — человек (2026-10-17) — (a) отказаться: виджет спецворкспейсов скрыт, `supports.specialWorkspaces: false`. Исходно: Спецворкспейсы (U25): отказаться / эмулировать именованными воркспейсами. Рекомендация плана: отказаться (`supports.specialWorkspaces: false`). — Блокирует S6b (U25).
- **Q3** — DECIDED — человек (2026-10-16) — Вариант (a): эвристика. Окно считается фуллскринным, если `layout.window_size` совпадает (±1px) с логическим размером выхода его воркспейса; выход «в фуллскрине», если такое окно на его **активном** воркспейсе. Windowed fullscreen не детектируется. — `NiriIpc.fullscreenOutputs`, `hasFullscreen(output)`, `isWindowFullscreen(id)`, сигнал `fullscreenChanged`; в S4 → `Compositor.hasFullscreen(output)`, `supports.fullscreenFlag: true` (по эвристике). UNVERIFIED: допуск ±1px при дробном масштабе.
- **Q4** — PENDING — Совместимость `shell.json` со старым форком: миграция при загрузке / скрипт (bash/Go) / начать с чистого. — Актуально для S10/S8.
- **Q5** — DECIDED — человек (2026-10-17) — (a) игнорировать `perMonitor`: бар всегда показывает воркспейсы своего выхода. Исходно: `bar.workspaces.perMonitor = false` на niri: показывать воркспейсы всех выходов / игнорировать опцию. — Блокирует S6b.
- **Q6** — PENDING — Мониторинг: C++-сервисы upstream (U11) или `sysmonitor` форка (F12). Рекомендация: upstream. — Актуально только для S10.
- **Q7** — DECIDED — человек (2026-10-17) — Вариант «заменить»: `ignoredTags` → правила (regex) по `app_id`/`title`. Исходная формулировка: `ignoredTags`: убрать / заменить на regex по `app_id`/`title`. — Блокирует часть S6b.
- **Q8** — PENDING — Какое событие приходит при переключении раскладки (`KeyboardLayoutSwitched`?). Решается по фикстуре `kb-switch`. По src 26.4.0 событие `KeyboardLayoutSwitched{idx}` есть; осталось подтвердить фикстурой, что niri шлёт именно его. — S3c, S6c.
- **Q9** — PENDING — Живое превью окна (`ScreencopyView` по toplevel) на niri: превью / только иконка и заголовок. — Определяет `supports.toplevelCapture`, U26, U49.
- **Q10** — DECIDED — человек (2026-10-17) — (b): шелл сам запускает `gpu-screen-recorder` через `assets/record.sh`, выход и fps — из niri (`Compositor.outputRefresh`). Исходно: Запись экрана (U45): `caelestia` CLI / прямой `gpu-screen-recorder` / не переносить. Зависит от аудита CLI. — S7 (U45). VERIFIED (caelestia-cli из flake.lock, `subcommands/record.py:74`): `caelestia record` при старте вызывает `hypr.message("monitors")` (сокет Hyprland) — на niri запуск записи упадёт; стоп/пауза работают через `pidof`/сигналы. Рекомендация: (b) шелл сам запускает `gpu-screen-recorder -w <выход>` / `-w region`.
- **Q11** — PENDING — `quicktoggles` (F05) vs `utilities/cards/Toggles` (U46). — Только S10.
- **Q12** — PENDING — Настройки: Nexus (upstream) или Control Center форка (F04). Рекомендация: Nexus. — Только S10.
- **Q13** — PENDING — `windowinfo` (U49) и `NiriThing` (F03): объединить / оставить оба. — U49 в S7 (базовая часть не блокируется).
- **Q14** — PENDING — `modules/keybinds` (F15): удалить / восстановить. — Только S10.
- **Q15** — DECIDED — человек (2026-10-17) — (a) да: GameMode пишет генерируемый include-файл в `~/.config/niri/`. Исходно: GameMode (U47): допустимо ли писать файлы в `~/.config/niri/` (генерируемый include). Рекомендация: да. — Блокирует U47.
- **Q16** — DECIDED — человек (2026-10-17) — Вариант (a): оставить `close-window`. Исходная формулировка: Кнопка «Kill» в windowinfo (U49): в niri нет принудительного kill (`niri msg action --help`). Варианты: (a) `close-window` — вежливое закрытие (сейчас так, не блокирует); (b) `kill -9 <pid>` из шелла. Рекомендация: (a), подпись кнопки не менять.
- **Q17** — PENDING — Размытие под панелями шелла на niri. Правило layer-rule на весь слой `caelestia-drawers` непригодно (xray закрывает окна, см. «ОПРОВЕРГНУТО» ниже). Варианты: (a) без blur (сейчас так); (b) layer-rule с `xray false` (экспериментально в niri 26.04, пропадает при анимациях, дорого — но всё равно размывает весь экран, а не только панели → по сути непригодно); (c) фигурный blur через `ext-background-effect` из шелла (нужна поддержка в quickshell, отдельная задача S10). Рекомендация: (a) сейчас, (c) позже. Не блокирует.
- **Q18** — PENDING — Погода (upstream `services/Weather.qml`, порт не трогал): при ошибке запроса к open-meteo (2026-10-17 13:15 — `503 Service Unavailable`) повтора нет, следующий запрос только через час (Timer 3600000) → в dashboard «--». С той же машины через минуты API отвечает 200. Варианты: (a) оставить как upstream; (b) NIRI-PORT-правка: onError + повтор через 5 мин (дифф к upstream); (c) завести issue/PR в upstream. Рекомендация: (c), локально (a). Не блокирует.
- **Q-NIX1** — DECIDED — человек (2026-10-17) — (c) оба режима через опцию модуля (managed — симлинк, seed — копия, если файла нет). Исходно: HM: `shell.json` через `xdg.configFile` (read-only симлинк) ломает сохранение из UI. Варианты: (a) как есть; (b) seed — активационный скрипт копирует JSON, только если файла нет; (c) оба через опцию. — Блокирует S8 (hm-module).
- **Q-NIX2** — DECIDED — человек (2026-10-17) — конфиг niri пишется руками и подключается из системного flake (`hmArgs.niriConfig = ./hosts/kurva-lenovo/config/niri.kdl`); HM-модуль генерирует `~/.config/niri/caelestia.kdl`, пользователь добавляет `include "caelestia.kdl"` (VERIFIED: `include` есть в niri 26.04, `niri validate`). Исходно: Генерировать ли из HM-модуля KDL-сниппет биндов для `include` в конфиг niri, и как пользователь собирает конфиг niri. — Блокирует часть S8.

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
- VERIFIED (`niri validate` живого config.kdl, 2026-10-17) — отсутствующий `include optional=true` → только WARN «optional include not found», конфиг валиден.
- ОПРОВЕРГНУТО (живая сессия kurva-lenovo 2026-10-17 + niri 26.04 `docs/wiki/Window-Effects.md` «Xray», `Configuration:-Layer-Rules.md` «background-effect») — blur для layer-shell через layer-rule работает, но включает xray по умолчанию и действует на всю поверхность. Слой `caelestia-drawers` на весь выход (Top) → все не полноэкранные окна закрыты размытыми обоями; полноэкранные видны (рисуются над Top). Правило удалено из `nix/niri/caelestia.kdl` (U53). Фигурный blur возможен только через `ext-background-effect` от самого шелла — см. Q17.
- VERIFIED (живая сессия 2026-10-17, `niri msg --json version`) — `{"cli":"26.04 (Nixpkgs)","compositor":"26.04 (Nixpkgs)"}`, совпадает с фикстурами. Выходы: eDP-1 1920x1080 и DP-2 3440x1440 (второй монитор есть).

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
- ~~Известный долг: `actionPayload("switch-layout", …)` и generic-числовой аргумент~~ — 2026-10-16 S4-cpp: `SwitchLayout{layout:"Next"|"Prev"|{"Index":N}}` и `MoveWindowToWorkspace{window_id,reference:{Id},focus}` сверены с `niri-ipc/src/lib.rs` 26.4.0, покрыты тестами. Generic `{"id":N}` для прочих действий остаётся — новые действия добавлять только с тестом payload.

## Фикстуры (S2, записаны 2026-10-16)
Как записаны: `scripts/port/record-niri-fixtures.sh` — изолированный headless sway (pixman) → вложенный niri 26.04 (winit) с `tests/fixtures/niri/config.kdl`; к сессии пользователя не подключается (свой `XDG_RUNTIME_DIR`, сброшены `WAYLAND_DISPLAY`/`NIRI_SOCKET`/`DBUS_SESSION_BUS_ADDRESS`). Окна — `foot --app-id fixture-N sleep 3600`. Сценарии: idle, windows, workspaces, fullscreen, kb-switch, overview, config-reload.
- VERIFIED(fixture kb-switch) — **Q8**: `switch-layout` даёт только `KeyboardLayoutSwitched{idx}`, `KeyboardLayoutsChanged` не приходит. Баг форка воспроизведён: `replayFixtures(kb-switch)` падает (индекс остаётся 0) → исправление в S3c.
- VERIFIED(fixture fullscreen) — **Q3, данные для эвристики**: в настоящем фуллскрине `layout.window_size` и `tile_size` **в точности** равны логическому размеру выхода (1276×693; без фуллскрина 626×677). `toggle-windowed-fullscreen` в IPC никак не виден (layout не меняется). Флага в IPC нет. Решение по Q3 всё ещё за человеком.
- VERIFIED(fixtures) — event-stream при подключении сначала присылает полное состояние: `WorkspacesChanged, WindowsChanged, OverviewOpenedOrClosed, KeyboardLayoutsChanged, ConfigLoaded, CastsChanged`.
- VERIFIED(fixture overview) — при открытии overview приходит `WindowFocusChanged{id:null}`, при закрытии фокус возвращается (`WindowFocusChanged{id:3}`). UI, завязанный на фокусное окно, будет «мигать» на время overview.
- VERIFIED(fixture config-reload) — `load-config-file` даёт `ConfigLoaded{failed:false}`.
- VERIFIED(fixture windows) — смена фокуса и перестановка колонок дают `WorkspaceActiveWindowChanged` и `WindowLayoutsChanged`; новое окно — `WindowOpenedOrChanged`, закрытие — `WindowClosed`.
- VERIFIED(src niri 26.4.0: `src/layout/tile.rs:869`, `floating.rs:336`) — `tile_pos_in_workspace_view` заполняется только для плавающих окон; у тайловых всегда `null` (не особенность вложенной сессии). U62: в area picker привязка только к плавающим окнам. UNVERIFIED: координаты «workspace view» совпадают с локальными координатами экрана (struts/exclusive zone).
- UNVERIFIED(nested) — multi-monitor: у winit-бэкенда niri ровно один выход, сценарий в изоляции не записать.
- 2026-10-16 — S3c: ветка `OutputsChanged` удалена (события нет в niri 26.04). `Outputs` перезапрашивается при каждом `WorkspacesChanged`, если сокет подключён (воркспейсы меняются при hotplug выходов). UNVERIFIED: что niri шлёт `WorkspacesChanged` при hotplug — в изоляции не проверить (winit, один выход).
- 2026-10-16 — `ConfigLoaded{failed}` → сигнал `NiriIpc.configLoaded(bool failed)`. Он приходит и при каждом переподключении event-stream, поэтому потребители (GameMode, U47) должны быть идемпотентны.

## Шорткаты (S5b)
- VERIFIED(src niri-config 26.4.0, `binds.rs`) — у `Bind` нет триггера на отпускание клавиши. Upstream `launcher` (toggle on release + `launcherInterrupt`) на niri не воспроизводим → launcher по нажатию. Следствие вынужденное, не развилка.
- VERIFIED(`niri validate`) — `nix/niri/caelestia.kdl` валиден для niri 26.04.
- VERIFIED (живая сессия 2026-10-17) — `caelestia-shell ipc show` / `ipc call drawers list` / `isOpen launcher` попадают в запущенный инстанс сервиса.
- 2026-10-16 — `drawers toggle sidebar|utilities` не блокируется при фуллскрине (upstream-шорткаты блокировали). Оставлено как в upstream IPC, отличие записано в COMPOSITOR_API.md.

## Focus grab (S5c, U21/U29)
- 2026-10-16 — `HyprlandFocusGrab` эмулируется в `modules/drawers/ContentWindow.qml`: та же формула `active` (+ отсоединённый popout вместо отдельного grab в `bar/popouts/Wrapper.qml`); пока активен — `keyboardFocus: Exclusive` и маска ввода на весь экран; нажатие вне бара/рамки/детей `Panels` вызывает тот же сброс, что `onCleared` в upstream. Форк grab не реализовывал (TODO в `fork-legacy:modules/drawers/Drawers.qml:65`). Вынужденное следствие (протокола нет), не развилка.
- Отличия от Hyprland: (1) нажатие вне панелей поглощается шеллом и не доходит до окна под курсором; (2) пока grab активен, hover/scroll по окнам приложений недоступны; (3) «внутри» = bounding box детей `Panels` (обёртки могут быть чуть больше видимой панели).
- UNVERIFIED — niri отдаёт клавиатуру layer-surface `Top` с `Exclusive` (ожидается по протоколу) и возвращает фокус окну после снятия. UNVERIFIED — отсоединённый popout: `Binding` в Wrapper.qml переопределяет фокус на `OnDemand`; получает ли он клавиатуру без клика на niri. → VERIFY.md.

## Бар: активное окно, статус, раскладки (S6c)
- 2026-10-16 — U28: `KbLayoutModel` берёт список/индекс раскладок из niri (`Compositor.kbLayouts/kbLayoutIndex`), переключение — `SwitchLayout{Index}`. Разбор xkb XML через `xmllint /usr/share/X11/...` удалён: niri отдаёт полные имена, код — `Compositor.kbCode` (base.lst из `CAELESTIA_XKB_RULES_PATH`). Дедупликация убрана — индексы обязаны совпадать с индексами niri. fhs-allowlist → 0.
- 2026-10-16 — U26: заголовок/иконка из `Compositor.activeToplevel` (`title`, `app_id`); живое превью скрыто флагом `supports.toplevelCapture` (false) до решения Q9.

## S7: idle, яркость
- VERIFIED(fixture outputs.json) — у выхода niri нет числового `id` (поля: name, make, model, serial, logical, modes, …). `Brightness.getMonitor("id:N")` на niri ничего не находит; `model:`/`serial:`/имя работают.
- 2026-10-16 — U56: строковые idle-действия из конфига: `"dpms off"`/`"dpms on"` → `power-off-monitors`/`power-on-monitors`; прочие строки были командами диспетчера Hyprland — на niri предупреждение в лог, без действия. UNVERIFIED: `power-on-monitors` по `returnAction` (niri и так будит мониторы при вводе) → VERIFY.md.
- 2026-10-16 — U53 (часть «layerrule»): `Colours.reloadHyprRules` — no-op (вызовы и таймеры сохранены ради минимального диффа), `Connections` к `configReloaded` удалён. VERIFIED(src niri-config 26.4.0 `layer_rule.rs`, `niri validate`): `layer-rule { match namespace="^caelestia-drawers$"; background-effect { blur true } }` — пример в `nix/niri/caelestia.kdl`. Аналога `ignore_alpha` нет. `setMode` через `caelestia scheme` CLI не тронут — аудит CLI (U36/U53/U54) за человеком.

## windowinfo (S7, U49)
- 2026-10-16 — Details: `address` → id окна niri; позиция — только для плавающих (`tile_pos_in_workspace_view`); монитор — выход воркспейса окна, вместо числового id — `model` (id у выходов нет); строки «Initial title/class», «Xwayland», «Pinned» скрыты (полей нет в niri 26.04, фикстура windows.json); фуллскрин — эвристика Q3, «maximised» неразличим.
- 2026-10-16 — Buttons: сетка 10 номеров → существующие воркспейсы выхода окна (`workspacesFor`), перенос по `{Id}`; «Pin» скрыт `supports.windowPin`; «Kill» → `close-window` (Q16).
- Preview: захват выключен до Q9 (`captureSource: null`).
- Q13 (объединение с NiriThing) не затронут — это S10.

## Упаковка (S8)
- 2026-10-16 — `nix/default.nix`: `hyprland` убран из аргументов и runtimeDeps; `niri` в runtimeDeps не нужен — шелл не вызывает CLI niri, только сокет `$NIRI_SOCKET`. Замыкание `nix build .#default` не содержит путей hyprland (`nix path-info -r ./result`). `CAELESTIA_XKB_RULES_PATH` уже задаётся обёрткой.
- VERIFIED(src niri 26.4.0 `src/main.rs:277-290`) — niri с feature `systemd` делает `systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE NIRI_SOCKET`, поэтому user-сервис `caelestia` из hm-module получает `NIRI_SOCKET` без изменений модуля. VERIFIED (живая сессия 2026-10-17): `systemctl --user show-environment` содержит `NIRI_SOCKET=/run/user/1000/niri.wayland-1.<pid>.sock`.

## Воркспейсы бара (S6b, по Q2=a, Q5=a, Q7)
- 2026-10-17 — «Номер» воркспейса в баре = `idx` на выходе этого бара; клик фокусирует по `{Id}` (ссылка `{Index}` разрешается на сфокусированном выходе — для бара другого монитора было бы неверно); позиция за пределами существующих → последний (всегда пустой) воркспейс выхода. `SpecialWorkspaces.qml` удалён, оверлей спецворкспейсов убран; в Nexus скрыты «Per monitor» и «Windows on special workspaces».
- 2026-10-17 — Q7: новый ключ `bar.workspaces.ignoredWindows` (QStringList, по умолчанию пусто; точное совпадение или `^…$`-regex по `app_id` или `title`), `ignoredTags` на niri не используется. `Compositor.toplevelsForWs(wsId, ignoredWindows)`, `isWindowIgnored`, `workspaceAt(output, idx)`.
- Иконки воркспейсов (`workspaceIcons`) матчатся по имени именованного воркспейса niri, у безымянных — по позиции (как числовые имена в upstream).

## GameMode (U47, Q15 = a)
- 2026-10-17 — `Compositor.setGameMode(on)` пишет `$XDG_CONFIG_HOME/niri/caelestia-gamemode.kdl` (первая строка — маркер on/off) и после записи делает `load-config-file`; `Compositor.gameMode` читается из файла (FileView, watchChanges). Пользователь подключает **в конце** своего `niri.kdl`: `include optional=true "caelestia-gamemode.kdl"`.
- VERIFIED(src niri-config 26.4.0 `lib.rs`: include с `optional`, части сливаются через `merge_with`; `niri validate` на конфиге с включённым/выключенным файлом и отсутствующим optional-include) — валидно. Содержимое: `animations { off }`, `blur { off }`, `layout { gaps 0; focus-ring { off }; border { width 1 }; shadow { off } }`, `window-rule { geometry-corner-radius 0 }`.
- VERIFIED(src) — опции tearing в niri-config 26.4.0 нет; `allow_tearing` не переносится.
- UNVERIFIED — что поздний `window-rule { geometry-corner-radius 0 }` перебивает скругление из правил пользователя, и что `border { width 1 }` не включает рамку, если пользователь её выключил (`off` в его конфиге) → VERIFY.md.

## Smoke-запуск (L3a, 2026-10-17)
- `scripts/port/smoke-shell.sh` — сборка `./result` запускается во вложенной изолированной сессии (headless sway → niri winit, временный HOME). Результат: `Configuration Loaded`, QML-ошибок (TypeError/ReferenceError/не найденных типов) нет.
- VERIFIED(src niri 26.4.0 `src/backend/winit.rs:198-206`) — winit-бэкенд без DRM-ноды отдаёт linux-dmabuf v3; quickshell 0.3.2 вызывает `get_default_feedback` (нужен v4) и падает сразу после загрузки. Это ограничение тестового окружения (tty-бэкенд на железе отдаёт v4+ с feedback), поэтому IPC-вызовы в изоляции не проверить.

## hm-module (S8, Q-NIX1 = c, Q-NIX2)
- 2026-10-17 — `programs.caelestia.settingsMode = "managed" | "seed"` (по умолчанию managed — как upstream). seed: `home.activation.caelestiaSeedSettings` (после `linkGeneration`) копирует сгенерированный JSON, если файла нет; оставшийся симлинк в `/nix/store` от managed заменяется копией. Restart-trigger сервиса — только в managed.
- 2026-10-17 — `programs.caelestia.niri.enable` пишет `~/.config/niri/caelestia.kdl` из `nix/niri/caelestia.kdl` (опция `niri.config` для своей версии); `spawn "caelestia-shell"` заменяется абсолютным путём бинаря пакета, чтобы IPC попадал в инстанс этого пакета. Внутри — бинды (layer-rule blur удалён 2026-10-17, см. «ОПРОВЕРГНУТО» выше) и последним `include optional=true "caelestia-gamemode.kdl"`. Пример перенесён из `docs/port/niri-binds.example.kdl` в `nix/niri/caelestia.kdl` (единый источник).
- VERIFIED(src niri-config 26.4.0 `lib.rs`: база include = `path.parent()` без canonicalize) — относительный include из симлинка `~/.config/niri/caelestia.kdl` ищется в `~/.config/niri`, а не в `/nix/store`.
- VERIFIED(eval) — модуль вычислен в `home-manager` (github master) для обоих режимов; сгенерированный KDL проходит `niri validate`.
- UNVERIFIED — gpu-screen-recorder на NixOS: захват монитора (`-w <выход>`) идёт через KMS и требует `gsr-kms-server` с capability; NixOS-модуль `programs.gpu-screen-recorder.enable = true` ставит wrapper. Без него вероятен отказ/запрос пароля. Проверить вживую (VERIFY.md → U45).
- 2026-10-19 — U41: после ~3 блокировок экран блокировки «лагает»: значок замка застревает в начальной анимации, фон пустой, сквозь прозрачную поверхность виден красный фон заблокированной сессии niri (niri FAQ). Исправление агента: поверхность блокировки непрозрачная (`m3surface`), фон на niri — обои вместо `ScreencopyView` (`Compositor.supports.lockScreencopy: false`). UNVERIFIED — причина зависания: захват экрана, который Quickshell запрашивает до подтверждения блокировки (`session_lock.cpp`, `updateSurfaces(false)` перед `manager->lock()`); журнал человека не смотрели. Проверить: 5+ блокировок подряд без лагов. Если лаги останутся — нужен `journalctl --user -u caelestia`.
