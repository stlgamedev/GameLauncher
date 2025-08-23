package util;

import haxe.io.Path;
import sys.FileSystem;

class Paths {
	public static var DIR_LOGS = "logs";
	public static var DIR_GAMES = "";
	public static var DIR_TRAILERS = "";

	// 1) Only logs (safe pre-config)
	public static function ensureLogs():Void
	{
		ensureDir(DIR_LOGS);
	}

	// 2) Content dirs (needs cfg)
	public static function ensureContent():Void
	{
		final root = normalize(Path.join([Globals.cfg.contentRootDir]));
		DIR_GAMES = Path.join([root, "games"]);
		DIR_TRAILERS = Path.join([root, "trailers"]);
		ensureDir(root);
		ensureDir(DIR_GAMES);
		ensureDir(DIR_TRAILERS);
	}

	static inline function normalize(p:String):String
		return Path.normalize(p);
    static function ensureDir(p:String):Void {
        if (!FileSystem.exists(p)) FileSystem.createDirectory(p);
    }
}
