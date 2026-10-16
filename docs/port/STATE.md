# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-16

## Current step
S1 — базовая сборка upstream на NixOS (без изменений кода)

## In progress
- [x] flake.nix: devShell + niri/jq/ripgrep/libxml2/qt6.qtdeclarative/clang-tools (nix eval ок)
- [x] flake.nix: checks.<system>.package (nix eval ок)
- [ ] `nix build -L .#default` — упал: `No space left on device` при сборке quickshell 0.3.2 (на / 650M свободно)

## Next action
После освобождения места на `/`: `nix build -L .#default --no-link`; затем `nix develop -c qmllint --version`
и `nix flake check -L`; результат — в DECISIONS.md → «Окружение»; коммит `port(S1): ...`.

## Metrics
boundary-allowlist: n/a (S2) · flake check: not run (диск)

## Blocked / pending decisions
- S1 build — BLOCKED: нет места на `/` (DECISIONS.md → «Окружение»)
- Q2–Q15, Q-NIX1, Q-NIX2 — PENDING (DECISIONS.md)

## Needs human
- Освободить место на `/` (нужно ≥ ~10–15G для сборки quickshell + плагина), например `sudo nix-collect-garbage -d`
  или удалить старые поколения системы — решать вам.
- `git push -u origin niri-v2` — у агента нет прав на origin.
