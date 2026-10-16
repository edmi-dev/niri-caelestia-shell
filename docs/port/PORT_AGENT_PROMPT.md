# Промпт агента: перенос caelestia-shell (upstream) на niri

> **Как пользоваться**
> 1. Положи `UPDATE_PLAN.md` в репозиторий по пути `docs/port/UPDATE_PLAN.md` (агент создаст каталог в шаге S0, если его нет).
> 2. Первая сессия: отдай агенту целиком раздел «ПРОМПТ» ниже.
> 3. Каждая следующая сессия, в том числе после того как кончились токены: «Продолжай перенос. Протокол возобновления — в AGENTS.md». Агент сам прочитает `AGENTS.md` и `docs/port/STATE.md` и продолжит с записанного «следующего действия».
> 4. Места, где нужен ты, агент помечает в `STATE.md` как `NEEDS-HUMAN`: запуск в живой сессии niri, `nixos-rebuild switch`, архитектурные решения.

---

## ПРОМПТ

### Роль

Ты — инженер, который переносит Wayland-оболочку **caelestia-shell** (Quickshell/QML + C++-плагин, Qt 6, CMake, Nix flake) с **Hyprland** на **niri**. Ты знаешь niri IPC: `niri msg`, `niri msg --json`, `niri msg --json event-stream`, сокет `$NIRI_SOCKET`, действия (`Action`) и события (`Event`). Ты работаешь на **NixOS**: всё собирается и запускается через flake, без FHS-допущений.

Работа длинная и растянется на десятки сессий. Контекст и токены могут кончиться в любой момент. Поэтому **состояние живёт в репозитории, а не в твоей памяти**.

### Цель

Ветка `niri-v2` в репозитории `edmi-dev/niri-caelestia-shell` должна содержать **текущий upstream `caelestia-dots/shell`**, который:
- собирается `nix build` и проходит `nix flake check`;
- работает на niri без Hyprland: Hyprland-код удалён или заменён;
- минимально расходится с upstream, чтобы будущие обновления подтягивались через `git merge upstream/main`;
- подключается к системному flake пользователя через input `niri-caelestia-src` (Home Manager, хост `kurva-lenovo`).

Доработки старого форка (manga/novel, quicktoggles, Control Center и т. п.) **не входят** в основную цель. Это опциональный шаг S10 — только по явному списку от человека.

### Источники

| Что | Где |
|---|---|
| План, анализ, таблица соответствий, ID изменений (U01…U64, F01…F15, Q1…Q15) | `docs/port/UPDATE_PLAN.md`. Не перечитывай целиком: ищи по ID (`rg -n 'U24' docs/port/UPDATE_PLAN.md`) |
| Upstream | remote `upstream` → `https://github.com/caelestia-dots/shell` |
| Старый форк (донор кода под niri) | ветка `fork-legacy` в этом же репо. Читай через `git show fork-legacy:<path>`, **не копируй дерево целиком** |
| Ключевой донор | `fork-legacy:plugin/src/Caelestia/Internal/{niriipc,nirisocket}.{hpp,cpp}`, `fork-legacy:services/Niri.qml` |

### Незыблемые правила

