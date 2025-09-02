package util;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/**
 * Launcher configuration loader/writer.
 * 
 * Key points:
 * - Unifies controls under a single [Controls] section (string lists per action).
 * - Provides compatibility getters `controlsKeys` and `controlsPads`
 *   so existing InputMap.configure(keys, pads) continues to work.
 * - Writes a very detailed settings.cfg with instructions/comments.
 */
class Config
{
	// ------------ General ------------
	public var mode:String; // "normal" | "kiosk"
	public var theme:String; // theme id (e.g., "default")
	public var idleSecondsMenu:Int; // to enter attract mode
	public var idleSecondsGame:Int; // idle kill inside a launched game
	public var logsRollDaily:Bool; // roll logs per day

	// ------------ Paths ------------
	public var contentRootDir:String; // path to games/trailers root (can be absolute)
	public var logsRoot:String; // path to logs dir (can be absolute)

	// ------------ Content / Update ------------
	public var subscriptions:Array<String>;
	public var autoUpdate:Bool;
	public var checkOnBoot:Bool;
	public var scheduleDaily:String; // "HH:MM"
	public var serverBase:String; // URL

	// ------------ Controls (unified) ------------
	// "action" -> "comma,separated,tokens"
	public var controls:Map<String, String>;

	// Back-compat views for InputMap.configure():
	public var controlsKeys(get, never):Map<String, Array<String>>;
	public var controlsPads(get, never):Map<String, Array<String>>;

	public static var CFG_FILE = "settings.cfg";

	public function new() {}

	// ---------------- Public API ----------------

	public static function loadOrCreate():Config
	{
		if (!FileSystem.exists(CFG_FILE))
		{
			var c = defaults();

			// ensure parent dir exists
			var cfgDir = Path.directory(CFG_FILE);
			if (cfgDir != "" && !FileSystem.exists(cfgDir))
			{
				try
					FileSystem.createDirectory(cfgDir)
				catch (_:Dynamic) {}
			}
			try
				File.saveContent(CFG_FILE, defaultsIni())
			catch (_:Dynamic) {}

			finalizePaths(c);
			return c;
		}

		var text = "";
		try
			text = File.getContent(CFG_FILE)
		catch (_:Dynamic)
		{
			var c = defaults();
			finalizePaths(c);
			return c;
		}

		var cfg = fromIni(text);
		finalizePaths(cfg);
		return cfg;
	}

	// ---------------- Internals ----------------

	static function defaults():Config
	{
		var c = new Config();
		c.mode = "normal";
		c.idleSecondsMenu = 180;
		c.idleSecondsGame = 300;
		c.logsRollDaily = true;

		#if debug
		c.contentRootDir = normalizePath("P:\\LauncherExternals\\");
		c.theme = "arcade-jam-2018";
		#else
		c.contentRootDir = "external";
		c.theme = "default";
		#end

		c.logsRoot = "logs";
		c.subscriptions = ["ArcadeJam01"];
		c.autoUpdate = false;
		c.checkOnBoot = true;
		c.scheduleDaily = "08:00";
		c.serverBase = "https://sgd.axolstudio.com/launcher";
		// Your requested defaults with gamepads:
		c.controls = new Map();
		c.controls.set("prev", "LEFT, A, PAD_LEFT");
		c.controls.set("next", "RIGHT, D, PAD_RIGHT");
		c.controls.set("select", "ENTER, SPACE, COMMA, SLASH, PAD_A, PAD_START");
		c.controls.set("back", "ESCAPE, PAD_SELECT");
		c.controls.set("admin_exit", "SHIFT+F12");

		return c;
	}

