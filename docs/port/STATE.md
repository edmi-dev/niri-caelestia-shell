# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-16

## Current step
S2 — скрипты-проверки и фикстуры niri

## In progress
- (пусто)

## Next action
Написать `scripts/port/check-boundary.sh` (bash, `set -euo pipefail`, rg по шаблону из PORT_AGENT_PROMPT.md
«Скрипты-проверки») с генерацией `scripts/port/boundary-allowlist.txt` из текущих нарушений (флаг `--update-allowlist`).

## Metrics
boundary-allowlist: n/a (S2) · flake check: green (x86_64-linux; --all-systems падает на armv6l, upstream)

## Blocked / pending decisions
- Q2–Q15, Q-NIX1, Q-NIX2 — PENDING (DECISIONS.md)

## Needs human
- `git push -u origin niri-v2` — у агента нет прав на origin.
