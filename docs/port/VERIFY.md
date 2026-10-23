# Проверка в живой сессии niri (L3b, выполняет человек)

Формат: команда → ожидаемый результат → [ ] отметка. Пункты добавляет агент по мере закрытия задач.

## S2 — фикстуры niri

Основные сценарии агент записывает сам в изолированной сессии: `nix develop -c scripts/port/record-niri-fixtures.sh`.
От человека — только то, что изолированно не воспроизвести:

- [ ] (опционально, если есть второй монитор) multi-monitor: сейчас скрипт поддерживает только вложенный niri с одним выходом; при необходимости агент добавит режим записи из живой сессии.
- [x] Сверить версию niri в системе: `niri --version` → 26.04 (проверено агентом 2026-10-16).

## S5b — шорткаты через IPC
Подключить `nix/niri/caelestia.kdl` (через HM: `programs.caelestia.niri.enable = true`, в конце `niri.kdl` — `include "caelestia.kdl"`) и запустить шелл (`caelestia-shell`).

- [x] `caelestia-shell ipc show` → видны цели `drawers` (с `showAll`), `nexus`, `lock`, `picker`, `mpris`, `brightness` (с `increase`/`decrease`), `notifs`, `toaster`. (2026-10-17, kurva-lenovo: все есть, плюс `wallpaper`, `audio`, `idleInhibitor`, `gameMode`; `drawers list` → bar/osd/session/launcher/dashboard/utilities/sidebar; `isOpen launcher` → 0)
- [ ] `caelestia-shell ipc call drawers toggle launcher` → открывается/закрывается launcher на сфокусированном выходе.
- [ ] Mod+Space из примера → то же самое, launcher переключается по нажатию.
- [ ] XF86MonBrightnessUp/Down → яркость меняется на шаг из конфига.

## S5c — эмуляция focus grab
- [ ] Открыть launcher (`caelestia-shell ipc call drawers toggle launcher`) → можно сразу печатать, без клика.
- [ ] Клик по окну приложения при открытом launcher/sidebar/session → панель закрывается (сам клик в окно не попадает — ожидаемо).
- [ ] Клик внутри открытой панели (кнопки sidebar, поле launcher) → панель не закрывается.
- [ ] После закрытия панели фокус клавиатуры возвращается окну приложения.
- [ ] Отсоединить popout (winfo) → клик снаружи закрывает его; ввод с клавиатуры в отсоединённом popout (wirelesspassword) работает.
- [ ] Полноэкранное окно (`niri msg action fullscreen-window`) → рамка/бар скрываются, панели закрываются.

## S6 — бар
- [ ] Прокрутка колесом над воркспейсами бара → `focus-workspace-up/down` на сфокусированном выходе; на первом воркспейсе прокрутка вверх ничего не делает.
- [ ] Caps Lock / Num Lock → иконки в баре и popout меняются (sysfs LED, опрос).
- [ ] Popout раскладок: список совпадает с `niri msg keyboard-layouts`, клик переключает раскладку, активная подписана верно; код в статус-иконке (`us`/`ru`) соответствует.
- [ ] Активное окно: заголовок и иконка по `app_id`; при открытом overview — «Desktop» (ожидаемо, niri снимает фокус).

## S7 — idle, уведомления
- [ ] Idle-таймаут с `dpms off` → мониторы гаснут; при движении мыши включаются, в логе шелла нет ошибок.
- [ ] Уведомление при полноэкранном окне: поведение по `notifs.fullscreen` (Off — не показывается); на обычном окне показывается.
- [ ] Визуализатор фона с autoHide: скрыт при тайловом окне на активном воркспейсе, виден при только плавающих/пустом.
- [ ] Area picker (`caelestia-shell ipc call picker open`): наведение на плавающее окно подсвечивает его рамку точно по краям (проверка UNVERIFIED «workspace view == координаты экрана», в т.ч. с баром\/exclusive zone); на тайловых окнах привязки нет — ожидаемо.
- [ ] windowinfo (detached popout из «активного окна»): детали окна корректны (id, размер, воркспейс, выход, pid, floating); «Move to workspace» показывает воркспейсы выхода окна и переносит окно; Float/Tile и Kill (вежливое закрытие) работают.

