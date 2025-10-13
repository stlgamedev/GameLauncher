# STL GameLauncher

## 1. Installation

Download the latest `STLGameLauncher-Setup-<version>.exe` from the [GitHub Releases](https://github.com/stlgamedev/GameLauncher/releases). Run the installer and follow the prompts. By default, the launcher will install to `C:\Program Files\STLGameLauncher` and create a desktop shortcut.

## 2. Configuration Prompts Explained

On first launch, you'll be prompted to configure the launcher. These settings are saved in `settings.cfg` in the app directory.

**General Section:**
- `mode`: `normal` (default) or `kiosk` (locked-down mode)
- `subscription`: The content pack to use (e.g., `arcade-jam-2018`)
- `idle_seconds_menu`: Seconds of inactivity before attract mode starts
- `idle_seconds_game`: Seconds of inactivity before a running game is killed

**Paths Section:**
- `content_root`: Directory for external content (games, themes, etc.)
- `logs_root`: Directory for log files

**Update Section:**
- `update_on_launch`: If `true`, launcher checks for updates on startup
- `server_base`: URL for update server


**Controls.Keys / Controls.Pads:**
- Map launcher actions to keyboard or gamepad buttons (e.g., `prev`, `next`, `select`, `back`, `admin_exit`)

### Kiosk Mode Controls (Arcade Cabinet)

When running in `kiosk` mode, the launcher will use hard-coded controls to match the arcade cabinet button layout. These controls override any settings in `settings.cfg`:

**Player 1:**
- Arrow keys for movement
- Period (`.`) for 'A' button
- Forward Slash (`/`) for 'B' button

**Player 2:**
- WASD for movement
- Backtick (<code>`</code>) for 'A' button
- Number 1 (`1`) for 'B' button

**Escape:**
- Central button for exiting (mapped to `Escape` key)

These mappings ensure all games and launcher actions work seamlessly with the physical arcade controls.

## 3. How Subscriptions Work

A subscription is a content pack (games, themes, assets) identified by a unique name (e.g., `arcade-jam-2018`). The launcher loads the subscription specified in `settings.cfg`. Each subscription can have its own games and theme.

## 4. Game Configuration

Each game in a subscription must be placed in its own folder under the games directory (e.g., `external/games/<game-id>/`).

**Folder Naming:**
- The folder name (`<game-id>`) should be unique and match the `id` field in the game's `game.json` file.
- Example: `external/games/mygame2025/`

**Required Files in Each Game Folder:**
- `game.json` — Metadata describing the game (see below for format)
- Game executable (e.g., `game.exe`) — The file specified by the `exe` field in `game.json`
- `box.png` — Box art image for the game
- `.version` — Plain text file with the current integer version (used for updates)
- Any additional assets (manuals, screenshots, etc.)

**Sample game.json layout:**

```json
{
	"id": "mygame2025",
	"title": "My Game Title",
	"developers": ["Studio Name"],
	"description": "Short description of the game.",
	"year": 2025,
	"genres": ["action", "puzzle"],
	"exe": "game.exe",
	"players": "1,2" // Add this field for player count
}
```

**Player Count Field:**
- `"players": "1"` — 1-player game
- `"players": "2"` — 2-player game only
- `"players": "1,2"` or `"players": "1-2"` — supports 1 or 2 players

You can display the player count in your theme using the `%PLAYERS%` token in a text element's `content` field. For example:

```json
{
	"name": "playerCount",
	"type": "text",
	"pos": "w-180,120",
	"size": "160,40",
	"color": "#FFD700",
	"pointSize": 24,
	"content": "%PLAYERS%"
}
```

This will show "1 Player", "2 Players", or "1-2 Players" based on the game's `players` field.

**How the Launcher Uses These Files:**
- The launcher scans all subfolders in `external/games/` and loads games with a valid `game.json`.
- The `id` field in `game.json` must match the folder name.
- The launcher uses `box.png` for display, and launches the executable specified in `exe`.
- The `.version` file is used for update checks (see above).
- All other assets are optional but can be referenced in the theme or game metadata.

## 4.2. Packaging Games for Updates (Zip Files)

To enable automatic updates, each game must have a zip file hosted on the update server. The launcher will download and extract these zips as needed.

**How to Package a Game Zip:**
- The zip filename must follow the format: `<game-id>-v<version>.zip` (e.g., `mygame2025-v3.zip`)
- The `<version>` is an integer and should match what will be written to the `.version` file after extraction.
- The contents of the zip should be a single top-level folder named `<game-id>`, containing all game files.

**Example zip structure:**
```
mygame2025-v3.zip
└── mygame2025/
	├── game.json
	├── game.exe
	├── box.png
	└── ...other assets...
```

When the launcher downloads and extracts the zip:
- It creates a folder named `<game-id>` in the games directory (e.g., `external/games/mygame2025/`).
- All files from the top-level folder in the zip are placed directly in that folder.
- The launcher writes the version number to `.version` inside the game folder after extraction.
- The zip file is deleted after extraction.

**Server Setup:**
- Upload each zip to the server in the appropriate subscription folder (e.g., `/games/` under the subscription root).
- The launcher will compare the local `.version` to the highest version zip available and download/extract if needed.

**Update Flow:**
- When a new version is released, increment the version number in the zip filename and in the game files.
- The launcher will extract the zip, write the new version to `.version`, and remove the zip file after extraction.

## 5. Creating a New Theme for a Subscription

Themes are stored in `external/theme/<theme-id>/` and must include a `theme.json` file describing the layout and elements.

**Required files:**
- `theme.json`: Theme specification (see below)
- Any referenced assets (images, fonts, sounds)

**Sample theme.json layout:**
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
		},
		{
			"name": "background",
			"type": "graphic",
			"source": "bg.png",
			"pos": "0,0",
			"size": "w,h"
		}
		// ... more elements ...
	]
}
```

See `source/themes/Theme.hx` for all supported element types and parameters.

---
For more details, see the source code and example configs in the repository.
