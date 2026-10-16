# Задачи переноса

Статусы: `TODO` / `WIP` / `DONE(Lx)` / `BLOCKED(Qn)` / `NEEDS-HUMAN`.
ID — из `UPDATE_PLAN.md` (U01…U64, F01…F15, Q1…Q15). Шаги — из `PORT_AGENT_PROMPT.md`.

## S0. Бутстрап
- [x] Ветки `fork-legacy`, `niri-v2`, remote `upstream` — DONE (человек)
- [x] `docs/port/{STATE,TASKS,DECISIONS,COMPOSITOR_API,VERIFY}.md`, `journal/`, `AGENTS.md`, `CLAUDE.md` — DONE(L0)
- [x] Коммит `port(S0): bootstrap agent infrastructure` — DONE
- [ ] Push `niri-v2` — см. STATE

## S1. Базовая сборка upstream (U01, U02)
- [x] `nix build -L .#default` на чистом upstream — DONE(L1)
- [x] devShell: `niri`, `jq`, `ripgrep`, `libxml2`, `qt6.qtdeclarative`, `clang-tools` — DONE(L1)
- [x] `flake.nix → checks.<system>.package` — DONE(L1), `nix flake check` зелёный (x86_64-linux)

## S2. Скрипты-проверки и фикстуры
- [x] `scripts/port/check-boundary.sh` + авто-allowlist (33 файла) — DONE(L1)
- [x] `scripts/port/check-fhs.sh` (+ `fhs-allowlist.txt`, 1 файл) — DONE(L1)
- [x] `scripts/port/divergence.sh` — DONE(L0)
- [x] `scripts/port/record-niri-fixtures.sh` — DONE(L0, не запускался: нет доступа к niri)
- [x] `checks.boundary`, `checks.fhs` во flake — DONE(L1)
- [ ] Записать фикстуры (idle, fullscreen, kb-switch, multi-monitor, overview) — NEEDS-HUMAN
- [ ] Ответы по фикстурам: Q3, Q8, OutputsChanged, tile_pos_in_workspace_view, версия niri — TODO

## S3. C++ модуль Caelestia.Niri (F01, U10)
- [x] S3a: перенос `nirisocket`/`niriipc` → `plugin/src/Caelestia/Niri/`, удалить `hyprextras.*`/`hyprdevices.*` (U10) — DONE(L1)
- [ ] S3b: QtTest `plugin/tests/niri/` + `checks.unit` — TODO
- [ ] S3c: `KeyboardLayoutSwitched`, `ConfigLoaded`, `WorkspaceActiveWindowChanged`, `OutputsChanged`, фуллскрин (Q3) — TODO

## S4. Фасад services/Compositor.qml
- [ ] Таблица мест вызова `Hypr.*` в `COMPOSITOR_API.md` — TODO
- [ ] `services/Compositor.qml` + `supports` — TODO
- [ ] Удалить `services/Hypr.qml` — TODO

## S5. Каркас оболочки
- [ ] S5a: U20 — ShellState/Screens — TODO
- [ ] S5b: U18, U51 — CustomShortcut → IpcHandler, `niri-binds.example.kdl` — TODO
- [ ] S5c: U21 (+U29 Wrapper) — ContentWindow, focus grab — TODO

## S6. Бар
- [ ] S6a: U23 — Bar.handleWheel — TODO
- [ ] S6b: U24 (Q5, Q7), U25 (Q2) — воркспейсы — TODO
- [ ] S6c: U26 (Q9), U27, U28 — активное окно, статус-иконки, раскладки — TODO

## S7. Остальные места, зависящие от композитора
- [ ] U42 — уведомления и фуллскрин (Q3) — TODO
- [ ] U52 — Visualiser autoHide — TODO
- [ ] U56 — IdleMonitors, power-off-monitors — TODO
- [ ] U49 — windowinfo (Q13) — TODO
- [ ] U62 — areapicker — TODO
- [ ] Аудит `caelestia-cli` для U53/U54/U36 — TODO (решение — человек)
- [ ] U45 — Recorder (Q10) — TODO
- [ ] U47 — GameMode (Q15) — TODO
- [ ] `boundary-allowlist.txt` пуст, `nix flake check` зелёный — TODO

## S8. Упаковка под NixOS (U02)
- [ ] `nix/default.nix`: без hyprland, + niri, env-пути — TODO
- [ ] `nix/hm-module.nix` (Q-NIX1, Q-NIX2), `NIRI_SOCKET` в user-сервисе — TODO
- [ ] README — TODO

## S9. Интеграция в систему пользователя
- [ ] Путь к системному flake — NEEDS-HUMAN
- [ ] `nixos-rebuild build --flake …#kurva-lenovo --override-input niri-caelestia-src path:$PWD` — TODO
- [ ] switch + прогон VERIFY — NEEDS-HUMAN

## S10. (Опционально) Доработки форка
- [ ] Только по списку от человека (F02…F15) — NEEDS-HUMAN

## S11. Синхронизация с upstream
- [ ] `docs/port/UPSTREAM_SYNC.md` + пробный merge — TODO
