# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-16

## Current step
S3c — недостающие события в `Caelestia.Niri` (каждое — с тестом)

## In progress
- (пусто)

## Next action
В `plugin/src/Caelestia/Niri/niriipc.cpp` → `processEvent`: добавить `KeyboardLayoutSwitched{idx}` (+ сценарий
`tests/fixtures/niri/synthetic-kb-switch/` и тест), затем `ConfigLoaded{failed}` → сигнал `configLoaded(bool failed)`,
`WorkspaceActiveWindowChanged`; ветку `OutputsChanged` удалить, `Outputs` перезапрашивать по `WorkspacesChanged`.
Проверка: `nix develop -c bash -c 'cmake --build build && ctest --test-dir build --output-on-failure'`.

## Metrics
boundary-allowlist: 29 files · fhs-allowlist: 1 file · flake check: green (package, boundary, fhs, unit)

## Blocked / pending decisions
- Фуллскрин (часть S3c) — BLOCKED(Q3): по src 26.4.0 флага нет, нужен выбор эвристики/отказа + фикстура `fullscreen`
- Q2–Q15, Q-NIX1, Q-NIX2 — PENDING (DECISIONS.md)
- Рантайм шелла сломан до S4 (`services/Hypr.qml` → удалённый `HyprExtras`) — ожидаемо

## Needs human
- Записать фикстуры niri: VERIFY.md → «S2» (у агента нет доступа к `NIRI_SOCKET`, он работает от `claude-agent`).
- Решить Q3 (фуллскрин): эвристика по `layout.window_size` ≈ размер выхода или не детектировать.
- `git push -u origin niri-v2` — у агента нет прав на origin.
