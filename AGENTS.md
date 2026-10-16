# AGENTS.md — niri port of caelestia-shell

## Goal
Branch `niri-v2` = current upstream `caelestia-dots/shell` running on **niri** (no Hyprland),
building with `nix build` / `nix flake check`, with minimal diff to upstream so that
`git merge upstream/main` keeps working. Consumed by the user's system flake via input `niri-caelestia-src`.

## Repo map
- `plugin/src/Caelestia/Niri/` — C++ module `Caelestia.Niri` (`nirisocket`, `niriipc`); the only C++ niri boundary.
- `plugin/tests/niri/` — QtTest on recorded fixtures; `tests/fixtures/niri/` — `niri msg --json` / event-stream dumps.
- `services/Compositor.qml` — the ONLY QML file allowed to touch `NiriIpc`. Contract: `docs/port/COMPOSITOR_API.md`.
- `scripts/port/` — `check-boundary.sh`, `check-fhs.sh`, `divergence.sh`, `record-niri-fixtures.sh`.
- `docs/port/` — state of the port (in Russian):
  - `STATE.md` — current step, in progress, **Next action**, blockers (≤120 lines)
  - `TASKS.md` — S0–S11 checklist; `DECISIONS.md` — Q-log and UNVERIFIED niri facts
  - `VERIFY.md` — human L3b checklist; `journal/` — archived STATE entries
  - `UPDATE_PLAN.md` — reference (IDs U01–U64, F01–F15, Q1–Q15); search by ID, don't read whole
  - `PORT_AGENT_PROMPT.md` — full agent prompt (section «ПРОМПТ»)
- Old fork (code donor): branch `fork-legacy`, read via `git show fork-legacy:<path>`.

## Resume protocol (every session)
1. `cat AGENTS.md docs/port/STATE.md` — nothing else up front.
2. `git status && git log --oneline -15`; resolve uncommitted work per `STATE.md → In progress`.
3. Execute **Next action** from `STATE.md`.
4. Read only files of the current task; big files by line ranges; search with `rg`.

## Checkpoint protocol (after each task / before long ops)
1. Run checks for the task level (L0–L2 below).
2. `git add -A && git commit -m "port(<ID>): <summary>"` (unfinished: `wip(<ID>): …`).
3. Update `docs/port/STATE.md` (one concrete Next action), move closed items to `journal/YYYY-MM-DD.md`.
4. Tick the task in `docs/port/TASKS.md`. If context is getting full — checkpoint and suggest a new session.

## Commands (NixOS, flake only)
- Fast iteration: `nix develop -c bash -c 'cmake --build build && ctest --test-dir build'`
- Full build (L1): `nix build -L .#default`
- Gate: `nix flake check -L`
- L0: `scripts/port/check-boundary.sh`, `scripts/port/check-fhs.sh`, `qmllint <changed files>`
- Markers: `scripts/port/divergence.sh`

## Hard rules
1. No Hyprland: no `Quickshell.Hyprland`, `Hyprland*`, `hyprctl`, `GlobalShortcut`, `Hypr.*`, no shims; missing features → `Compositor.supports.*` flags.
2. Don't guess niri behaviour: verify via fixtures / `niri msg --help`; otherwise mark `UNVERIFIED` in DECISIONS.md and code.
3. Minimal diff to upstream; mark every touched upstream spot with `// NIRI-PORT(<ID>): <why>`.
4. Atomic tasks: one ID (or part), ≤ ~10 files, ends with a commit + STATE.md update.
5. NixOS: only `nix develop -c …` / `nix build`; no pip/sudo//usr writes, no `nixos-rebuild switch` / `home-manager switch`.
6. New tools/scripts in bash or Go only; never write Python; don't touch upstream Python.
7. Don't make the human's decisions: new forks → DECISIONS.md `PENDING`, task `BLOCKED(Qn)`, move on.
8. Code, comments, commits in English; `docs/port/` files and reports to the human in Russian.