1. **Никакого Hyprland.** Без `Quickshell.Hyprland`, `Hyprland*` типов, `hyprctl`, `HyprlandFocusGrab`, `GlobalShortcut`, `Hypr.*` и без «шима», который имитирует объекты Hyprland. Всё, у чего нет аналога в niri, отключается через флаг возможностей (см. «Архитектура»), а не эмулируется молча.
2. **Не додумывай поведение niri.** Если не уверен, что поле, событие или действие существует, сначала проверь по фикстурам в `tests/fixtures/niri/` или через `niri msg --help` / `niri msg action --help` в devShell. Если проверить нельзя, пометь `UNVERIFIED` в `docs/port/DECISIONS.md` и в коде (`// NIRI-PORT(...): UNVERIFIED ...`).
3. **Минимальный дифф к upstream.** Не переименовывай и не переформатируй upstream-файлы и не перемещай код без нужды. Каждое изменённое место в upstream-коде помечай комментарием `// NIRI-PORT(<ID>): <почему>` (в QML и C++ одинаково). Так при следующем merge сразу видно, что наше.
4. **Атомарные задачи.** Одна задача — один ID или его часть, ≤ ~10 файлов, заканчивается коммитом и обновлением `STATE.md`. Не начинай следующую задачу, пока не закоммитил текущую.
5. **NixOS-правила** (раздел «NixOS»): только `nix develop -c …` / `nix build`; никаких `pip install`, `sudo`, записи в `/usr`, `nixos-rebuild switch`, `home-manager switch`. Системные переключения делает человек.
6. **Новые утилиты и скрипты — на bash или Go.** Python не писать. Существующие upstream-скрипты на Python не трогать.
7. **Решения человека не принимай сам.** Вопросы Q1–Q15 из плана и любые новые развилки записывай в `DECISIONS.md` со статусом `PENDING`, задачу помечай `BLOCKED(Qn)` и бери следующую незаблокированную.
8. Код, комментарии и сообщения коммитов — на английском. Файлы в `docs/port/` и отчёты человеку — на русском.

### Протокол возобновления (выполнять в начале КАЖДОЙ сессии)

1. `cat AGENTS.md docs/port/STATE.md`. Больше ничего заранее не читать.
2. `git status && git log --oneline -15`. Если есть незакоммиченные изменения — разберись по `STATE.md → In progress`: доделай или откати (`git stash`), затем запиши, что сделал.
3. Возьми **Next action** из `STATE.md` и выполни его.
4. Читай только файлы текущей задачи. Большие файлы — по диапазонам строк (`sed -n` / Read с offset), поиск — через `rg`. Широкий поиск по репозиторию отдавай саб-агенту, если он есть, и забирай только вывод.

### Протокол контрольной точки (после каждой задачи и перед любой долгой операцией)

1. Прогнать проверки уровня задачи (см. «Уровни проверки»).
2. `git add -A && git commit -m "port(<ID>): <summary>"`. Незаконченную работу при угрозе обрыва коммить как `wip(<ID>): …`.
3. Обновить `docs/port/STATE.md`: текущий шаг, сделанное, **одно конкретное следующее действие** (команда или файл:строка), блокеры. Держи файл ≤ 120 строк. Закрытые пункты переноси в `docs/port/journal/YYYY-MM-DD.md`.
4. Отметить задачу в `docs/port/TASKS.md`.
5. Если чувствуешь, что контекст переполнен (много прочитанного, долгая сессия), сделай контрольную точку и предложи человеку новую сессию. Не жди обрыва.

### Уровни проверки

| Уровень | Что | Кто может |
|---|---|---|
| L0 | `scripts/port/check-boundary.sh`, `scripts/port/check-fhs.sh`, `qmllint` по изменённым файлам | агент |
| L1 | `nix build -L .#default` (и `cmake --build build` в devShell для быстрых итераций) | агент |
| L2 | `ctest --test-dir build` — юнит-тесты niri-модуля на записанных фикстурах | агент |
| L3a | Вложенный niri: из графической сессии `niri` запускается окном; внутри — собранный шелл. Работает, только если агент запущен на машине пользователя с дисплеем. **Проверь на практике, прежде чем на это опираться** | агент (если есть дисплей) |
| L3b | Живая сессия niri пользователя: чек-лист с точными командами, которые агент кладёт в `docs/port/VERIFY.md` | **человек** |

Задача с поведением в рантайме не закрывается на L1–L2. Она получает статус `DONE(L2), NEEDS-HUMAN(L3b)`, а в `VERIFY.md` добавляется пункт.

---

### Архитектура (держать агент-френдли)

**1. Единственная граница с композитором.**

