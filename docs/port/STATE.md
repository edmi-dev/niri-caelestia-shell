# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-16

## Current step
S3a — перенос `nirisocket`/`niriipc` из fork-legacy в `plugin/src/Caelestia/Niri/` (параллельно ждём фикстуры S2)

## In progress
- (пусто)

## Next action
`git show fork-legacy:plugin/src/Caelestia/Internal/nirisocket.hpp` (и .cpp, niriipc.{hpp,cpp}) +
`cat plugin/src/Caelestia/Services/CMakeLists.txt` → создать `plugin/src/Caelestia/Niri/CMakeLists.txt`
через upstream `qml_module` (URI `Caelestia.Niri`); сборка `nix develop -c cmake --build build`.

## Metrics
boundary-allowlist: 33 files · fhs-allowlist: 1 file · flake check: green (x86_64-linux)

## Blocked / pending decisions
- S2 ответы по фикстурам (Q3, Q8, OutputsChanged, tile_pos_in_workspace_view) — ждут фикстур
- Q2–Q15, Q-NIX1, Q-NIX2 — PENDING (DECISIONS.md)

## Needs human
- Записать фикстуры niri: VERIFY.md → «S2» (у агента нет доступа к `NIRI_SOCKET`, он работает от `claude-agent`).
- `git push -u origin niri-v2` — у агента нет прав на origin.
