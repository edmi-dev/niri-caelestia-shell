# Журнал решений

Формат: `Qn — PENDING/DECIDED — кто — суть — последствия`. Подробности вариантов — `UPDATE_PLAN.md`, раздел 5.

## Вопросы

- **Q1** — DECIDED — человек — Стратегия: перенос upstream на niri (ветка `niri-v2` от `upstream/main`), доработки форка — опционально в S10. — Схема работ S0–S11.
- **Q2** — PENDING — Спецворкспейсы (U25): отказаться / эмулировать именованными воркспейсами. Рекомендация плана: отказаться (`supports.specialWorkspaces: false`). — Блокирует S6b (U25).
- **Q3** — PENDING — Детектор фуллскрина: поле IPC / эвристика по `layout.window_size` / не детектировать. Решается по фикстуре `fullscreen`. — Блокирует S3c, S5c, U42, U51.
- **Q4** — PENDING — Совместимость `shell.json` со старым форком: миграция при загрузке / скрипт (bash/Go) / начать с чистого. — Актуально для S10/S8.
- **Q5** — PENDING — `bar.workspaces.perMonitor = false` на niri: показывать воркспейсы всех выходов / игнорировать опцию. — Блокирует S6b.
- **Q6** — PENDING — Мониторинг: C++-сервисы upstream (U11) или `sysmonitor` форка (F12). Рекомендация: upstream. — Актуально только для S10.
- **Q7** — PENDING — `ignoredTags`: убрать / заменить на regex по `app_id`/`title`. — Блокирует часть S6b.
- **Q8** — PENDING — Какое событие приходит при переключении раскладки (`KeyboardLayoutSwitched`?). Решается по фикстуре `kb-switch`. — S3c, S6c.
- **Q9** — PENDING — Живое превью окна (`ScreencopyView` по toplevel) на niri: превью / только иконка и заголовок. — Определяет `supports.toplevelCapture`, U26, U49.
- **Q10** — PENDING — Запись экрана (U45): `caelestia` CLI / прямой `gpu-screen-recorder` / не переносить. Зависит от аудита CLI. — S7 (U45).
- **Q11** — PENDING — `quicktoggles` (F05) vs `utilities/cards/Toggles` (U46). — Только S10.
- **Q12** — PENDING — Настройки: Nexus (upstream) или Control Center форка (F04). Рекомендация: Nexus. — Только S10.
- **Q13** — PENDING — `windowinfo` (U49) и `NiriThing` (F03): объединить / оставить оба. — U49 в S7 (базовая часть не блокируется).
- **Q14** — PENDING — `modules/keybinds` (F15): удалить / восстановить. — Только S10.
- **Q15** — PENDING — GameMode (U47): допустимо ли писать файлы в `~/.config/niri/` (генерируемый include). Рекомендация: да. — Блокирует U47.
- **Q-NIX1** — PENDING — HM: `shell.json` через `xdg.configFile` (read-only симлинк) ломает сохранение из UI. Варианты: (a) как есть; (b) seed — активационный скрипт копирует JSON, только если файла нет; (c) оба через опцию. — Блокирует S8 (hm-module).
- **Q-NIX2** — PENDING — Генерировать ли из HM-модуля KDL-сниппет биндов для `include` в конфиг niri, и как пользователь собирает конфиг niri. — Блокирует часть S8.

## Факты о niri (UNVERIFIED, пока нет фикстур)

- UNVERIFIED — признак фуллскрина у окна в `niri msg --json windows` (Q3).
- UNVERIFIED — событие `KeyboardLayoutSwitched` при `switch-layout` (Q8).
- UNVERIFIED — событие `OutputsChanged` в event-stream (код форка его обрабатывает).
- UNVERIFIED — поле `layout.tile_pos_in_workspace_view` у окна.
- UNVERIFIED — действие `power-on-monitors`.
- UNVERIFIED — поведение `include` на отсутствующий файл.
- UNVERIFIED — blur для layer-shell поверхностей.
- Версия niri — не записана.

## Окружение
- 2026-10-16 — S1: `nix build -L .#default` на чистом upstream (a3a8fe59) упал не из-за кода: quickshell 0.3.2 (input `quickshell`, нет в бинарном кэше) собирается из исходников и падает с `No space left on device`. На `/` (там же `/nix`, build-dir `/nix/var/nix/b`) свободно 650M из 125G. Нужно освободить место (решение человека: `nix-collect-garbage`, удаление старых поколений и т. п.), затем повторить сборку.
- 2026-10-16 — Правки flake (devShell-инструменты, `checks.package`) вычисляются (`nix eval` ок); сборка не проверена.
- 2026-10-16 — S1 закрыт: человек освободил место (на / 33G). `nix build .#default` (чистый upstream + правки flake) → `/nix/store/dv3mg159…-caelestia-shell-1.0.0`. `nix flake check -L` (x86_64-linux) — зелёный.
- `nix flake check --all-systems` падает на `armv6l-linux`: «cannot bootstrap GHC» (quickshell → pipewire → … → pandoc → ghc). Проблема upstream/nixpkgs, не порта; гейт — только x86_64-linux. Предупреждение `unknown flake output 'homeManagerModules'` — из upstream, не трогаем.
- devShell: niri 26.04 (nixpkgs), qmllint/qtdeclarative 6.11.2, clang-tools 21.1.8, cmake 4.4.3. Версия niri в живой сессии пользователя — записать по фикстурам (S2).
- 2026-10-16 — Агент работает от пользователя `claude-agent` без `NIRI_SOCKET`: L3a (вложенный niri) и запись фикстур агенту недоступны; всё рантайм-поведение — через человека (L3b).