```
plugin/src/Caelestia/Niri/          # C++ модуль Caelestia.Niri (из fork-legacy Internal/niri*)
  nirisocket.{hpp,cpp}              # транспорт: event-stream + request-сокет
  niriipc.{hpp,cpp}                 # состояние: outputs/workspaces/windows/keyboard, actions
plugin/tests/niri/                  # QtTest: подаём JSON фикстур, проверяем модель
tests/fixtures/niri/                # записанные ответы niri msg --json и event-stream
services/Compositor.qml             # ЕДИНСТВЕННЫЙ QML-файл, который знает про NiriIpc
docs/port/COMPOSITOR_API.md         # контракт Compositor.qml (свойства, функции, сигналы, флаги)
```

- **Весь** остальной QML ходит только в `Compositor.*`. Прямой `NiriIpc` за пределами `services/Compositor.qml` запрещён; это проверяется скриптом.
- В `Compositor.qml` есть объект возможностей:
  `readonly property QtObject supports: QtObject { readonly property bool specialWorkspaces: false; readonly property bool focusGrab: false; readonly property bool globalShortcuts: false; readonly property bool runtimeOptions: false; readonly property bool windowTags: false; readonly property bool cursorPos: false; readonly property bool fullscreenFlag: <по фикстурам>; readonly property bool toplevelCapture: <проверить> }`.
  UI скрывает функции по этим флагам, без разбросанных `if niri`.
- API нейтральный, без слов Hyprland. Ориентировочный состав (уточнить по реальным местам вызова в S4): `outputs`, `focusedOutput`, `outputForScreen(screen)`, `workspacesForOutput(name)`, `activeWorkspace(output)`, `focusWorkspace(ws)`, `focusWorkspaceRelative(±1)`, `windows`, `windowsForWorkspace(id)`, `focusedWindow`, `hasFullscreen(output)`, `moveWindowToWorkspace(winId, ws)`, `kbLayouts`, `kbLayoutIndex`, `kbLayout`, `kbLayoutFull`, `switchKbLayout(idx)`, `capsLock`, `numLock`, `powerOffMonitors()`, `quit()`, сигнал `configReloaded`.
- Upstream-файл `services/Hypr.qml` удаляется. Места вызова меняются `Hypr.x` → `Compositor.y` с маркером `NIRI-PORT`.

**2. Скрипты-проверки** (`scripts/port/`, bash, `set -euo pipefail`, работают в `nix develop`):

- `check-boundary.sh` — падает, если найдено `Quickshell.Hyprland|Hyprland[A-Z]|\bHypr\.|hyprctl|GlobalShortcut|HyprlandFocusGrab` в любом файле, или `NiriIpc` вне `services/Compositor.qml` и `plugin/src/Caelestia/Niri/`. Есть временный allowlist `scripts/port/boundary-allowlist.txt` с ещё не перенесёнными файлами. **Число строк в нём — главная метрика прогресса**, к концу S7 оно должно стать 0.
- `check-fhs.sh` — падает на `/usr/`, `/bin/bash`, `/etc/` в QML, C++ и скриптах (кроме разрешённых fallback-ов после `Quickshell.env(...) ||`).
- `record-niri-fixtures.sh` — запускается человеком в живой сессии niri. Пишет `niri msg --json {version,outputs,workspaces,windows,focused-window,keyboard-layouts}` и ~30 с `niri msg --json event-stream` в `tests/fixtures/niri/<сценарий>/`. Сценарии: `idle`, `fullscreen` (окно в `fullscreen-window`), `kb-switch`, `multi-monitor` (если есть второй монитор), `overview`.
- `divergence.sh` — выводит все `NIRI-PORT(...)` маркеры по ID; используется при синхронизации с upstream.
- (опционально, Go) `tools/niri-replay/` — фейковый `$NIRI_SOCKET`, который проигрывает фикстуры для L3a и отладки без реального niri.

**3. Файлы состояния** (`docs/port/`):

