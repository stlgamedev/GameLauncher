package util;

using StringTools;

/**
 * STLGameLauncher configuration loader/writer.
 *
 * Creates and reads "settings.cfg" in the app directory.
 *
 * Simplified schema (single subscription, theme is derived from subscription,
 * logs always rotate, updates: manual or auto-on-launch).
 */
class Config
{
	// --------- Public fields (read by the app) ---------
	public var mode:String; // "normal" | "kiosk"
	public var subscription:String; // e.g., "arcade-launcher-2018"

	public var idleSecondsMenu:Int; // to enter attract mode
	public var idleSecondsGame:Int; // idle kill inside game

	public var contentRootDir:String; // absolute or relative
	public var logsRoot:String; // absolute or relative

	public var updateOnLaunch:Bool; // true => run UpdateState on launch
	public var serverBase:String; // base URL for updates

	// Controls (merged later into InputMap)
	public var controlsKeys:Map<String, Array<String>>; // lower-case tokens
	public var controlsPads:Map<String, Array<String>>; // lower-case tokens

	public static var CFG_FILE = "settings.cfg";

	public function new() {}

	public static function load():Null<Config>
	{
		if (!FileSystem.exists(CFG_FILE))
		{
			Log.line("[CFG][ERROR] settings.cfg is missing.");
			return null;
		}

		var text = "";
		try
		{
			text = File.getContent(CFG_FILE);
		}
		catch (e:Dynamic)
		{
			Log.line("[CFG][ERROR] Could not read " + CFG_FILE + ": " + Std.string(e));
			return null;
		}

		var cfg = fromIni(text);
		finalizePaths(cfg);

		// Force hard-coded controls in kiosk mode
		if (cfg != null && cfg.mode == "kiosk")
		{
			// Player 1: Arrow keys, Period = 'A', Forward Slash (/) = 'B'
			// Player 2: WASD, ` = 'A', 1 = 'B'
			cfg.controlsKeys = [
				"prev" => ["left", "a", "w"],
				"next" => ["right", "d", "s"],
				"select" => ["enter", "space", ".", "`", "1"],
				"back" => ["escape", "/"],
				"admin_exit" => ["shift+f12"]
			];
			// Pads remain unchanged (or could be set to empty)
		}

		// Check for required fields
		if (cfg == null || cfg.contentRootDir == null || cfg.serverBase == null || cfg.subscription == null)
		{
			Log.line("[CFG][ERROR] settings.cfg is incomplete.");
			return null;
		}

		return cfg;
	}

	/* ================= Internals ================= */
	static function defaults():Config
	{
		var c = new Config();

		// General
		c.mode = "normal";

		c.subscription = "arcade-jam-2018";

		// Idle thresholds
		c.idleSecondsMenu = 180;
		c.idleSecondsGame = 300;

		// // Paths
		// #if debug
		// c.contentRootDir = normalizePath("P:\\LauncherExternals\\");
		// #else
		c.contentRootDir = "external";
		// #end
		c.logsRoot = "logs";

		// Updates
		c.updateOnLaunch = false; // manual by default
		c.serverBase = "https://sgd.axolstudio.com/"; // change in installer or cfg

		// Controls defaults (lower-case tokens; InputMap will normalize)
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
						case "subscription": c.subscription = v;
						case "idle_seconds_menu": c.idleSecondsMenu = safeInt(v, c.idleSecondsMenu);
						case "idle_seconds_game": c.idleSecondsGame = safeInt(v, c.idleSecondsGame);
						default:
					}

				case "Paths":
					switch k
					{
						case "content_root": c.contentRootDir = v;
						case "logs_root": c.logsRoot = v;
						default:
					}

				case "Update":
					switch k
					{
						case "update_on_launch": c.updateOnLaunch = toBool(v, c.updateOnLaunch);
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

		Log.line('[CFG] Loaded: mode=${c.mode}, subscription=${c.subscription}, content_root=${c.contentRootDir}, logs_root=${c.logsRoot}, update_on_launch=${c.updateOnLaunch}');
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
		util.Paths.ensureDir(c.contentRootDir);
		util.Paths.ensureDir(c.logsRoot);
	}

	/* ================= Helpers ================= */
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
		return {key: key.toLowerCase(), value: value};
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
}
