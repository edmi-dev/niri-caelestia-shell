# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-17

## Current step
S9 — интеграция. `nixos-rebuild build` для kurva-lenovo с локальной веткой — УСПЕШНО (2026-10-17, без switch).

## In progress
- Системный flake `/home/edmi/nixos-config` — изменения лежат незакоммиченными в его рабочем дереве (это репо человека;
  агент там не коммитит). У человека там же своя staged-правка `hosts/desktop/default.nix` — не трогать.

## S9: что изменено в /home/edmi/nixos-config
- `flake.nix` — input `niri-caelestia-src`: `github:edmi-dev/niri-caelestia-shell/niri-v2`, теперь flake (убран `flake = false`),
  `inputs.nixpkgs.follows`; follows для quickshell — закомментирован (вариант). flake.lock НЕ обновлён.
- `users/edmi.nix` — `kurva.niriCaelestia.enable = false` (старый модуль `modules/laptop/caelestia-niri`), импорт `caelestia-niri-v2`.
- `modules/laptop/caelestia-niri-v2/default.nix` (новый, untracked) — HM-модуль порта: `programs.caelestia` (cli, settingsMode = seed,
  settings из старого shell.json без `useFahrenheit`, niri.enable с собственным сниппетом), доп. пакеты cliphist/tesseract/app2unit/grim.
- `modules/laptop/caelestia-niri-v2/caelestia.kdl` (новый, untracked) — бинды только на свободных клавишах (Mod+D/B/X/S/Z/A/N,
  Mod+Shift+X/S/C/N), layer-rule blur, include GameMode. Причина: поздний include заменяет совпадающие бинды.
- `hosts/{kurva-lenovo,desktop}/config/niri.kdl` — `systemctl --user start caelestia.service`, старый Mod+D закомментирован,
  последней строкой `include "caelestia.kdl"`.
- Проверено: `niri validate` (оба хоста) — valid; `nix-instantiate --parse` — ок. Сборки не было.

## Next action
Ждать от человека `switch` и прогона VERIFY.md (S9, U45). Команда сборки (path: не годится — тащит старый build/):
`nixos-rebuild build --flake /home/edmi/nixos-config#kurva-lenovo --override-input niri-caelestia-src "git+file://$PWD?ref=niri-v2"`.
Собирается только закоммиченное. Ошибки рантайма — чинить по отчёту человека. Затем S11 (UPSTREAM_SYNC.md + пробный merge).

Рецепт qmllint (в devShell нет QML-путей): собрать плагин `cmake -S . -B <scratch>/build -G Ninja -DCAELESTIA_BUILD_TESTS=ON`,
затем `qmllint -I <qtdeclarative>/lib/qt-6/qml -I <quickshell-wrapped>/lib/qt-6/qml -I <scratch>/build/qml <file>`
(пути: `readlink -f $(command -v qmllint)`, `command -v qs` внутри `nix develop`). Каталог `build/` в репо — под старым путём, не использовать.
Ограничение L0: qmllint не разрешает `qs.*` (нужна VFS quickshell) — для потребителей проверять только синтаксис.
В маркерах не упоминать `hyprctl`, `Hypr.`, `Hyprland<Type>` — их ловит check-boundary.

## Metrics
boundary-allowlist: 0 · fhs-allowlist: 0 · flake check: green (package, boundary, fhs, unit; 30 тестов, 8 сценариев) · closure без hyprland · smoke: QML без ошибок

## Blocked / pending decisions
- Q9 (живое превью окна) — PENDING; превью выключено флагом `supports.toplevelCapture`
- Q10 — DECIDED (b), U45 сделан: `assets/record.sh`; вживую не проверен (VERIFY.md → U45)
- Аудит caelestia-cli (U36/U53 setMode/U54) — человек; `scheme`/`wallpaper` в CLI пока не проверены на Hyprland-зависимость
- Q4, Q6, Q11–Q14 — относятся к S10 (доработки форка), не блокируют

## Needs human
- `git push -u origin niri-v2` — у агента нет прав на origin; затем `nix flake update niri-caelestia-src` в nixos-config.
- `git add` нового модуля в nixos-config и разрешение на `nixos-rebuild build`.
- Решение Q9; аудит caelestia-cli.
- `switch` и прогон VERIFY.md; возможно `programs.gpu-screen-recorder.enable = true` (см. DECISIONS).