| Файл | Назначение | Размер |
|---|---|---|
| `STATE.md` | Текущий шаг, In progress, **Next action**, блокеры, NEEDS-HUMAN | ≤ 120 строк |
| `TASKS.md` | Чек-лист по шагам S0–S11 с ID из плана; статусы `TODO / WIP / DONE(Lx) / BLOCKED(Qn) / NEEDS-HUMAN` | — |
| `DECISIONS.md` | Журнал решений: `Qn — PENDING/DECIDED — кто — суть — последствия`; `UNVERIFIED`-факты о niri | — |
| `COMPOSITOR_API.md` | Контракт `Compositor.qml` и таблица «upstream Hypr.* → Compositor.* → niri IPC» | — |
| `VERIFY.md` | Чек-лист для человека (L3b): команда → ожидаемый результат → [ ] | — |
| `journal/*.md` | Архив закрытых пунктов STATE по датам | — |

**4. `AGENTS.md`** в корне (≤ 80 строк) и `CLAUDE.md` с одной строкой `@AGENTS.md`. Содержимое: цель в 3 строках; карта репозитория (где граница, где состояние); протоколы возобновления и контрольной точки (кратко, со ссылкой на этот промпт в `docs/port/PORT_AGENT_PROMPT.md`); команды сборки, тестов и проверок; незыблемые правила 1–8 одной строкой каждое.

---

### NixOS

- **Всё через flake.** В upstream уже есть `devShells.default` и `.envrc` (direnv): он собирает в `build/` и экспортирует `CAELESTIA_LIB_DIR`, `QML2_IMPORT_PATH`. Добавь в devShell: `niri` (для `niri msg`, `niri validate`), `jq`, `ripgrep`, `libxml2` (`xmllint`), `qt6.qtdeclarative` (`qmllint`), `clang-tools`. Не добавляй `hyprland`.
- **Команды:** быстрая итерация — `nix develop -c bash -c 'cmake --build build && ctest --test-dir build'`; полная — `nix build -L .#default`; гейт — `nix flake check -L`.
- **`flake.nix → checks.<system>`:** `package` (сборка), `boundary` (`check-boundary.sh`), `fhs` (`check-fhs.sh`), `unit` (ctest). Каждая проверка — `runCommand`, падает с понятным сообщением.
- **Пакет (`nix/default.nix`):** убрать `hyprland` из `runtimeDeps`. Добавить `niri` (для `niri msg` в рантайме) и то, что понадобится по решениям (`gpu-screen-recorder`, `slurp`, `libxml2`…). Пути к данным — только через переменные окружения в `makeWrapper`, по образцу существующего `CAELESTIA_XKB_RULES_PATH`.
- **Известные FHS-ловушки upstream:**
  - `modules/bar/popouts/kblayout/KbLayoutModel.qml:141,152` жёстко читает `/usr/share/X11/xkb/rules/{base,evdev}.xml` → брать каталог из `CAELESTIA_XKB_RULES_PATH` (`${xkeyboard-config}/share/xkeyboard-config-2/rules/`).
  - `utils/Paths.qml:24` fallback `/usr/lib/caelestia` — допустим, потому что wrapper ставит `CAELESTIA_LIB_DIR`.
- **Home Manager (`nix/hm-module.nix`):**
  - Upstream пишет `caelestia/shell.json` через `xdg.configFile`, то есть **read-only симлинк в store**. Тогда сохранение настроек из UI (атомарная запись в C++ `Settings`) упадёт. Это вопрос `Q-NIX1` для человека: (a) оставить как есть, (b) режим «seed» — активационный скрипт копирует сгенерированный JSON, только если файла нет, (c) оба режима через опцию.
  - GameMode (U47) генерирует `~/.config/niri/…/gamemode.kdl`. Этот файл **не должен** управляться HM. Активационный скрипт создаёт пустой файл, если его нет (`include` в niri на отсутствующий файл — проверить поведение). То же касается `colors.kdl`, если цвета будут писаться в конфиг niri.
  - Опционально: опция модуля генерирует KDL-сниппет биндов `spawn "caelestia-shell" "ipc" "call" …` для `include` в конфиг niri. Не трогай, как пользователь собирает конфиг niri, — спроси (`Q-NIX2`).
  - Systemd user-сервис: убедиться, что в окружении сервиса есть `NIRI_SOCKET` (`systemctl --user show-environment | rg NIRI_SOCKET` — пункт для VERIFY), и что сервис привязан к `graphical-session.target` niri.
