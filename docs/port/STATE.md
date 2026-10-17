# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-17

## Current step
S9 — интеграция в систему пользователя. Правки системного flake написаны, НЕ собраны (человек просил не билдить).

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
Дождаться от человека: (1) `git -C /home/edmi/nixos-config add modules/laptop/caelestia-niri-v2` (flake не видит untracked);
(2) разрешения на сборку. Затем:
`nixos-rebuild build --flake /home/edmi/nixos-config#kurva-lenovo --override-input niri-caelestia-src path:$PWD` (только build).
Ошибки eval/сборки чинить в модуле `caelestia-niri-v2` или в `nix/hm-module.nix` порта. После `switch` (делает человек) — VERIFY.md → S9.
Параллельно, если человек решит Q10 = b: U45 — `services/Recorder.qml` запускает `gpu-screen-recorder` напрямую (см. DECISIONS Q10).

Рецепт qmllint (в devShell нет QML-путей): собрать плагин `cmake -S . -B <scratch>/build -G Ninja -DCAELESTIA_BUILD_TESTS=ON`,
затем `qmllint -I <qtdeclarative>/lib/qt-6/qml -I <quickshell-wrapped>/lib/qt-6/qml -I <scratch>/build/qml <file>`
(пути: `readlink -f $(command -v qmllint)`, `command -v qs` внутри `nix develop`). Каталог `build/` в репо — под старым путём, не использовать.
Ограничение L0: qmllint не разрешает `qs.*` (нужна VFS quickshell) — для потребителей проверять только синтаксис.
В маркерах не упоминать `hyprctl`, `Hypr.`, `Hyprland<Type>` — их ловит check-boundary.

## Metrics
boundary-allowlist: 0 · fhs-allowlist: 0 · flake check: green (package, boundary, fhs, unit; 30 тестов, 8 сценариев) · closure без hyprland · smoke: QML без ошибок

## Blocked / pending decisions
- Q9 (живое превью окна) — PENDING; превью выключено флагом `supports.toplevelCapture`
- Q10 (Recorder, U45) — PENDING; `caelestia record` на niri падает при старте (зовёт Hyprland). Рекомендация (b)
- Аудит caelestia-cli (U36/U53 setMode/U54) — человек; `scheme`/`wallpaper` в CLI пока не проверены на Hyprland-зависимость
- Q4, Q6, Q11–Q14 — относятся к S10 (доработки форка), не блокируют

## Needs human
- `git push -u origin niri-v2` — у агента нет прав на origin; затем `nix flake update niri-caelestia-src` в nixos-config.
- `git add` нового модуля в nixos-config и разрешение на `nixos-rebuild build`.
- Решения Q9, Q10; аудит caelestia-cli.
