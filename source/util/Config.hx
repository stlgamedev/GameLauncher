package util;



/**
 * Launcher configuration loader/writer.
 *
 * settings.cfg example (created automatically if missing):
 *
 * [General]
 * mode = normal
 * theme = default
 * idle_seconds_menu = 180
 * idle_seconds_game = 300
 * hotkey = SHIFT+F12
 * logs_roll_daily = true
 *
 * [Paths]
 * content_root = external
 * logs_root = logs
 *
 * [Content]
 * subscriptions = Demos,ArcadeJam01
 *
 * [Update]
 * auto_update = false
 * check_on_boot = true
 * schedule_daily = 08:00
 * server_base = https://sgd.axolstudio.com/launcher
 */
class Config
{
	public var mode:String; // "normal" | "kiosk"
	public var theme:String; // theme id (e.g., "default")
	public var idleSecondsMenu:Int; // to enter attract mode
	public var idleSecondsGame:Int; // idle kill inside game
	public var hotkey:String; // e.g., "SHIFT+F12"
	public var logsRollDaily:Bool; // roll logs per day

	public var contentRootDir:String; // path to games/trailers root (can be absolute)
	public var logsRoot:String; // path to logs dir (can be absolute)

	public var subscriptions:Array<String>;
	public var autoUpdate:Bool;
	public var checkOnBoot:Bool;
	public var scheduleDaily:String; // "HH:MM"
	public var serverBase:String; // URL

	public static var CFG_FILE = "settings.cfg";

	public function new() {}

	// ---------------- Public API ----------------

	public static function loadOrCreate():Config
	{
		// If settings.cfg is missing, write defaults and return defaults object
		if (!FileSystem.exists(CFG_FILE))
		{
			var c = defaults();
			// ensure parent dir exists
			var cfgDir = Path.directory(CFG_FILE);
			if (cfgDir != "" && !FileSystem.exists(cfgDir))
			{
				try
				{
					FileSystem.createDirectory(cfgDir);
				}
				catch (e:Dynamic) {}
			}
			try
			{
				File.saveContent(CFG_FILE, defaultsIni());
				Log.line("[CFG] Created default " + CFG_FILE);
			}
			catch (e:Dynamic)
			{
				Log.line("[CFG][ERROR] Failed to write defaults: " + Std.string(e));
			}
			// normalize paths before returning
			finalizePaths(c);
			return c;
		}

		// Load from existing INI
		var text = "";
		try
		{
			text = File.getContent(CFG_FILE);
		}
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

	// ---------------- Internals ----------------

	static function defaults():Config
	{
		var c = new Config();
		c.mode = "normal";
		c.theme = "default";
		c.idleSecondsMenu = 180;
		c.idleSecondsGame = 300;
		c.hotkey = "SHIFT+F12";
		c.logsRollDaily = true;

		#if debug
		// force external path for debug builds
		c.contentRootDir = normalizePath("P:\\LauncherExternals\\");
		#else
		c.contentRootDir = "external";
		#end

		c.logsRoot = "logs";

		c.subscriptions = ["Demos", "ArcadeJam01"];
		c.autoUpdate = false;
		c.checkOnBoot = true;
		c.scheduleDaily = "08:00";
		c.serverBase = "https://sgd.axolstudio.com/launcher";
		return c;
	}

	static function defaultsIni():String
	{
		#if debug
		var debugContent = "P:\\LauncherExternals\\";
		#else
		var debugContent = "external";
		#end

		return "[General]\n" + "mode = normal\n" + "theme = default\n" + "idle_seconds_menu = 180\n" + "idle_seconds_game = 300\n" + "hotkey = SHIFT+F12\n"
			+ "logs_roll_daily = true\n\n" + "[Paths]\n" + "content_root = " + debugContent + "\n" + "logs_root = logs\n\n" + "[Content]\n"
			+ "subscriptions = ArcadeJam01\n\n" + "[Update]\n" + "auto_update = false\n" + "check_on_boot = true\n" + "schedule_daily = 08:00\n"
			+ "server_base = https://sgd.axolstudio.com/launcher\n";
	}

	static function fromIni(ini:String):Config
	{
		var c = defaults();
		var section = "";

		// Support both "key=value" and "key: value" styles, commas for lists
		for (rawLine in ini.split("\n"))
		{
			var line = StringTools.trim(rawLine);
			if (line == "" || startsWithAny(line, ["#", ";", "//"]))
				continue;

			// Section header?
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
						case "hotkey": c.hotkey = v;
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
						case "subscriptions":
							c.subscriptions = parseList(v);
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

				default:
			}
		}

		Log.line('[CFG] Loaded: mode=${c.mode}, theme=${c.theme}, content_root=${c.contentRootDir}, logs_root=${c.logsRoot}');
		return c;
	}

	static function finalizePaths(c:Config):Void
	{
		// Normalize/absolutize paths; if relative, make them relative to the working dir
		c.contentRootDir = normalizePath(c.contentRootDir);
		c.logsRoot = normalizePath(c.logsRoot);

		// Ensure directories exist
		ensureDir(c.contentRootDir);
		ensureDir(c.logsRoot);
	}

	// ---------------- Helpers ----------------

	static function startsWithAny(s:String, prefixes:Array<String>):Bool
	{
		for (p in prefixes)
		{
			if (StringTools.startsWith(s, p))
			{
				return true;
			}
		}
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
		// supports comma-separated (recommended); also tolerates semicolons
		var parts = v.split(","); // primary
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

	static public function normalizePath(p:String):String
	{
		if (p == null || p == "")
			return "";
		// Expand ~ for *nix-like paths (harmless on Windows)
		if (p.charAt(0) == "~")
		{
			var home = Sys.getEnv("USERPROFILE");
			if (home == null)
				home = Sys.getEnv("HOME");
			if (home != null)
				p = home + p.substr(1);
		}
		// If it looks absolute (Windows or POSIX), use as-is; else make it relative to CWD
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
			{
				FileSystem.createDirectory(dir);
				Log.line("[CFG] Created directory: " + dir);
			}
			else if (!FileSystem.isDirectory(dir))
			{
				Log.line("[CFG][WARN] Path exists but is not a directory: " + dir);
			}
		}
		catch (e:Dynamic)
		{
			Log.line("[CFG][ERROR] Could not ensure directory: " + dir + " :: " + Std.string(e));
		}
	}
}