- **Интеграция в системный flake** (только сборка, без switch): `nixos-rebuild build --flake <путь>#kurva-lenovo --override-input niri-caelestia-src path:<путь к checkout>`. Путь к системному flake спроси у человека. Сам файл системного flake без разрешения не редактируй.

---

### Шаги

Каждый шаг рассчитан на 1–2 сессии. Большие шаги разбиты на подшаги, и каждый подшаг заканчивается коммитом. Порядок строгий, кроме пометок «параллельно».

#### S0. Бутстрап репозитория и инфраструктуры агента
- **Действия:**
  - Клон `edmi-dev/niri-caelestia-shell`; текущий `main` сохранить как ветку `fork-legacy`.
  - `git remote add upstream https://github.com/caelestia-dots/shell && git fetch upstream`; `git switch -c niri-v2 upstream/main`.
  - Создать `docs/port/{STATE,TASKS,DECISIONS,COMPOSITOR_API,VERIFY}.md`, `docs/port/journal/`, `AGENTS.md`, `CLAUDE.md`; скопировать этот промпт в `docs/port/PORT_AGENT_PROMPT.md`.
  - Заполнить `TASKS.md` шагами S0–S11 с ID из `UPDATE_PLAN.md`, `DECISIONS.md` — вопросами Q1–Q15 и Q-NIX1/Q-NIX2 со статусом `PENDING`. Q1 уже решён: «перенос upstream на niri».
  - Записать в `STATE.md` хеш `upstream/main`, от которого начали.
- **Готово:** коммит `port(S0): bootstrap agent infrastructure`, push ветки (если есть права; иначе NEEDS-HUMAN).

#### S1. Базовая сборка upstream на NixOS (без изменений кода)
- **Действия:** `nix build -L .#default` на чистом upstream. Зафиксировать, что собирается; ошибки окружения записать в DECISIONS. Добавить в devShell инструменты из раздела NixOS. Создать скелет `checks` во flake (пока только `package`).
- **Проверка:** L1.
- **Готово:** известная рабочая точка отсчёта; коммит.

#### S2. Скрипты-проверки и фикстуры niri
- **Действия:** написать `check-boundary.sh` (allowlist = все текущие нарушения, сгенерировать автоматически), `check-fhs.sh`, `divergence.sh`, `record-niri-fixtures.sh`. Подключить первые два в `checks`.
- **NEEDS-HUMAN:** запустить `record-niri-fixtures.sh` в живой сессии niri по всем сценариям и закоммитить фикстуры (или дать агенту их сделать, если он работает на машине пользователя).
- **По фикстурам ответить и записать в DECISIONS:** есть ли у окна признак фуллскрина (Q3); какое событие приходит при переключении раскладки — `KeyboardLayoutSwitched` (Q8); есть ли событие изменения выходов; есть ли `layout.tile_pos_in_workspace_view`; версия niri.
- **Параллельно:** пока фикстур нет, переходи к S3 с синтетическими примерами, помеченными `synthetic`.

#### S3. C++ модуль `Caelestia.Niri`
- **S3a.** Перенести `nirisocket` и `niriipc` из `fork-legacy` в `plugin/src/Caelestia/Niri/`, оформить через upstream-функцию `qml_module` (URI `Caelestia.Niri`), удалить `hyprextras.*` и `hyprdevices.*` из `plugin/src/Caelestia/Services/CMakeLists.txt` и с диска. Собрать под строгие флаги upstream (`-Wconversion -Wshadow …`) и починить предупреждения. → L1.
- **S3b.** QtTest в `plugin/tests/niri/`: скормить фикстуры парсеру событий и проверить модели (воркспейсы по выходам, активный ws, фокус окна, сортировка по `pos_in_scrolling_layout`, раскладки). Подключить в CMake (`enable_testing`) и в `checks.unit`. → L2.
- **S3c.** Добавить недостающее: `KeyboardLayoutSwitched`, `ConfigLoaded` → сигнал, `WorkspaceActiveWindowChanged`. Ветку `OutputsChanged` исправить или удалить по фикстурам (если такого события нет — переопрашивать `Outputs` по `WorkspacesChanged`). Признак фуллскрина — по решению Q3. Каждое добавление — с тестом. → L2.

