# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-17

## Current step
S9 — интеграция в систему пользователя (S0–S8 закрыты; в коде нет Hyprland, boundary-allowlist = 0)

## In progress
- (пусто)

## Next action
S9: получить от человека путь к системному flake (там `hosts/kurva-lenovo/config/niri.kdl`, input `niri-caelestia-src`).
Затем `nixos-rebuild build --flake <путь>#kurva-lenovo --override-input niri-caelestia-src path:$PWD` (только build, не switch);
предложить человеку правки HM-конфига: `programs.caelestia = { settingsMode = "seed"; niri.enable = true; }` и
`include "caelestia.kdl"` в конце `niri.kdl` (VERIFY.md → S9).
Проверка рантайма в изоляции: `nix build .#default && nix develop -c scripts/port/smoke-shell.sh` (QML грузится; дальше
вложенный winit-niri падает на dmabuf v3 — ограничение окружения, DECISIONS → «Smoke-запуск»).

Рецепт qmllint (в devShell нет QML-путей): собрать плагин `cmake -S . -B <scratch>/build -G Ninja -DCAELESTIA_BUILD_TESTS=ON`,
затем `qmllint -I <qtdeclarative>/lib/qt-6/qml -I <quickshell-wrapped>/lib/qt-6/qml -I <scratch>/build/qml <file>`
(пути: `readlink -f $(command -v qmllint)`, `command -v qs` внутри `nix develop`). Каталог `build/` в репо — под старым путём, не использовать.
Ограничение L0: qmllint не разрешает `qs.*` (нужна VFS quickshell) — для потребителей проверять только синтаксис.
В маркерах не упоминать `hyprctl`, `Hypr.`, `Hyprland<Type>` — их ловит check-boundary.

## Metrics
boundary-allowlist: 0 · fhs-allowlist: 0 · flake check: green (package, boundary, fhs, unit; 30 тестов, 8 сценариев) · closure без hyprland · smoke: QML без ошибок

## Blocked / pending decisions
- Q9 (живое превью окна) — PENDING; превью выключено флагом `supports.toplevelCapture`
- Q10 (Recorder, U45) — PENDING; аудит caelestia-cli (U36/U53 setMode/U54) — человек
- Q4, Q6, Q11–Q14 — относятся к S10 (доработки форка), не блокируют

## Needs human
- `git push -u origin niri-v2` — у агента нет прав на origin.
- Путь к системному flake (S9).
- Решения Q9, Q10; аудит caelestia-cli.
