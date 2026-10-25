# Port state
Upstream base: a3a8fe59aba2c0048ab02dc817748678f96076ff   Branch: niri-v2   Updated: 2026-10-24

## Current step
S9 — живая проверка на kurva-lenovo (niri 26.04, eDP-1 + DP-2). Система переключена (system-308), шелл работает
как `caelestia.service`, QML в пакете = HEAD niri-v2 (кроме сборочных подстановок).

## In progress
- Ползунок яркости не двигается от клавиш (2026-10-25): в `hosts/kurva-lenovo/config/niri.kdl:433-434` клавиши зовут
  `brightnessctl` напрямую, шелл читает яркость только при старте → не знает об изменении. Человеку дан дифф:
  раскомментировать строки 35-36 в `modules/laptop/caelestia-niri-v2/caelestia.kdl` (IPC `brightness increase/decrease`).
  VERIFIED (`niri validate`, 26.04): одинаковый бинд в основном файле и в include — валидно (в одном файле — ошибка).
  Попутно: при фокусе на DP-2 без DDC «active» = монитор DP-2, но `brightnessctl` меняет eDP → ползунок eDP не сдвинется
  (upstream-поведение; уйдёт после `hardware.i2c.enable`).
- F19 (таймауты экрана/сна из профиля power-switch, keep awake их перебивает; просьба 2026-10-24) — сделано. Нужны
  power-switch с `idle` и `idle` в профилях nixos-config (дифф дан человеку); ждём живой проверки (VERIFY.md → F19).
- Яркость внешнего монитора на ноутбуке не работает (2026-10-23): в nixos-config `./ddcci.nix` закомментирован (7d0342a) →
  нет `hardware.i2c.enable` → нет `/dev/i2c-*` и группы i2c → `ddcutil detect` пуст → шелл шлёт `brightnessctl` (подсветка eDP).
  Человеку дан дифф: `hardware.i2c.enable = true;` в `modules/nixos/workstation.nix`. Ждём проверку `ddcutil detect --brief`.
- F18 (иконки приложений вместо глифов категорий под рабочими столами, просьба 2026-10-23) — сделано, ждём живой проверки (VERIFY.md → F18).
- F17 (power-switch вместо power-profiles-daemon на ноутбуке, 4 кнопки, просьба человека 2026-10-23) — сделано, ждём живой проверки (VERIFY.md → F17).
- F16 (keep awake на 3 положения, просьба человека 2026-10-22) — сделано, ждём живой проверки (VERIFY.md → F16).
- U41-fix (лаги/красный экран блокировки после ~3 раз) — фон из обоев вместо screencopy, непрозрачная поверхность. Ждём: человек пересобирает и блокирует 5+ раз подряд.
- U53-fix (blur на весь слой drawers) — исправлен, после switch окна видны. Ветка запушена, lock nixos-config = dbd51252.
- nixos-config (по просьбе человека, не закоммичено агентом): `users/test.nix` — `caelestia-hyprland.nix` заменён на
  `caelestia-niri-v2` + `niri/config.kdl` из `niriConfig` хоста (как у edmi). `nixos-rebuild build #kurva-lenovo` — ок.
  desktop: edmi уже на v2 через `users/edmi.nix`, `hosts/desktop/config/niri.kdl` подключает `caelestia.kdl`;
  `nix eval` toplevel desktop — ок, сборка на desktop не делалась.
- Погода: «--» в dashboard — open-meteo 13:15 ответил 503, upstream не повторяет запрос до часового таймера (Q18).
  Человеку объяснено: `services.weatherLocation = "Tel Aviv"`, `services.weatherUnits = "Celsius"` в
  `programs.caelestia.settings` (seed: применяется только при отсутствии shell.json) или прямо в shell.json.
  Ждём: применил ли человек и появилась ли погода.

## Ограничения окружения агента
- Агент работает как `claude-agent` (uid 991): нет доступа к `$NIRI_SOCKET`, user-шине systemd, журналу edmi,
  `~/.local/state`. Живые данные — через дамп от человека (`/tmp/niri-live.txt`, команда в отчёте 2026-10-17).
- Правки в `/home/edmi/nixos-config` агенту запрещены (классификатор) — давать человеку точный дифф.

## Next action
Идти по VERIFY.md по одному шагу с человеком. S5b launcher/Mod+D — ✓ (2026-10-25). S5c ✓ кроме п.5 (отложен). Сейчас: S6 п.2
(Caps/Num Lock в баре); яркость S5b — после switch с правкой caelestia.kdl. Дальше: S5c → S6 → S7 → S8 → U47 → U45. Живые данные — дамп от человека в
`/tmp/*.txt` (агент не видит сокет/журнал edmi).
Потом S11 (UPSTREAM_SYNC.md + пробный merge upstream/main), затем S10 по решениям Q4, Q6, Q9, Q11–Q14, Q17.
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
- Q18 (повтор запроса погоды после ошибки) — PENDING
- Q9 (живое превью окна) — PENDING; превью выключено флагом `supports.toplevelCapture`
- Аудит caelestia-cli (U36/U53 setMode/U54) — человек
- Q4, Q6, Q11–Q14 — относятся к S10 (доработки форка), не блокируют

## Needs human
- Удалить блок `layer-rule { match namespace="^caelestia-drawers$" … }` (и комментарий над ним) из
  `nixos-config/modules/laptop/caelestia-niri-v2/caelestia.kdl`, затем switch.
- `git push origin niri-v2` (у агента нет прав).
- Решения Q9, Q17, Q18; аудит caelestia-cli.
