# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-16

## Current step
S7/S8 — всё незаблокированное в S5–S8 сделано. Остаток упирается в решения человека (см. ниже).

## In progress
- (пусто)

## Next action
S8 README: короткий раздел «niri port» в начале `README.md` (маркер NIRI-PORT(S8)): зависимости (niri ≥ 26.04, без Hyprland),
`include` для `docs/port/niri-binds.example.kdl`, `caelestia-shell ipc call …` вместо глобальных шорткатов, ограничения (`supports.*`).
После решений человека: S6b (Q2, Q5, Q7) → `Workspaces.qml`, `Workspace.qml`, `SpecialWorkspaces.qml`; U47 GameMode (Q15).
В маркерах не упоминать `hyprctl`, `Hypr.`, `Hyprland<Type>` — их ловит check-boundary.

Рецепт qmllint (в devShell нет QML-путей): собрать плагин `cmake -S . -B <scratch>/build -G Ninja -DCAELESTIA_BUILD_TESTS=ON`,
затем `qmllint -I <qtdeclarative>/lib/qt-6/qml -I <quickshell-wrapped>/lib/qt-6/qml -I <scratch>/build/qml <file>`
(пути: `readlink -f $(command -v qmllint)`, `command -v qs` внутри `nix develop`). Каталог `build/` в репо — под старым путём, не использовать.
Ограничение L0: qmllint не разрешает `qs.*` (нужна VFS quickshell) — для потребителей проверять только синтаксис.

## Metrics
boundary-allowlist: 4 files (воркспейсы бара ×3, GameMode) · fhs-allowlist: 0 files · flake check: green (package, boundary, fhs, unit; 30 тестов, 8 сценариев) · closure без hyprland

## Blocked / pending decisions
- S6b (воркспейсы бара, спецворкспейсы) — BLOCKED(Q2, Q5, Q7); U47 GameMode — BLOCKED(Q15)
- Превью окна (U26, U49 Preview) — BLOCKED(Q9); Kill в windowinfo — Q16 (сейчас close-window)
- hm-module — BLOCKED(Q-NIX1, Q-NIX2); U45 Recorder — Q10; аудит caelestia-cli (U36/U53/U54) — человек
- Рантайм шелла не стартует, пока в QML есть `Hypr.*` (4 файла выше) — ожидаемо

## Needs human
- `git push -u origin niri-v2` — у агента нет прав на origin.
- Решения: Q2, Q5, Q7 (разблокируют S6b и запуск шелла), Q15 (GameMode), Q9, Q16, Q-NIX1/2 — DECISIONS.md.
