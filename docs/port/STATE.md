# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-16

## Current step
S4 — фасад `services/Compositor.qml` (S0–S3 закрыты)

## In progress
- (пусто)

## Next action
S4-cpp: в `plugin/src/Caelestia/Niri/niriipc.cpp` `actionPayload` — добавить `MoveWindowToWorkspace` с `window_id`+`focus`+
`{Id}` и `SwitchLayout{layout:{Index:N}}` (JSON-форму сверить с `niri-ipc` 26.04, иначе UNVERIFIED), тесты в `plugin/tests/niri/`.
Затем `services/Compositor.qml` строго по `COMPOSITOR_API.md` → «Свойства / функции / сигналы» (таблица мест вызова готова).

## Metrics
boundary-allowlist: 29 files · fhs-allowlist: 1 file · flake check: green (package, boundary, fhs, unit; 26 тестов, 8 сценариев)

## Blocked / pending decisions
- Q2, Q4–Q7, Q9–Q15, Q-NIX1, Q-NIX2 — PENDING (DECISIONS.md); Q3 — DECIDED (a); Q8 — исправлен
- Рантайм шелла сломан до S4 (`services/Hypr.qml` → удалённый `HyprExtras`) — ожидаемо

## Needs human
- `niri --version` в системе — сверить с 26.04 (фикстуры записаны на 26.04).
- `git push -u origin niri-v2` — у агента нет прав на origin.
