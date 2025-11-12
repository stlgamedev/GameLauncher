package util;

import haxe.io.Path;
import sys.FileSystem;
import util.Globals;
import StringTools;
using StringTools;

/**
 * Paths
 **/
class Paths
{
	/** Root for content (games/theme). Falls back to "external". */
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

	public static inline function safeReadDir(dir:String):Array<String>
	{
		try
		{
			return FileSystem.readDirectory(dir);
		}
		catch (_:Dynamic)
		{
			return [];
		}
	}

	public static inline function strOrNull(v:Dynamic):Null<String>
	{
		return v == null ? null : Std.string(v).trim();
	}

	public static inline function strOrEmpty(v:Dynamic):String
	{
		return v == null ? "" : Std.string(v).trim();
	}
}
