package util;

import sys.FileSystem;

class Paths {
    public static inline var EXTERNAL_ROOT = "external";
    public static inline var DIR_GAMES    = EXTERNAL_ROOT + "/games";
    public static inline var DIR_TRAILERS = EXTERNAL_ROOT + "/trailers";

    // Logs at repo root now:
    public static inline var DIR_LOGS     = "logs";

    public static inline var CFG_FILE     = "settings.cfg";

    public static function ensureAll():Void {
        ensureDir(EXTERNAL_ROOT);
        ensureDir(DIR_GAMES);
        ensureDir(DIR_TRAILERS);
        ensureDir(DIR_LOGS);
    }

    static function ensureDir(p:String):Void {
        if (!FileSystem.exists(p)) FileSystem.createDirectory(p);
    }
}
