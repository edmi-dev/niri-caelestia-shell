# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-16

## Current step
S4 — фасад `services/Compositor.qml` (S0–S3 закрыты)

## In progress
- (пусто)

## Next action
Написать `services/Compositor.qml` (pragma Singleton) строго по `COMPOSITOR_API.md` → «Свойства / функции / сигналы» + `supports`;
разбор xkb `base.lst` перенести из `services/Hypr.qml` (FileView `kbLayoutFile`). Добавить файл в allowlist `check-boundary.sh`, если нужно; `qmllint`.
Сборка: каталог `build/` сконфигурирован под старый путь (`/home/edmi/...`) — использовать свежий `cmake -B <scratch> -DCAELESTIA_BUILD_TESTS=ON`.

## Metrics
boundary-allowlist: 29 files · fhs-allowlist: 1 file · flake check: green (package, boundary, fhs, unit; 30 тестов, 8 сценариев)

## Blocked / pending decisions
- Q2, Q4–Q7, Q9–Q15, Q-NIX1, Q-NIX2 — PENDING (DECISIONS.md); Q3 — DECIDED (a); Q8 — исправлен
- Рантайм шелла сломан до S4 (`services/Hypr.qml` → удалённый `HyprExtras`) — ожидаемо

## Needs human
- `git push -u origin niri-v2` — у агента нет прав на origin.
