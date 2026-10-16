# Проверка в живой сессии niri (L3b, выполняет человек)

Формат: команда → ожидаемый результат → [ ] отметка. Пункты добавляет агент по мере закрытия задач.

## S2 — фикстуры niri (нужны для S3b/S3c и решений Q3, Q8)

Из корня репозитория, в своей сессии niri (не от пользователя агента — у него нет `NIRI_SOCKET`):

- [ ] `nix develop -c scripts/port/record-niri-fixtures.sh idle` → `tests/fixtures/niri/idle/*.json`, `event-stream.jsonl`
- [ ] `nix develop -c scripts/port/record-niri-fixtures.sh fullscreen` → во время записи: окно в фуллскрин (`fullscreen-window`) и обратно
- [ ] `nix develop -c scripts/port/record-niri-fixtures.sh kb-switch` → во время записи: `niri msg action switch-layout next` несколько раз
- [ ] `nix develop -c scripts/port/record-niri-fixtures.sh overview` → во время записи: открыть и закрыть overview
- [ ] (если есть второй монитор) `nix develop -c scripts/port/record-niri-fixtures.sh multi-monitor` → фокус на другой монитор, переключение воркспейсов
- [ ] Проверить, что в фикстурах нет приватного (заголовки окон, пути) — при необходимости поправить вручную
- [ ] `git add tests/fixtures/niri && git commit -m "test(niri): record niri IPC fixtures"`

Длительность записи по умолчанию — 30 с, можно задать вторым аргументом: `… kb-switch 20`.
Важно: `niri` в devShell — 26.04 из nixpkgs; если в системе другая версия, скрипт всё равно пишет версию **запущенного** композитора в `version.json`.
