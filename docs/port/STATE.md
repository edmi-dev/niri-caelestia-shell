# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-16

## Current step
S3b — QtTest для `Caelestia.Niri` на фикстурах (пока фикстур нет — синтетические, помечены `synthetic`)

## In progress
- (пусто)

## Next action
Создать `tests/fixtures/niri/synthetic/` (workspaces/windows/keyboard-layouts JSON + event-stream.jsonl по формату
niri IPC) и `plugin/tests/niri/tst_niriipc.cpp` (QtTest: `NiriIpc(false, nullptr)` + `applyResponse`/`processEvent`);
подключить `enable_testing()` в CMake; `nix develop -c bash -c 'cmake --build build && ctest --test-dir build'`.

## Metrics
boundary-allowlist: 29 files · fhs-allowlist: 1 file · flake check: green (x86_64-linux)

## Blocked / pending decisions
- S2 ответы по фикстурам (Q3, Q8, OutputsChanged, tile_pos_in_workspace_view) — ждут фикстур
- Q2–Q15, Q-NIX1, Q-NIX2 — PENDING (DECISIONS.md)
- Рантайм шелла сломан до S4 (`services/Hypr.qml` → удалённый `HyprExtras`) — ожидаемо

## Needs human
- Записать фикстуры niri: VERIFY.md → «S2» (у агента нет доступа к `NIRI_SOCKET`, он работает от `claude-agent`).
- `git push -u origin niri-v2` — у агента нет прав на origin.
