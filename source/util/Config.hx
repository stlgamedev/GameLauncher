package util;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/**
 * Launcher configuration loader/writer.
 *
 * Creates and reads "settings.cfg".
 */
class Config
{
	public var mode:String; // "normal" | "kiosk"
	public var theme:String; // theme id (e.g., "default")

	public var idleSecondsMenu:Int; // time to enter attract mode
	public var idleSecondsGame:Int; // idle kill inside game
	public var logsRollDaily:Bool; // roll logs per day

	public var contentRootDir:String; // absolute or relative
	public var logsRoot:String; // absolute or relative

	public var subscriptions:Array<String>;
	public var autoUpdate:Bool;
	public var checkOnBoot:Bool;
	public var scheduleDaily:String; // "HH:MM"
	public var serverBase:String; // URL

	// Controls (merged later into InputMap)
	public var controlsKeys:Map<String, Array<String>>;
	public var controlsPads:Map<String, Array<String>>;

	public static var CFG_FILE = "settings.cfg";

	public function new() {}

	/* ---------------- Public API ---------------- */
	public static function loadOrCreate():Config
	{
		if (!FileSystem.exists(CFG_FILE))
		{
			var c = defaults();
			ensureParentDir(CFG_FILE);
			try
			{
				File.saveContent(CFG_FILE, defaultsIni());
				Log.line("[CFG] Created default " + CFG_FILE);
			}
			catch (e:Dynamic)
			{
				Log.line("[CFG][ERROR] Failed to write defaults: " + Std.string(e));
			}
			finalizePaths(c);
			return c;
		}

		var text = "";
		try
			text = File.getContent(CFG_FILE)
		catch (e:Dynamic)
		{
			Log.line("[CFG][ERROR] Could not read " + CFG_FILE + ": " + Std.string(e));
			var c = defaults();
			finalizePaths(c);
			return c;
		}

		var cfg = fromIni(text);
		finalizePaths(cfg);
		return cfg;
	}

	/* ---------------- Internals ---------------- */
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
		c.subscriptions = ["Demos", "ArcadeJam01"];
		c.autoUpdate = false;
		c.checkOnBoot = true;
		c.scheduleDaily = "08:00";
		c.serverBase = "https://sgd.axolstudio.com/launcher";
		// Controls defaults (lowercase tokens; InputMap will normalize)
		c.controlsKeys = [
			"prev" => ["left", "a"],
			"next" => ["right", "d"],
			"select" => ["enter", "space", "comma", "slash"],
			"back" => ["escape"],
			"admin_exit" => ["shift+f12"]
		];
		c.controlsPads = [
			"prev" => ["pad_left"],
			"next" => ["pad_right"],
			"select" => ["pad_a", "pad_start"],
			"back" => ["pad_select"],
			"admin_exit" => [] // keyboard-only by default
		];

		return c;
	}

	static function defaultsIni():String
	{
		#if debug
		var content = "P:\\LauncherExternals\\";
		var theme = "arcade-jam-2018";
		#else
		var content = "external";
		var theme = "default";
		#end

		return "
; ============================================================
; Game Launcher Settings
; ------------------------------------------------------------
; Lines beginning with ';' are comments.
; Do not put comments after values on the same line.
; All keys are case-insensitive. Lists use commas.
;
; Controls:
;   - Put keyboard inputs in [Controls.Keys] and gamepad in [Controls.Pads].
;   - Valid keyboard names (examples):
;       left,right,up,down, enter,space,escape, comma,slash, a,d, shift,f12
;     (Use \"shift+f12\" for the admin combo.)
;   - Valid gamepad names (XInput-style):
;       pad_a,pad_b,pad_x,pad_y, pad_start,pad_select, pad_left,pad_right,pad_up,pad_down
;   - Actions:
;       prev, next  : move selection
;       select      : start/confirm
;       back        : cancel/return
;       admin_exit  : privileged backdoor (defaults to shift+f12)
; ============================================================

[General]
; mode: \"normal\" (demo machines) or \"kiosk\" (arcade mapping only)
mode = normal
; theme folder name in external/themes/
theme = "
			+ theme
			+ "

; idle thresholds (seconds)
idle_seconds_menu = 180
idle_seconds_game = 300

; roll logs daily (creates a new file per day)
logs_roll_daily = true


[Paths]
; where games/, trailers/, themes/ live
content_root = "
			+ content
			+ "
; where logs/ go
logs_root = logs


[Content]
; comma-separated content channels to show
subscriptions = ArcadeJam01


[Update]
auto_update = false
check_on_boot = true
schedule_daily = 08:00
server_base = https://sgd.axolstudio.com/launcher


; ---------------- Controls ----------------
; Keyboard bindings
[Controls.Keys]
prev = left, a
next = right, d
select = enter, space, comma, slash
back = escape
admin_exit = shift+f12

; Gamepad bindings (XInput-style)
[Controls.Pads]
prev = pad_left
next = pad_right
select = pad_a, pad_start
back = pad_select
admin_exit =
";
	}

	static function fromIni(ini:String):Config
	{
		var c = defaults();
		var section = "";

		for (rawLine in ini.split("\n"))
		{
			var line = rawLine.trim();
			if (line == "" || startsWithAny(line, [";", "#", "//"]))
				continue;

			// Section header
			if (line.charAt(0) == "[" && line.charAt(line.length - 1) == "]")
			{
				section = line.substr(1, line.length - 2);
				continue;
			}

			var kv = parseKeyValue(line);
			if (kv == null)
				continue;
			var k = kv.key, v = kv.value;

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

				case "Controls.Keys":
					setMapList(c.controlsKeys, k, v);

				case "Controls.Pads":
					setMapList(c.controlsPads, k, v);

				default:
			}
		}

		Log.line('[CFG] Loaded: mode=${c.mode}, theme=${c.theme}, content_root=${c.contentRootDir}, logs_root=${c.logsRoot}');
		return c;
	}

	static function setMapList(m:Map<String, Array<String>>, key:String, value:String):Void
	{
		if (m == null)
			m = new Map();
		var a = parseList(value); // keep lower-case; InputMap will normalize
		m.set(key.toLowerCase(), a);
	}

	static function finalizePaths(c:Config):Void
	{
		c.contentRootDir = normalizePath(c.contentRootDir);
		c.logsRoot = normalizePath(c.logsRoot);
		ensureDir(c.contentRootDir);
		ensureDir(c.logsRoot);
	}

	/* ---------------- Helpers ---------------- */
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

		var key = line.substr(0, idx).trim();
		var value = line.substr(idx + 1).trim();

		// Strip quotes around entire value (optional)
		if (value.length >= 2)
		{
			var a = value.charAt(0), b = value.charAt(value.length - 1);
			if ((a == '"' && b == '"') || (a == "'" && b == "'"))
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
			var s = p.trim();
			if (s != "")
				out.push(s.toLowerCase());
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

	static function ensureParentDir(path:String):Void
	{
		var dir = Path.directory(path);
		if (dir != "" && !FileSystem.exists(dir))
		{
			try
				FileSystem.createDirectory(dir)
			catch (_:Dynamic) {}
		}
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
			else if (!FileSystem.isDirectory(dir))
				Log.line("[CFG][WARN] Path exists but is not a directory: " + dir);
		}
		catch (e:Dynamic)
		{
			Log.line("[CFG][ERROR] Could not ensure directory: " + dir + " :: " + Std.string(e));
		}
	}
}
