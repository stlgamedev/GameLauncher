package util;

import haxe.io.Path;
import sys.FileSystem;

class Paths {
	/** Root for content (games/trailers/theme). Falls back to "external". */
	public static function contentRoot():String
	{
		var root = (Globals.cfg != null && Globals.cfg.contentRootDir != null && Globals.cfg.contentRootDir != "") ? Globals.cfg.contentRootDir : "external";
		return normalize(root);
	}

	/** Root for logs. Falls back to "logs". */
	public static function logsRoot():String
	{
		var p = (Globals.cfg != null && Globals.cfg.logsRoot != null && Globals.cfg.logsRoot != "") ? Globals.cfg.logsRoot : "logs";
		return normalize(p);
	}

	/** Derived content folders (computed at call-time). */
	public static inline function gamesDir():String
		return Path.join([contentRoot(), "games"]);

	public static inline function trailersDir():String
		return Path.join([contentRoot(), "trailers"]);

	public static inline function themeDir():String
		return Path.join([contentRoot(), "theme"]);

	/** Create logs dir (safe once cfg exists). */
	public static function ensureLogs():Void
	{
		ensureDir(logsRoot());
	}

	/** Create content tree (root + subdirs). */
	public static function ensureContent():Void
	{
		ensureDir(contentRoot());
		ensureDir(gamesDir());
		ensureDir(trailersDir());
		ensureDir(themeDir());
	}

	// ---- helpers ----

	public static inline function normalize(p:String):String
	{
		return (p == null || p == "") ? "" : Path.normalize(p);
	}

	public static function ensureDir(p:String):Void
	{
		if (p == null || p == "")
			return;
		if (!FileSystem.exists(p))
			FileSystem.createDirectory(p);
	}
}
