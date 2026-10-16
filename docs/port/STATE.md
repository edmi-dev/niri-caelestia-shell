# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-16

## Current step
S5 — каркас оболочки (S0–S4 закрыты)

## In progress
- (пусто)

## Next action
S5a (U20): `services/ShellState.qml:24-26,39-41` — `Hypr.focusedMonitor`/`Hypr.monitorFor(x)` → `Compositor.focusedMonitor`/
`Compositor.monitorFor(x)` (строки таблицы в `COMPOSITOR_API.md`), маркеры `NIRI-PORT(U20)`; убрать файл из allowlist
(`check-boundary.sh --update-allowlist`), `qmllint`, коммит. Затем S5b (U18, U51).

Рецепт qmllint (в devShell нет QML-путей): собрать плагин `cmake -S . -B <scratch>/build -G Ninja -DCAELESTIA_BUILD_TESTS=ON`,
затем `qmllint -I <qtdeclarative>/lib/qt-6/qml -I <quickshell-wrapped>/lib/qt-6/qml -I <scratch>/build/qml <file>`
(пути: `readlink -f $(command -v qmllint)`, `command -v qs` внутри `nix develop`). Каталог `build/` в репо — под старым путём, не использовать.

## Metrics
boundary-allowlist: 28 files · fhs-allowlist: 1 file · flake check: green (package, boundary, fhs, unit; 30 тестов, 8 сценариев)

## Blocked / pending decisions
- Q2, Q4–Q7, Q9–Q15, Q-NIX1, Q-NIX2 — PENDING (DECISIONS.md); Q3 — DECIDED (a); Q8 — исправлен
- Рантайм шелла сломан, пока места вызова `Hypr.*` не перенесены на `Compositor.*` (S5–S7) — ожидаемо

## Needs human
- `git push -u origin niri-v2` — у агента нет прав на origin.
