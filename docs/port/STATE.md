# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-16

## Current step
S4 — фасад `services/Compositor.qml` (S0–S3 закрыты)

## In progress
- (пусто)

## Next action
`rg -n '\bHypr\.|Hyprland\.|HyprlandMonitor|HyprlandToplevel|HyprlandWorkspace' -t qml` → таблица мест вызова в
`docs/port/COMPOSITOR_API.md` (вызов → файл:строка → функция Compositor → niri action/event → U-ID); затем
`services/Compositor.qml` по таблице + объект `supports` (fullscreenFlag: true — Q3(a), `NiriIpc.hasFullscreen`).
Учесть: при открытом overview niri шлёт `WindowFocusChanged{id:null}` (DECISIONS → «Фикстуры»).

## Metrics
boundary-allowlist: 29 files · fhs-allowlist: 1 file · flake check: green (package, boundary, fhs, unit; 26 тестов, 8 сценариев)

## Blocked / pending decisions
- Q2, Q4–Q7, Q9–Q15, Q-NIX1, Q-NIX2 — PENDING (DECISIONS.md); Q3 — DECIDED (a); Q8 — исправлен
- Рантайм шелла сломан до S4 (`services/Hypr.qml` → удалённый `HyprExtras`) — ожидаемо

## Needs human
- `niri --version` в системе — сверить с 26.04 (фикстуры записаны на 26.04).
- `git push -u origin niri-v2` — у агента нет прав на origin.
