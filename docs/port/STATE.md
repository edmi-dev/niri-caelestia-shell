# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-16

## Current step
S4 — фасад `services/Compositor.qml` (S3c закрыт, кроме фуллскрина — BLOCKED(Q3))

## In progress
- (пусто)

## Next action
`rg -n '\bHypr\.|Hyprland\.|HyprlandMonitor|HyprlandToplevel|HyprlandWorkspace' -t qml` → таблица мест вызова в
`docs/port/COMPOSITOR_API.md` (вызов → файл:строка → функция Compositor → niri action/event → U-ID); затем
`services/Compositor.qml` по таблице + объект `supports`.

## Metrics
boundary-allowlist: 29 files · fhs-allowlist: 1 file · flake check: green (package, boundary, fhs, unit; 24 теста, 8 сценариев)

## Blocked / pending decisions
- Фуллскрин (S3c) — BLOCKED(Q3): данные есть (window_size == размер выхода), нужен выбор человека
- Q2, Q4–Q7, Q9–Q15, Q-NIX1, Q-NIX2 — PENDING (DECISIONS.md); Q8 — подтверждён и исправлен
- Рантайм шелла сломан до S4 (`services/Hypr.qml` → удалённый `HyprExtras`) — ожидаемо

## Needs human
- Решить Q3 (фуллскрин): (a) эвристика `window_size` == логический размер выхода (рекомендую), (b) не детектировать.
- `niri --version` в системе — сверить с 26.04 (фикстуры записаны на 26.04).
- `git push -u origin niri-v2` — у агента нет прав на origin.