	static function defaultsIni():String
	{
		#if debug
		var debugContent = "P:\\LauncherExternals\\";
		var theme = "arcade-jam-2018";
		#else
		var debugContent = "external";
		var theme = "default";
		#end

		// Heavily commented, human-friendly config
		return "# ==============================================================\n"
			+ "#  Arcade Launcher - Settings\n"
			+ "#  Any line starting with # is a comment.\n"
			+ "#  Use either 'key = value' or 'key: value' formats.\n"
			+ "#  Strings do not need quotes unless they include '=' or ':'.\n"
			+ "#\n"
			+ "#  CONTROLS OVERVIEW\n"
			+ "#  -----------------\n"
			+ "#  Controls live in the [Controls] section as comma-separated lists\n"
			+ "#  per action (case-insensitive, whitespace ignored around commas).\n"
			+ "#\n"
			+ "#  Actions you can set:\n"
			+ "#    prev, next  -> Move selection in the carousel.\n"
			+ "#    select      -> Launch / confirm.\n"
			+ "#    back        -> Go back / request exit (LaunchState listens for this).\n"
			+ "#    admin_exit  -> Admin-only emergency exit (SHIFT+F12 recommended).\n"
			+ "#\n"
			+ "#  Keyboard tokens (examples):\n"
			+ "#    LEFT, RIGHT, UP, DOWN, ENTER, SPACE, COMMA, SLASH, A, D, ESCAPE, SHIFT, F12\n"
			+ "#\n"
			+ "#  Gamepad tokens: prefix with PAD_\n"
			+ "#    PAD_A, PAD_B, PAD_X, PAD_Y, PAD_START, PAD_SELECT (alias of PAD_BACK), PAD_BACK,\n"
			+ "#    PAD_LEFT, PAD_RIGHT, PAD_UP, PAD_DOWN\n"
			+ "#\n"
			+ "#  Examples:\n"
			+ "#    prev = LEFT, A, PAD_LEFT\n"
			+ "#    admin_exit = SHIFT+F12\n"
			+ "#\n"
			+ "#  PATHS\n"
			+ "#  -----\n"
			+ "#  'content_root' should contain 'games', 'trailers', and 'themes'.\n"
			+ "#  'logs_root' is where daily logs are written.\n"
			+ "# ==============================================================\n"
			+ "\n"
			+ "[General]\n"
			+ "mode = normal              # normal | kiosk\n"
			+ "theme = "
			+ theme
			+ "             # theme folder name under 'external/themes'\n"
			+ "idle_seconds_menu = 180    # seconds of inactivity at menu before attract mode\n"
			+ "idle_seconds_game = 300    # seconds of inactivity inside a game before forced exit (Windows builds)\n"
			+ "logs_roll_daily = true     # write logs with a daily suffix\n"
			+ "\n"
			+ "[Paths]\n"
			+ "content_root = "
			+ debugContent
			+ "  # root containing 'games', 'trailers', 'themes'\n"
			+ "logs_root = logs              # folder for logs (created if missing)\n"
			+ "\n"
			+ "[Content]\n"
			+ "subscriptions = ArcadeJam01  # comma-separated IDs you plan to sync\n"
			+ "\n"
			+ "[Update]\n"
			+ "auto_update = false\n"
			+ "check_on_boot = true\n"
			+ "schedule_daily = 08:00\n"
			+ "server_base = https://sgd.axolstudio.com/launcher\n"
			+ "\n"
			+ "[Controls]\n"
			+ "# prev/next: move selection in the carousel\n"
			+ "prev = LEFT, A, PAD_LEFT\n"
			+ "next = RIGHT, D, PAD_RIGHT\n"
			+ "# select: confirm / launch\n"
			+ "select = ENTER, SPACE, COMMA, SLASH, PAD_A, PAD_START\n"
			+ "# back: go back from a submenu (also used by LaunchState to request game exit)\n"
			+ "back = ESCAPE, PAD_SELECT\n"
			+ "# admin_exit: privileged hotkey to immediately exit a running game (Windows global hotkey) or the app when at menu\n"
			+ "admin_exit = SHIFT+F12\n";
	}

	static function fromIni(ini:String):Config
	{
		var c = defaults();
		var section = "";

		for (rawLine in ini.split("\n"))
		{
			var line = StringTools.trim(rawLine);
			if (line == "" || startsWithAny(line, ["#", ";", "//"]))
				continue;

			if (line.charAt(0) == "[" && line.charAt(line.length - 1) == "]")
			{
				section = line.substr(1, line.length - 2);
				continue;
			}

			var kv = parseKeyValue(line);
			if (kv == null)
				continue;
			var k = kv.key;
			var v = kv.value;

			switch section
			{
				case "General":
					switch k
					{
						case "mode": c.mode = v.toLowerCase();
						case "theme": c.theme = v;
						case "idle_seconds_menu": c.idleSecondsMenu = safeInt(v, c.idleSecondsMenu);
						case "idle_seconds_game": c.idleSecondsGame = safeInt(v, c.idleSecondsGame);
						case "logs_roll_daily": c.logsRollDaily = toBool(v, c.logsRollDaily);
						default:
					}

				case "Paths":
					switch k
					{
						case "content_root": c.contentRootDir = v;
						case "logs_root": c.logsRoot = v;
						default:
					}

				case "Content":
					switch k
					{
						case "subscriptions": c.subscriptions = parseList(v);
						default:
					}

				case "Update":
					switch k
					{
						case "auto_update": c.autoUpdate = toBool(v, c.autoUpdate);
						case "check_on_boot": c.checkOnBoot = toBool(v, c.checkOnBoot);
						case "schedule_daily": c.scheduleDaily = v;
						case "server_base": c.serverBase = v;
						default:
					}

				case "Controls":
					if (c.controls == null)
						c.controls = new Map();
					c.controls.set(k.toLowerCase(), v);
				default:
			}
		}

		util.Logger.Log.line('[CFG] Loaded: mode=${c.mode}, theme=${c.theme}, content_root=${c.contentRootDir}, logs_root=${c.logsRoot}');
		return c;
	}

