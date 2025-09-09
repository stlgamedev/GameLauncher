package util;

import haxe.Json;
import haxe.io.Path;
import util.Paths;
import sys.FileSystem;
import sys.io.File;

/**
 * Ultra-light analytics: counts launches, lastPlayed, totalSeconds per game. One JSON file in content root. Silent on IO errors.
 */
class Analytics
{
	public static inline var SUBDIR = "analytics";
	public static inline var FILE = "usage.json";

	// In-memory cache (lazy loaded)
	static var loaded:Bool = false;
	static var path:String;
	static var data:Dynamic;

	public static function init(contentRoot:String):Void
	{
		if (loaded)
			return;
		path = Path.join([contentRoot, SUBDIR, FILE]);
		Paths.ensureDir(Path.join([contentRoot, SUBDIR]));
		load();
	}

	public static function recordLaunch(gameId:String):Void
	{
		if (gameId == null || gameId == "")
			return;
		ensureLoaded();

		var e:Dynamic = Reflect.field(data, gameId);
		if (e == null)
		{
			e = {count: 0, lastPlayed: 0.0, totalSeconds: 0.0};
			Reflect.setField(data, gameId, e);
		}
		// bump count, update lastPlayed
		e.count = (Std.int(e.count) : Int) + 1;
		e.lastPlayed = Date.now().getTime(); // UTC ms
		save();
	}

	public static function recordSession(gameId:String, seconds:Float):Void
	{
		if (gameId == null || gameId == "")
			return;
		ensureLoaded();

		var e:Dynamic = Reflect.field(data, gameId);
		if (e == null)
		{
			e = {count: 0, lastPlayed: 0.0, totalSeconds: 0.0};
			Reflect.setField(data, gameId, e);
		}
		e.totalSeconds = (Std.parseFloat(Std.string(e.totalSeconds)) : Float) + Math.max(0, seconds);
		e.lastPlayed = Date.now().getTime();
		save();
	}

	/* -------- internals -------- */
	static inline function ensureLoaded():Void
	{
		if (!loaded)
			load();
	}

	static function load():Void
	{
		data = {};
		#if sys
		try
		{
			if (FileSystem.exists(path))
			{
				var txt = File.getContent(path);
				if (txt != null && txt != "")
					data = Json.parse(txt);
			}
		}
		catch (_:Dynamic) {}
		#end
		loaded = true;
	}

	static function save():Void
	{
		#if sys
		try
		{
			File.saveContent(path, Json.stringify(data));
		}
		catch (_:Dynamic) {}
		#end
	}
}
