# Контракт `services/Compositor.qml`

Единственный QML-файл, который знает про `NiriIpc` (модуль `Caelestia.Niri`). Весь остальной QML обращается только к `Compositor.*`.
Заполняется в S4 по реальным местам вызова (`rg -n '\bHypr\.' -t qml`).

## Возможности (`Compositor.supports`)

| Флаг | Значение | Основание |
|---|---|---|
| `specialWorkspaces` | false | в niri нет спецворкспейсов (Q2) |
| `focusGrab` | false | нет протокола hyprland-focus-grab |
| `globalShortcuts` | false | нет протокола global-shortcuts; бинды через IPC |
| `runtimeOptions` | false | нет runtime-опций; только KDL + include |
| `windowTags` | false | в niri нет тегов окон (Q7) |
| `cursorPos` | false | нет позиции курсора в IPC |
| `fullscreenFlag` | true (эвристика) | Q3(a): `window_size` == логический размер выхода; windowed fullscreen не виден |
| `toplevelCapture` | TBD | проверить (Q9) |

## Свойства / функции / сигналы

_TBD (S4)._

## Таблица мест вызова: upstream `Hypr.*` → `Compositor.*` → niri IPC

| Вызов upstream | Файл:строка | Compositor | niri action / event | ID |
|---|---|---|---|---|
| _TBD (S4)_ | | | | |

## IPC (`IpcHandler`-цели, замена `CustomShortcut`)

_TBD (S5b)._