	static function finalizePaths(c:Config):Void
	{
		c.contentRootDir = normalizePath(c.contentRootDir);
		c.logsRoot = normalizePath(c.logsRoot);
		ensureDir(c.contentRootDir);
		ensureDir(c.logsRoot);
	}

	// ---------------- Compatibility getters ----------------

	inline function isPadToken(tok:String):Bool
	{
		return tok != null && tok.toUpperCase().indexOf("PAD_") == 0;
	}

	function get_controlsKeys():Map<String, Array<String>>
	{
		var out = new Map<String, Array<String>>();
		if (controls != null)
		{
			for (action in controls.keys())
			{
				var line = controls.get(action);
				var arr = new Array<String>();
				if (line != null && line != "")
				{
					for (raw in line.split(","))
					{
						var tok = StringTools.trim(raw);
						if (tok != "" && !isPadToken(tok))
							arr.push(tok.toUpperCase());
					}
				}
				out.set(action, arr);
			}
		}
		return out;
	}

	function get_controlsPads():Map<String, Array<String>>
	{
		var out = new Map<String, Array<String>>();
		if (controls != null)
		{
			for (action in controls.keys())
			{
				var line = controls.get(action);
				var arr = new Array<String>();
				if (line != null && line != "")
				{
					for (raw in line.split(","))
					{
						var tok = StringTools.trim(raw);
						if (tok != "" && isPadToken(tok))
							arr.push(tok.toUpperCase());
					}
				}
				out.set(action, arr);
			}
		}
		return out;
	}

	// ---------------- Helpers ----------------

	static function startsWithAny(s:String, prefixes:Array<String>):Bool
	{
		for (p in prefixes)
			if (StringTools.startsWith(s, p))
				return true;
		return false;
	}

	static function parseKeyValue(line:String):{key:String, value:String}
	{
		var idx = line.indexOf("=");
		if (idx < 0)
			idx = line.indexOf(":");
		if (idx <= 0)
			return null;

		var key = StringTools.trim(line.substr(0, idx));
		var value = StringTools.trim(line.substr(idx + 1));

		// Strip surrounding quotes if present
		if (value.length >= 2
			&& ((value.charAt(0) == '"' && value.charAt(value.length - 1) == '"')
				|| (value.charAt(0) == '\'' && value.charAt(value.length - 1) == '\'')))
		{
			value = value.substr(1, value.length - 2);
		}
		return {key: key, value: value};
	}

	static function parseList(v:String):Array<String>
	{
		var parts = v.split(",");
		if (parts.length == 1 && v.indexOf(";") >= 0)
			parts = v.split(";");
		var out = new Array<String>();
		for (p in parts)
		{
			var s = StringTools.trim(p);
			if (s != "")
				out.push(s);
		}
		return out;
	}

	static inline function safeInt(s:String, fallback:Int):Int
	{
		var n = Std.parseInt(s);
		return (n == null) ? fallback : n;
	}

	static inline function toBool(s:String, fallback:Bool):Bool
	{
		var t = s.toLowerCase();
		if (t == "true" || t == "1" || t == "yes" || t == "on")
			return true;
		if (t == "false" || t == "0" || t == "no" || t == "off")
			return false;
		return fallback;
	}

	public static function normalizePath(p:String):String
	{
		if (p == null || p == "")
			return "";
		if (p.charAt(0) == "~")
		{
			var home = Sys.getEnv("USERPROFILE");
			if (home == null)
				home = Sys.getEnv("HOME");
			if (home != null)
				p = home + p.substr(1);
		}
		var isAbs = Path.isAbsolute(p) || (p.length > 1 && p.charAt(1) == ":");
		var full = isAbs ? p : Path.normalize(Sys.getCwd() + "/" + p);
		return Path.normalize(full);
	}

	static function ensureDir(dir:String):Void
	{
		if (dir == null || dir == "")
			return;
		try
		{
			if (!FileSystem.exists(dir))
				FileSystem.createDirectory(dir);
		}
		catch (_:Dynamic) {}
	}
}
