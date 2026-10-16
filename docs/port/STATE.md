# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-16

## Current step
S7 — остальные места, зависящие от композитора (S0–S5, S6a закрыты; S6b BLOCKED(Q2,Q5,Q7); S6c — превью BLOCKED(Q9))

## In progress
- (пусто)

## Next action
S7, U62 (areapicker): `modules/areapicker/Picker.qml:21-22,38,47,104` — опции бордера/скругления → константы или Config (нет runtime-опций), активный ws → `Compositor.activeWorkspaceFor(monitorFor(screen))`, окна → `toplevelsForWs`; геометрия окон UNVERIFIED (`tile_pos_in_workspace_view`). Сверить с `git show fork-legacy:modules/areapicker/Picker.qml`.
Затем U49 (windowinfo, базовая часть без превью), U47 BLOCKED(Q15), U53 (Colours: runtime layerrule → удалить, `supports.runtimeOptions`).
В маркерах не упоминать `hyprctl`, `Hypr.`, `Hyprland<Type>` — их ловит check-boundary.

Рецепт qmllint (в devShell нет QML-путей): собрать плагин `cmake -S . -B <scratch>/build -G Ninja -DCAELESTIA_BUILD_TESTS=ON`,
затем `qmllint -I <qtdeclarative>/lib/qt-6/qml -I <quickshell-wrapped>/lib/qt-6/qml -I <scratch>/build/qml <file>`
(пути: `readlink -f $(command -v qmllint)`, `command -v qs` внутри `nix develop`). Каталог `build/` в репо — под старым путём, не использовать.
Ограничение L0: qmllint не разрешает `qs.*` (нужна VFS quickshell) — для потребителей проверять только синтаксис.

## Metrics
boundary-allowlist: 10 files · fhs-allowlist: 0 files · flake check: green (package, boundary, fhs, unit; 30 тестов, 8 сценариев)

## Blocked / pending decisions
- Q2, Q4–Q7, Q9–Q15, Q-NIX1, Q-NIX2 — PENDING (DECISIONS.md); Q3 — DECIDED (a); Q8 — исправлен
- S6b (воркспейсы бара, спецворкспейсы) — BLOCKED(Q2, Q5, Q7); превью активного окна (U26) — BLOCKED(Q9)
- Рантайм шелла сломан, пока места вызова `Hypr.*` не перенесены на `Compositor.*` (S6b, S7) — ожидаемо

## Needs human
- `git push -u origin niri-v2` — у агента нет прав на origin.
- Решения Q2, Q5, Q7 (разблокируют S6b) и Q9 (превью окна) — DECISIONS.md.
