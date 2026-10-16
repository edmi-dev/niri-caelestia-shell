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
- [x] `scripts/port/record-niri-fixtures.sh` (изолированный headless sway + niri) — DONE(L2)
- [x] `checks.boundary`, `checks.fhs` во flake — DONE(L1)
- [x] Записать фикстуры в изолированном sway+niri (idle, windows, workspaces, fullscreen, kb-switch, overview, config-reload) — DONE(L2)
- [ ] multi-monitor — NEEDS-HUMAN (под winit один выход; опционально)
- [x] Ответы по фикстурам: Q8 подтверждён, данные для Q3, OutputsChanged нет, tile_pos null во вложенной сессии, niri 26.04 — DONE

## S3. C++ модуль Caelestia.Niri (F01, U10)
- [x] S3a: перенос `nirisocket`/`niriipc` → `plugin/src/Caelestia/Niri/`, удалить `hyprextras.*`/`hyprdevices.*` (U10) — DONE(L1)
- [x] S3b: QtTest `plugin/tests/niri/` + `checks.unit` — DONE(L2) (синтетика; реальные фикстуры подхватятся автоматически)
- [x] S3c: `KeyboardLayoutSwitched`, `ConfigLoaded`, `WorkspaceActiveWindowChanged`, `OutputsChanged`, фуллскрин (Q3) — DONE(L2): KeyboardLayoutSwitched, ConfigLoaded→configLoaded(bool), WorkspaceActiveWindowChanged, OutputsChanged удалён, фуллскрин по Q3(a)

## S4. Фасад services/Compositor.qml
- [x] Таблица мест вызова `Hypr.*` в `COMPOSITOR_API.md` — DONE
- [x] S4-cpp: `actionPayload` — `MoveWindowToWorkspace` с `window_id`/`focus`, `SwitchLayout{Index}` + тесты — DONE
- [x] `services/Compositor.qml` + `supports` — DONE
- [x] Удалить `services/Hypr.qml` — DONE (места вызова `Hypr.*` мигрируют в S5–S7)

## S5. Каркас оболочки
- [x] S5a: U20 — ShellState/Screens — DONE
- [x] S5b: U18, U51 — CustomShortcut → IpcHandler, `nix/niri/caelestia.kdl` — DONE
- [x] S5c: U21 (+U29 Wrapper) — ContentWindow, focus grab — DONE (эмуляция, см. DECISIONS «Focus grab»)

## S6. Бар
- [x] S6a: U23 — Bar.handleWheel — DONE
- [x] S6b: U24 (Q5, Q7), U25 (Q2) — воркспейсы — DONE
- [~] S6c: U26 (Q9), U27, U28 — активное окно, статус-иконки, раскладки — U27, U28 DONE; U26 DONE кроме превью (BLOCKED(Q9))

## S7. Остальные места, зависящие от композитора
- [x] U42 — уведомления и фуллскрин (Q3) — DONE (+ U39 StateMessage)
- [x] U52 — Visualiser autoHide — DONE
- [x] U56 — IdleMonitors, power-off-monitors — DONE (+ U55 Brightness)
- [x] U49 — windowinfo (Q13) — DONE базовая часть; превью BLOCKED(Q9), Kill — Q16
- [x] U62 — areapicker — DONE (привязка только к плавающим окнам)
- [ ] Аудит `caelestia-cli` для U53/U54/U36 — TODO (решение — человек)
- [ ] U45 — Recorder (Q10) — TODO
- [x] U47 — GameMode (Q15) — DONE
- [x] `boundary-allowlist.txt` пуст, `nix flake check` зелёный — DONE (2026-10-17)

## S8. Упаковка под NixOS (U02)
- [x] `nix/default.nix`: без hyprland, env-пути — DONE (niri в runtimeDeps не нужен)
- [x] `nix/hm-module.nix` (Q-NIX1, Q-NIX2), `NIRI_SOCKET` в user-сервисе — DONE: `settingsMode` managed|seed, `niri.enable` → `~/.config/niri/caelestia.kdl`; NIRI_SOCKET без правок
- [ ] README — TODO

## S9. Интеграция в систему пользователя
- [ ] Путь к системному flake — NEEDS-HUMAN
- [ ] `nixos-rebuild build --flake …#kurva-lenovo --override-input niri-caelestia-src path:$PWD` — TODO
- [ ] switch + прогон VERIFY — NEEDS-HUMAN

## S10. (Опционально) Доработки форка
- [ ] Только по списку от человека (F02…F15) — NEEDS-HUMAN

## S11. Синхронизация с upstream
- [ ] `docs/port/UPSTREAM_SYNC.md` + пробный merge — TODO
