# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-17

## Current step
S9 — живая проверка на kurva-lenovo (niri 26.04, eDP-1 + DP-2). Система переключена (system-308), шелл работает
как `caelestia.service`, QML в пакете = HEAD niri-v2 (кроме сборочных подстановок).

## In progress
- U53-fix: из `nix/niri/caelestia.kdl` удалён layer-rule blur для `caelestia-drawers` (закрывал все не полноэкранные
  окна размытыми обоями — xray по умолчанию). В репо закоммичено. В nixos-config у человека своя копия сниппета
  `modules/laptop/caelestia-niri-v2/caelestia.kdl` — блок `layer-rule` удаляет человек (агенту правка запрещена), затем switch.

## Ограничения окружения агента
- Агент работает как `claude-agent` (uid 991): нет доступа к `$NIRI_SOCKET`, user-шине systemd, журналу edmi,
  `~/.local/state`. Живые данные — через дамп от человека (`/tmp/niri-live.txt`, команда в отчёте 2026-10-17).
- Правки в `/home/edmi/nixos-config` агенту запрещены (классификатор) — давать человеку точный дифф.

## Next action
После того как человек удалит `layer-rule` из своей копии сниппета и сделает switch: подтвердить, что окна видны
(VERIFY.md → S9), затем идти по VERIFY.md по одному шагу: S5b (Mod+D, яркость) → S5c → S6 → S7 → S8 → U47 → U45.
Экран меняющие действия — только после «да» человека.

Рецепт qmllint (в devShell нет QML-путей): собрать плагин `cmake -S . -B <scratch>/build -G Ninja -DCAELESTIA_BUILD_TESTS=ON`,
затем `qmllint -I <qtdeclarative>/lib/qt-6/qml -I <quickshell-wrapped>/lib/qt-6/qml -I <scratch>/build/qml <file>`
(пути: `readlink -f $(command -v qmllint)`, `command -v qs` внутри `nix develop`). Каталог `build/` в репо — под старым путём, не использовать.
Ограничение L0: qmllint не разрешает `qs.*` (нужна VFS quickshell) — для потребителей проверять только синтаксис.
В маркерах не упоминать `hyprctl`, `Hypr.`, `Hyprland<Type>` — их ловит check-boundary.

## Журнал сервиса (2026-10-17) — классификация
- upstream/окружение, не чинить: `~/.face` нет; PowerProfiles не активируется (нет power-profiles-daemon, стоит tlp);
  portal «Connection already associated with an application ID»; `Object or context destroyed during incubation`.
- upstream: `Notification.qml` TypeError `… of null` (модель уведомления удалена во время анимации) — порт файл не трогал.
- upstream-упаковка: Nexus → About запускает `quickshell --version`, а обёртка не кладёт quickshell в PATH. Не чинить
  без решения человека (дифф к upstream nix).
- От `Caelestia.Niri` предупреждений нет.

## Metrics
boundary-allowlist: 0 · fhs-allowlist: 0 · flake check: green (2026-10-17) · closure без hyprland · `spirv-opt` не найден
при сборке шейдеров (некритично, шейдеры без оптимизации)

## Blocked / pending decisions
- Q17 (blur под панелями) — PENDING; сейчас blur нет
- Q9 (живое превью окна) — PENDING; превью выключено флагом `supports.toplevelCapture`
- Аудит caelestia-cli (U36/U53 setMode/U54) — человек
- Q4, Q6, Q11–Q14 — относятся к S10 (доработки форка), не блокируют

## Needs human
- Удалить блок `layer-rule { match namespace="^caelestia-drawers$" … }` (и комментарий над ним) из
  `nixos-config/modules/laptop/caelestia-niri-v2/caelestia.kdl`, затем switch.
- `git push origin niri-v2` (у агента нет прав).
- Решения Q9, Q17; аудит caelestia-cli.
