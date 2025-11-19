# STL GameLauncher

Fullscreen game launcher built for arcade cabinets and kiosk installations. Features automatic crash recovery, idle monitoring, and a DVD-style attract mode with starfield and floating screenshots.

**Current Version:** 1.1.0

[![Latest Build](https://github.com/stlgamedev/GameLauncher/actions/workflows/release.yml/badge.svg)](https://github.com/stlgamedev/GameLauncher/actions/workflows/release.yml)

---

## Installation

Grab the latest `STLGameLauncher-Setup-v<version>.exe` from [GitHub Releases](https://github.com/stlgamedev/GameLauncher/releases) and run it. The installer will walk you through configuration and drop everything in `C:\Program Files\STLGameLauncher` by default.

### Normal vs Kiosk Mode

The launcher runs in one of two modes, configured in `settings.cfg`:

**Normal Mode** — Standard desktop application behavior:
- Runs like a regular program
- Uses keyboard/gamepad controls defined in config
- NO auto-restart on crash
- NO auto-start on login
- You manually launch it when you want to use it

**Kiosk Mode** — Locked-down unattended operation for arcade cabinets:
- Auto-starts on Windows login via scheduled task (`STLGameLauncherKiosk`)
- Auto-restarts on crash (up to 3 times per minute via the scheduled task)
- Hard-coded arcade controls (ignores config file control settings)
- Enforces idle timeouts for games
- Designed to run 24/7 without human intervention

---

## Configuration

Settings live in `settings.cfg` in the install directory. You can edit this manually if needed.

### General

```ini
[General]
mode = kiosk
subscription = arcade-jam-2018
idle_seconds_menu = 180
idle_seconds_game = 300
```

- `mode` — `normal` or `kiosk`
- `subscription` — Content pack name
- `idle_seconds_menu` — Inactivity timeout before attract mode kicks in
- `idle_seconds_game` — Inactivity timeout before killing an idle game

### Paths

```ini
[Paths]
content_root = C:\ProgramData\STLGameLauncher\external
logs_root = C:\ProgramData\STLGameLauncher\logs
```

- `content_root` — Where games, themes, and assets live
- `logs_root` — Where logs are written (auto-cleaned after 30 days)

### Updates

```ini
[Update]
update_on_launch = true
server_base = https://sgd.axolstudio.com/
```

- `update_on_launch` — Check for updates on startup
- `server_base` — Update server URL

### Controls

```ini
[Controls.Keys]
select = enter,space
prev = left,a
next = right,d
back = escape
admin_exit = shift+f12

[Controls.Pads]
select = pad_a,pad_start
prev = pad_left
next = pad_right
back = pad_select
```

**Note:** Kiosk mode overrides these settings with hard-coded arcade controls and ignores the config file.

**Admin hotkey:** `Shift+F12` force-kills the current game and returns to the menu from anywhere. This works in both Normal and Kiosk mode.

---

## Attract Mode

After sitting idle for `idle_seconds_menu` (configured in settings), the launcher switches to attract mode — a screensaver showing game screenshots and prompting visitors to press Start.

Press any key or button to return to the menu.

---

## Subscriptions

A subscription is a content pack that includes games, a theme, and all associated assets. The launcher loads whatever subscription is specified in the `subscription` field in `settings.cfg`.

### How Updates Work

If `update_on_launch = true` in your config, the launcher checks for new content on startup by connecting to the update server specified in `server_base`.

The server organizes content by subscription name:

```
https://sgd.axolstudio.com/
└── arcade-jam-2018/
    ├── games/
    │   ├── mygame-v1.zip
    │   ├── mygame-v2.zip
    │   └── anothergame-v1.zip
    └── theme/
        └── default-theme-v1.zip
```

The launcher compares the version numbers in the zip filenames against local `.version` files for each game and theme. If the server has a newer version, it downloads and extracts it automatically.

**For offline installations:** Set `update_on_launch = false` and manually copy game/theme folders to the appropriate directories. No network required.

---

## Game Configuration

Each game lives in its own folder under `<content_root>/games/<game-id>/` with these required files:

```
external/games/mygame2025/
├── game.json        (metadata)
├── game.exe         (executable)
├── box.png          (box art for menu)
└── .version         (version number, auto-created)
```

### game.json Format

This file tells the launcher everything about your game:

```json
{
  "id": "mygame2025",
  "title": "My Game Title",
  "developers": ["Studio Name", "Another Dev"],
  "description": "Short description that appears in the menu.",
  "year": 2025,
  "genres": ["action", "puzzle"],
  "exe": "game.exe",
  "players": "1,2"
}
```

**Field Breakdown:**
- `id` — Unique identifier. **MUST match the folder name exactly.**
- `title` — Display name shown in the menu
- `developers` — Array of developer/studio names (can be multiple)
- `description` — Brief description (shown in menu if theme supports it)
- `year` — Release year
- `genres` — Array of genre tags (e.g., `["action", "rpg", "platformer"]`)
- `exe` — Name of the executable file (relative to game folder)
- `players` — Player count:
  - `"1"` = 1 player only
  - `"2"` = 2 players only
  - `"1,2"` = 1 or 2 players
  - `"1-2"` = 1 to 2 players (displayed differently by some themes)

### Box Art (`box.png`)

The menu displays this image for each game. Recommended size is 512x512 or larger. The launcher will scale it to fit the theme layout.

### Packaging Games for Updates

When packaging games for server distribution, create a zip file named `<game-id>-v<version>.zip`:

```
mygame2025-v3.zip
└── mygame2025/
    ├── game.json
    ├── game.exe
    ├── box.png
    └── (any other game files)
```

**Important:** The top-level folder inside the zip MUST match the `id` in `game.json`.

**Update Process:**
1. Launcher checks server for `<game-id>-v*.zip` files
2. Compares version number to local `.version` file
3. If server version is newer, downloads and extracts to `<content_root>/games/<game-id>/`
4. Writes new version number to `.version`
5. Deletes the downloaded zip file

---

## Theme Configuration

Themes control the visual layout and live in `external/theme/<theme-id>/`.

```
external/theme/vortex-theme/
├── theme.json
└── ...assets...
```

### theme.json

```json
{
  "id": "vortex-theme",
  "name": "Vortex Theme",
  "elements": [
    {
      "name": "titleText",
      "type": "text",
      "pos": "w/2,40",
      "size": "600,80",
      "color": "#FFFFFF",
      "pointSize": 48,
      "content": "%TITLE%"
    }
  ]
}
```

### Variable Tokens

Use these in text `content` fields:

- `%TITLE%` — Game title
- `%YEAR%` — Release year
- `%DEVS%` — Developers (comma-separated)
- `%GENRES%` — Genres (bullet-separated)
- `%DESC%` — Description
- `%PLAYERS%` — "1 Player", "2 Players", or "1-2 Players"
- `%BOX%` — Box art path
- `%CART%` — Cart image path
- `%GENRE1%`, `%GENRE2%`, etc. — Individual genres by 1-based index

Check `source/themes/Theme.hx` for full element documentation.

---

## Crash Recovery

The launcher has multiple layers of crash protection:

### Application-Level Auto-Restart (Both Modes)

If the launcher crashes, it catches the exception, logs the error with a full stack trace, and attempts to restart itself. This works in both Normal and Kiosk mode.

### Kiosk Mode Scheduled Task (Kiosk Only)

In Kiosk mode, the installer creates a Windows scheduled task called `STLGameLauncherKiosk` that:
- Runs on user login
- Monitors the launcher process
- Automatically restarts it if it exits for any reason
- Limits restarts to 3 attempts per minute (prevents infinite crash loops)

**This scheduled task is NOT created in Normal mode** — crashes in Normal mode will attempt one self-restart, then exit if that fails.

### Emergency Stop (Kiosk Mode)

If you get stuck in a crash loop in Kiosk mode and need to stop the auto-restart behavior:

1. Open Task Scheduler (`Win+R` → `taskschd.msc`)
2. Find `STLGameLauncherKiosk` in the task list
3. Right-click → **Disable**

Or via command line:
```cmd
schtasks /Change /TN "STLGameLauncherKiosk" /DISABLE
```

This stops the scheduled task from restarting the launcher. You can then investigate the logs to see what's causing the crashes.

---

## Logging

Logs go to `<logs_root>/gl-YYYYMMDD.log` and include:
- Startup/shutdown
- Game launches and session times
- Update checks
- Errors and stack traces
- Idle timeouts

Logs older than 30 days are auto-deleted on startup.

**View recent log:**
```cmd
scripts\tail_latest_log.cmd
```

---

## Analytics

Usage stats are tracked locally in `<content_root>/analytics/usage.json`:

```json
{
  "mygame2025": {
    "count": 42,
    "lastPlayed": 1699564823000,
    "totalSeconds": 12847.5
  }
}
```

- `count` — Launch count
- `lastPlayed` — UTC timestamp (ms)
- `totalSeconds` — Total playtime

This data never leaves the machine.

---

## Creating Releases

1. Update the version number in `Project.xml`
2. Commit your changes
3. Run `scripts\create_release_tag.cmd`
4. GitHub Actions automatically builds the installer and publishes the release

If a release build fails and you need to retry, use `scripts\retry_release_tag.cmd` to delete and recreate the tag.

---

## Troubleshooting

### Launcher won't start
- Check `logs/gl-<date>.log` for errors
- Verify `settings.cfg` is valid
- Make sure `content_root` exists and is accessible

### Games won't launch
- Verify `game.json` is valid and `exe` field is correct
- Check game executable permissions
- Review logs

### Updates failing
- Check `server_base` URL
- Verify network connectivity
- Review logs for HTTP errors

### Crash loop
See "Emergency Stop" in Crash Recovery section above.

---

## License

See `LICENSE` file.

---

**Issues:** https://github.com/stlgamedev/GameLauncher/issues
