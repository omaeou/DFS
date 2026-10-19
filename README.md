# DFS — Dark Fantasy Shell

**Русский:** [к описанию](#русский) · **English:** [go to English](#english)

DFS — модульная оболочка рабочего стола на [Quickshell](https://quickshell.org/). Интерфейс оформлен в стиле dark fantasy: металлические рамки, руны, акцентное свечение и анимации. Сейчас интеграция с композитором рассчитана на Hyprland.

## Русский

### Возможности

- Панель с настраиваемыми левой, центральной и правой капсулами.
- Отдельные панели на подключённых экранах; список экранов можно ограничить в конфигурации.
- Рабочие столы Hyprland, заголовок активного окна, часы и системный трей.
- Управление воспроизведением через MPRIS/`playerctl`, окно плеера и эквалайзер EasyEffects.
- Уведомления, управление Wi-Fi и Bluetooth, громкостью и микрофоном.
- Выбор обоев из заданного списка и переключаемые темы оболочки.
- Профили VPN для NetworkManager, OpenFortiVPN и внешних клиентов.
- Встроенные QML-модули и поддержка пользовательских плагинов.

Некоторые модули используют внешние системные программы и работают только при наличии соответствующего сервиса или устройства.

### Требования

- Linux и [Quickshell](https://quickshell.org/) с Qt Quick Controls и используемыми модулями Quickshell.
- В том числе QML-модули `QtWebSockets`, `Quickshell.Hyprland`, `Quickshell.Services.Notifications`, `Quickshell.Services.Pipewire` и `Quickshell.Services.SystemTray`.
- Hyprland для переключения рабочих столов и интеграции Go-демона с событиями композитора.
- `playerctl` для MPRIS-плееров; скрипты плеера также используют `jq`, `curl`, `python3` и утилиты `coreutils` (`timeout`, `head`, `sha256sum`, `wc`).
- NetworkManager (`nmcli`) для Wi-Fi, BlueZ (`bluetoothctl`) для Bluetooth.
- `openfortivpn` для соответствующего типа VPN-профиля; он не нужен, если используются другие клиенты.
- `secret-tool` и активная системная связка ключей, если нужно сохранять пароли VPN.
- EasyEffects с включённым локальным управляющим сокетом — для чтения и изменения полос эквалайзера.
- `awww` и работающий `awww-daemon` — для переключения обоев.
- Go — только если собираете необязательный демон DFS.

Громкость и микрофон используют PipeWire API Quickshell; для выбора аудиоустройств также вызывается `pactl`.

### Установка и запуск

Из корня репозитория выполните:

```sh
./install.sh
```

Установщик копирует оболочку в `~/.config/quickshell/dfs/` (или `$XDG_CONFIG_HOME/quickshell/dfs/`) и сохраняет существующий `config.json`. Затем запустите её:

```sh
qs -p "$HOME/.config/quickshell/dfs/shell.qml"
```

Для запуска прямо из клона репозитория:

```sh
qs -p "$PWD/shell/shell.qml"
```

### Демон Hyprland (необязательно)

Go-демон пересылает события Hyprland оболочке по WebSocket, слушающему только loopback-интерфейс. Соединение требует случайный токен из приватного runtime-каталога пользователя. Сейчас интерфейс активного окна использует это соединение. Рабочие столы получают состояние и команды напрямую через Quickshell.

Соберите демон из каталога репозитория:

```sh
mkdir -p "$HOME/.local/bin"
cd daemon
go build -o "$HOME/.local/bin/dfs-daemon" .
```

Добавьте запуск обоих процессов в конфигурацию Hyprland:

```ini
exec-once = $HOME/.local/bin/dfs-daemon
exec-once = qs -p $HOME/.config/quickshell/dfs/shell.qml
```

### Конфигурация

Основной файл настроек — `shell/config.json` в репозитории или установленный `~/.config/quickshell/dfs/config.json`. После установки редактируйте копию в каталоге Quickshell.

- `bar.layout.left`, `bar.layout.center`, `bar.layout.right` задают порядок модулей в капсулах.
- Пустой `bar.screenIds` показывает панель на всех подключённых экранах. Чтобы выбрать экраны, перечислите их имена из системы, например `DP-1` или `eDP-1`.
- `bar.autoHide`, `bar.height` и `bar.margin` настраивают панель.
- `appearance.skin`, `appearance.colorScheme`, `appearance.animations`, `appearance.glow` и `appearance.ornaments` задают оформление и эффекты.
- `layout` задаёт порядок встроенных модулей панели управления.
- `modules` содержит параметры отдельных модулей; неизвестные параметры можно не добавлять.
- `wallpapers` — массив путей к изображениям или каталогам. При открытии каталоги сканируются рекурсивно; ищутся PNG, JPG, JPEG, WEBP, AVIF, BMP, GIF, TIFF, PNM, TGA, Farbfeld и SVG. Поддержка AVIF зависит от сборки `awww`. Можно использовать абсолютные пути, пути относительно `shell/` и `~/`. Левая кнопка открывает выбор с миниатюрами, правая применяет следующие обои.
- Кнопка VPN открывает список профилей. `.ovpn` можно импортировать через NetworkManager; для OpenFortiVPN есть отдельный профиль; для других клиентов задаются команды подключения и отключения.
- Пароли VPN сохраняются через `secret-tool` в системной связке ключей, а не в `config.json`. NetworkManager использует собственные сохранённые секреты. Для OpenFortiVPN одноразовый код вводится до запуска; внешняя команда может запросить его во время входа.

Поддерживаемые значения оформления: темы `bloodsteel`, `ashen`, `obsidian`, `verdigris`, `alchemy`, `runes`, `custom`; цветовые схемы `crimson`, `violet`, `frost`, `jade`, `amber`; анимации `full`, `balanced`, `reduced`, `off`.

Встроенные ID панели: `systemInfo`, `activeWindow`, `workspaces`, `clock`, `musicPlayer`, `notifications`, `networkToggle`, `vpn`, `wallpaper`, `systray`, `controlPanelToggle`. Модули панели управления: `Wifi`, `Bluetooth`, `Volume`, `Mic`, `Appearance`.

Краткая инструкция по доработке модулей и QML находится в [`QML_GUIDE.md`](QML_GUIDE.md).

Пример настройки панели:

```json
{
  "bar": {
    "screenIds": [],
    "layout": {
      "left": ["activeWindow"],
      "center": ["workspaces", "clock"],
      "right": ["musicPlayer", "notifications", "systray", "controlPanelToggle"]
    }
  }
}
```

Список экранов можно получить в Hyprland командой `hyprctl monitors`.

### Плагины

Пример плагина и требования к QML-компоненту описаны в [`shell/plugins/example-clock/README.md`](shell/plugins/example-clock/README.md). Чтобы включить пример, измените `plugins.example-clock.enabled` на `true` и добавьте `example-clock` в один из массивов `bar.layout`. Плагины исполняются как доверенный QML-код от имени текущего пользователя.

### Уведомления из SwayNC

Quickshell принимает уведомления через DBus. Для передачи в историю DFS уведомлений, уже полученных SwayNC, в репозитории есть [`swaync-notification-bridge.sh`](shell/core/services/swaync-notification-bridge.sh). Его можно вызывать из пользовательской интеграции, передав данные через переменные `SWAYNC_APP_NAME`, `SWAYNC_SUMMARY`, `SWAYNC_BODY` и `SWAYNC_ID`.

### Если оболочка не запускается

- Проверьте путь к `shell.qml` и запустите Quickshell из терминала, чтобы увидеть сообщения загрузки.
- Если уведомления из SwayNC не появляются в DFS, проверьте, что bridge запускается после оболочки и передаёт текст уведомления.
- Если нет обложки, трека или команд плеера, проверьте `playerctl --list-all` и наличие MPRIS у используемого приложения.
- Эквалайзер требует запущенный EasyEffects и доступный управляющий сокет; без них остаются локально сохранённые значения полос.
- Для сети и Bluetooth проверьте, что доступны `nmcli` и `bluetoothctl`, а NetworkManager и BlueZ запущены.

## English

### Overview

DFS is a modular desktop shell built with [Quickshell](https://quickshell.org/). Its dark-fantasy interface uses metal-like frames, runes, accent lighting, and animations. The compositor integration currently targets Hyprland.

### Features

- A bar with configurable left, center, and right capsules.
- One bar per connected display, with an option to limit it to selected displays.
- Hyprland workspaces, active-window title, clock, and system tray.
- MPRIS/`playerctl` playback controls, a custom player window, and an EasyEffects equalizer.
- Notifications, Wi-Fi and Bluetooth controls, volume, and microphone controls.
- Wallpaper cycling from a configured list and switchable shell themes.
- VPN profiles for NetworkManager, OpenFortiVPN, and configurable external clients.
- Built-in QML modules and support for user plugins.

Some modules depend on external system tools and require the matching service or device to be available.

### Requirements

- Linux and [Quickshell](https://quickshell.org/) with Qt Quick Controls and the Quickshell modules used by the shell.
- This includes the `QtWebSockets`, `Quickshell.Hyprland`, `Quickshell.Services.Notifications`, `Quickshell.Services.Pipewire`, and `Quickshell.Services.SystemTray` QML modules.
- Hyprland for workspace switching and compositor events consumed by the Go daemon.
- `playerctl` for MPRIS players; the player scripts also use `jq`, `curl`, `python3`, and `coreutils` utilities (`timeout`, `head`, `sha256sum`, `wc`).
- NetworkManager (`nmcli`) for Wi-Fi and VPN, BlueZ (`bluetoothctl`) for Bluetooth.
- `openfortivpn` for its dedicated VPN profile type; this client is optional if you use other providers.
- `secret-tool` and an unlocked Secret Service keyring if you want saved VPN passwords.
- EasyEffects with its local control socket enabled to read and change equalizer bands.
- `awww` and a running `awww-daemon` to cycle wallpapers.
- Go only if you want to build the optional DFS daemon.

Volume and microphone controls use Quickshell's PipeWire API. Audio-device selection also calls `pactl`.

### Install and run

From the repository root, run:

```sh
./install.sh
```

The installer copies the shell to `~/.config/quickshell/dfs/` (or `$XDG_CONFIG_HOME/quickshell/dfs/`) and preserves an existing `config.json`. Then start it with:

```sh
qs -p "$HOME/.config/quickshell/dfs/shell.qml"
```

To run directly from the repository checkout:

```sh
qs -p "$PWD/shell/shell.qml"
```

### Hyprland daemon (optional)

The Go daemon forwards Hyprland events to the shell over a WebSocket bound to the loopback interface. The connection also requires a random token from the user's private runtime directory. The active-window title currently uses this connection. Workspace state and switching use Quickshell directly.

Build it from the repository:

```sh
mkdir -p "$HOME/.local/bin"
cd daemon
go build -o "$HOME/.local/bin/dfs-daemon" .
```

Add both processes to your Hyprland configuration:

```ini
exec-once = $HOME/.local/bin/dfs-daemon
exec-once = qs -p $HOME/.config/quickshell/dfs/shell.qml
```

### Configuration

The source configuration is `shell/config.json`. After installation, edit the copy at `~/.config/quickshell/dfs/config.json`.

- `bar.layout.left`, `bar.layout.center`, and `bar.layout.right` define the module order in each capsule.
- An empty `bar.screenIds` shows the bar on every connected display. To select displays, list their system names, such as `DP-1` or `eDP-1`.
- `bar.autoHide`, `bar.height`, and `bar.margin` configure the bar.
- `appearance.skin`, `appearance.colorScheme`, `appearance.animations`, `appearance.glow`, and `appearance.ornaments` control the visual theme and effects.
- `layout` sets the order of built-in control-panel modules.
- `modules` contains per-module settings; optional settings can be omitted.
- `wallpapers` accepts image files or directories. Directories are scanned recursively when the picker opens for PNG, JPG, JPEG, WEBP, AVIF, BMP, GIF, TIFF, PNM, TGA, Farbfeld, and SVG images. AVIF support depends on the `awww` build. Paths may be absolute, relative to `shell/`, or use `~/`. Left-click the wallpaper button to choose from previews; right-click applies the next image.
- The VPN button opens saved profiles. Import `.ovpn` files through NetworkManager, use the OpenFortiVPN profile, or define commands for another client. Saved passwords use the system keyring.

Supported appearance values: skins `bloodsteel`, `ashen`, `obsidian`, `verdigris`, `alchemy`, `runes`, `custom`; color schemes `crimson`, `violet`, `frost`, `jade`, `amber`; animation levels `full`, `balanced`, `reduced`, `off`.

Built-in bar IDs: `systemInfo`, `activeWindow`, `workspaces`, `clock`, `musicPlayer`, `notifications`, `networkToggle`, `vpn`, `wallpaper`, `systray`, and `controlPanelToggle`. Control-panel module IDs: `Wifi`, `Bluetooth`, `Volume`, `Mic`, and `Appearance`.

Example bar configuration:

```json
{
  "bar": {
    "screenIds": [],
    "layout": {
      "left": ["activeWindow"],
      "center": ["workspaces", "clock"],
      "right": ["musicPlayer", "notifications", "systray", "controlPanelToggle"]
    }
  }
}
```

In Hyprland, list connected displays with `hyprctl monitors`.

### Plugins

The example plugin and its QML component contract are documented in [`shell/plugins/example-clock/README.md`](shell/plugins/example-clock/README.md). To enable it, set `plugins.example-clock.enabled` to `true` and add `example-clock` to one of the `bar.layout` arrays. Plugins run as trusted QML code with the current user's permissions.

### SwayNC notifications

Quickshell receives notifications over DBus. To copy notifications already received by SwayNC into DFS history, the repository includes [`swaync-notification-bridge.sh`](shell/core/services/swaync-notification-bridge.sh). A user integration can invoke it with `SWAYNC_APP_NAME`, `SWAYNC_SUMMARY`, `SWAYNC_BODY`, and `SWAYNC_ID` environment variables.

### Troubleshooting

- Check the path to `shell.qml` and start Quickshell from a terminal to see configuration errors.
- If SwayNC notifications do not appear in DFS, check that the bridge runs after the shell and passes the notification text.
- If track metadata, cover art, or playback controls are missing, check `playerctl --list-all` and confirm that the app exposes MPRIS.
- The equalizer needs EasyEffects running with its control socket available; without it, locally saved band values remain available.
- For network and Bluetooth controls, check that `nmcli` and `bluetoothctl` are installed and that NetworkManager and BlueZ are running.