## S8 — упаковка
- [x] `systemctl --user show-environment | grep NIRI_SOCKET` в сессии niri → переменная есть (иначе сервису шелла нужен `programs.caelestia.systemd.environment`). (2026-10-17: есть)
- [ ] Воркспейсы бара: на каждом мониторе — свои воркспейсы; клик по номеру на баре несфокусированного монитора переключает воркспейс именно на нём; клик по номеру за последним воркспейсом → пустой воркспейс этого монитора.
- [ ] `bar.workspaces.ignoredWindows: ["^steam_app_.*$"]` (пример) → такие окна не делают воркспейс «занятым» и не показываются иконками.

## U47 — GameMode
Добавить в конец `niri.kdl`: `include optional=true "caelestia-gamemode.kdl"`.
- [ ] Utilities → Game mode вкл → анимации/blur/gaps/тени выключены, углы квадратные; `~/.config/niri/caelestia-gamemode.kdl` начинается с `(on)`.
- [ ] Выкл → настройки niri восстановлены, файл содержит только заголовок `(off)`; перезапуск шелла не переключает режим и не показывает тост.
- [ ] Если у вас рамка (`border`) выключена — game mode её не включает (UNVERIFIED).

## S9 — интеграция (системный flake)
В HM-конфиге: `programs.caelestia = { enable = true; settingsMode = "seed"; niri.enable = true; };`, в конце `hosts/kurva-lenovo/config/niri.kdl`: `include "caelestia.kdl"`.
- [~] (2026-10-17: симлинк ✓, `niri validate` ✓, shell.json обычный файл ✓; сохранение из Nexus — не проверено) После `home-manager`/`nixos-rebuild switch`: `~/.config/niri/caelestia.kdl` — симлинк, `niri validate` без ошибок; `~/.config/caelestia/shell.json` — обычный файл (seed), сохранение настроек из Nexus работает.
- [~] `systemctl --user status caelestia` → active; бар, панели, воркспейсы на месте. (2026-10-17: active ✓; БАГ — не полноэкранные окна не видны, вместо них размытые обои: layer-rule blur на весь слой drawers. Исправлено в U53, проверено после switch)
- [x] После switch без layer-rule blur: тайловые и плавающие окна видны, панели шелла поверх них. (2026-10-17, подтвердил человек)

## U45 — запись экрана (Q10 = b)
- [ ] Утилиты → Record fullscreen: запись идёт с текущего монитора, уведомление «Recording started».
- [ ] Стоп: файл появился в `~/Videos/Recordings/recording_*.mp4`, уведомление с Watch/Open/Delete работает.
- [ ] Record region: открывается slurp; Esc отменяет без ошибки; выбранная область пишется.
- [ ] With sound: в файле есть звук.
- [ ] Пауза/продолжение.
- [ ] Если старт падает (уведомление «Recording failed») — включить `programs.gpu-screen-recorder.enable = true` в NixOS-конфиге.

## F16 — Keep awake на три положения (2026-10-22)
- [ ] Утилиты → Keep awake: переключатель на 3 положения (луна / перечёркнутая луна / открытый замок), клик по трети дорожки выбирает положение, клик по текущему — следующее.
- [ ] «Не уходить в сон» (середина): через 3 мин экран блокируется, через 5 мин гаснет, через 10 мин сна НЕТ.
- [ ] «Не блокировать» (справа): ни блокировки, ни гашения, ни сна; подпись «Preventing screen lock».
- [ ] `caelestia-shell ipc call idleInhibitor setMode noSleep` / `getMode` / `cycle`; старые `toggle`/`enable` включают «не блокировать».

## F17 — Профили power-switch в поповере батареи (2026-10-23)
- [ ] Ноутбук: поповер батареи — 4 кнопки (лист / eco / весы / вилка), подсвечен текущий профиль из `power-switch status`, под пилюлей его метка.
- [ ] Клик по кнопке: индикатор переезжает, приходит уведомление power-switch, `power-switch status` показывает новый профиль (без запроса пароля).
- [ ] Профиль сменён из терминала → при следующем открытии поповера подсвечен он.
- [ ] Desktop: прежняя пилюля на 3 кнопки (power-profiles-daemon).
- [ ] `caelestia-shell ipc call powerSwitch list` / `get` / `set powersave`.