#### S4. Фасад `services/Compositor.qml`
- **Действия:** `rg -n '\bHypr\.' --type-add 'qml:*.qml' -t qml` — собрать все места вызова в таблицу в `COMPOSITOR_API.md` (вызов → файл:строка → функция Compositor → действие или событие niri → U-ID). Реализовать `Compositor.qml` по таблице плюс объект `supports`. Удалить `services/Hypr.qml`. Документировать каждую функцию в `COMPOSITOR_API.md`.
- **Проверка:** L0 (allowlist ещё полон, это ожидаемо), L1. Отдельно — маленький QML-тест или временный `qs`-скрипт, который печатает `Compositor.workspacesForOutput(...)` в L3a/L3b.

#### S5. Каркас оболочки
- **S5a. Состояние экранов (U20).** `services/ShellState.qml` `forActive()`/`componentsForActive()` → `Compositor.focusedOutput`; `services/Screens.qml`, `components/ScreenState.qml` — без изменений, если не требуется.
- **S5b. Шорткаты (U18, U51).** Удалить `components/misc/CustomShortcut.qml`; каждый `CustomShortcut` в `modules/Shortcuts.qml` и других файлах заменить на функцию `IpcHandler` с тем же смыслом. Список целей и функций записать в `COMPOSITOR_API.md → IPC`. Сгенерировать пример KDL-биндов в `nix/niri/caelestia.kdl`.
- **S5c. Окно drawers (U21).** `modules/drawers/ContentWindow.qml`: монитор → `Compositor.outputForScreen(screen)`; спецворкспейс → убрать по `supports.specialWorkspaces`; фуллскрин → `Compositor.hasFullscreen(output)`; `HyprlandFocusGrab` → `WlrLayershell.keyboardFocus` (Exclusive/OnDemand) + закрытие по клику вне области. Образец обходного пути — `git show fork-legacy:modules/drawers/Drawers.qml` (строка ~32). То же в `modules/bar/popouts/Wrapper.qml`.
- **Проверка:** L0 (allowlist уменьшился), L1, L3 из VERIFY: панели открываются и закрываются, Esc и клик вне закрывают, фокус не залипает, рамка исчезает при фуллскрине.

#### S6. Бар
- **S6a (U23).** `modules/bar/Bar.qml` `handleWheel` → `Compositor.focusWorkspaceRelative(±1)`.
- **S6b (U24).** `modules/bar/components/workspaces/{Workspaces,Workspace}.qml`: источники → `Compositor.workspacesForOutput`, `windowsForWorkspace`; `ignoredTags` → по решению Q7; `perMonitor` → по решению Q5. `SpecialWorkspaces.qml` (U25) — не загружать при `!supports.specialWorkspaces` (не удалять файл, чтобы не расходиться с upstream).
- **S6c (U26, U27, U28).** Активное окно, статус-иконки, Caps/Num, popout раскладок: `hyprctl switchxkblayout` → `Compositor.switchKbLayout(idx)`; xkb-пути — через env (NixOS). Превью окна — только если `supports.toplevelCapture` (Q9).
- **Проверка:** L0, L1, L2 и пункты VERIFY: воркспейсы совпадают с `niri msg --json workspaces` по выходам; клик и скролл; заголовок активного окна; раскладка обновляется после `niri msg action switch-layout next`.

#### S7. Остальные места, зависящие от композитора
По одной задаче на ID, в таком порядке: U42 (уведомления и фуллскрин) → U52 (Visualiser autoHide) → U56 (IdleMonitors: `dpms off` → `Compositor.powerOffMonitors()`, проверить `power-on-monitors`) → U49 (windowinfo) → U62 (areapicker: `hyprctl cursorpos`, `Hypr.options` — по `supports`) → U53/U54/U36 (**сначала** аудит `caelestia-cli`: использует ли `scheme`, `wallpaper`, `record` Hyprland; результат — в DECISIONS, решение за человеком) → U45 (Recorder) → U47 (GameMode через генерируемый include-KDL, состояние — по наличию файла, повторное применение по `configReloaded`).
- **Готово:** `boundary-allowlist.txt` пуст, `nix flake check` зелёный, все B-пункты либо `DONE`, либо `BLOCKED(Qn)` с записью.

#### S8. Упаковка под NixOS
- **Действия:** `nix/default.nix` (runtime-зависимости, env-пути, без hyprland); `check-fhs.sh` зелёный; `nix/hm-module.nix` по решениям Q-NIX1/Q-NIX2 (`shell.json`, mutable-файлы niri, опционально бинды); `NIRI_SOCKET` в окружении user-сервиса. Обновить README: зависимости, бинды niri, отличия от upstream.
- **Проверка:** `nix flake check -L`; `nix build .#default`; в VERIFY — запуск сервиса.

#### S9. Интеграция в систему пользователя (NEEDS-HUMAN на switch)
- **Действия:** спросить путь к системному flake. `nixos-rebuild build --flake <flake>#kurva-lenovo --override-input niri-caelestia-src path:$PWD`. Если сборка не проходит — чинить в репо шелла, а системный flake править только с разрешения. Подготовить в VERIFY финальный чек-лист сессии niri (все пункты S5–S8).
- **Человек:** `switch`, прогон VERIFY, отметки. Найденное агент заводит задачами `FIX-n` в TASKS.

#### S10. (Опционально) Перенос доработок старого форка
Только по списку от человека (F02, F05, F06, …). Одна F на задачу. Код берётся из `fork-legacy` через `git show` и **переписывается под API upstream** (`Caelestia.Config`, `Tokens`, `Tr.tr`, `Compositor`), а не копируется. Новые модули форка кладутся в отдельные каталоги (`modules/<name>/`), чтобы не увеличивать дифф с upstream.

#### S11. Процедура синхронизации с upstream
Написать `docs/port/UPSTREAM_SYNC.md`: `git fetch upstream && git merge upstream/main` → `check-boundary.sh` покажет новые обращения к Hyprland → `divergence.sh` покажет наши маркеры в изменённых upstream-файлах → чинить → `nix flake check`. Попробовать процедуру на свежем upstream и записать результат.

---

### Формат отчёта человеку (в конце каждой сессии, кратко, по-русски)

1. Что сделано (ID, коммиты).
2. Метрика: строк в `boundary-allowlist.txt` было → стало; статус `nix flake check`.
3. Что нужно от человека: NEEDS-HUMAN и PENDING-решения, с вариантами.
4. Next action — та же строка, что в `STATE.md`.

### Шаблон `docs/port/STATE.md`

```markdown
# Port state
Upstream base: <hash>   Branch: niri-v2   Updated: <date>

## Current step
S5c — ContentWindow (U21)

## In progress
- [x] monitor → Compositor.outputForScreen
- [ ] HyprlandFocusGrab → keyboardFocus + click-outside   (modules/drawers/ContentWindow.qml:112)

## Next action
Replace HyprlandFocusGrab block at modules/drawers/ContentWindow.qml:112 using pattern from
`git show fork-legacy:modules/drawers/Drawers.qml` (~L32); then `nix develop -c cmake --build build`.

## Metrics
boundary-allowlist: 17 lines · flake check: red (boundary)

## Blocked / pending decisions
- Q3 fullscreen flag — waiting for fixtures (NEEDS-HUMAN: run scripts/port/record-niri-fixtures.sh)

## Needs human
- VERIFY.md items 4–7 (panels focus behaviour)
```
