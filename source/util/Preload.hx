package util;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import haxe.io.Path;
import openfl.display.BitmapData;
import sys.FileSystem;

class Preload
{
	public static function preloadGamesBoxArt(games:Array<util.GameEntry>):Void
	{
		if (games == null)
			return;
		for (g in games)
		{
			if (g == null || g.box == null || g.box == "")
				continue;

			var abs = g.box;
			if (!isAbsolute(abs))
			{
				var root = (Globals.cfg != null && Globals.cfg.contentRootDir != null && Globals.cfg.contentRootDir != "") ? Globals.cfg.contentRootDir : "external";
				abs = Path.join([root, abs]);
			}
			if (!FileSystem.exists(abs))
			{
				util.Logger.Log.line("[PRELOAD][MISS] " + abs);
				continue;
			}

			var gr:FlxGraphic = FlxG.bitmap.get(abs);
			if (gr == null)
			{
				try
				{
					var bd = BitmapData.fromFile(abs);
					if (bd != null)
					{
						gr = FlxG.bitmap.add(bd, false, abs);
						if (gr != null)
						{
							gr.destroyOnNoUse = false;
							gr.persist = true;
						}
					}
				}
				catch (e:Dynamic)
				{
					util.Logger.Log.line("[PRELOAD][ERROR] " + abs + " :: " + Std.string(e));
				}
			}
		}
	}

	public static function has(absPath:String):Bool
	{
		// We key by absolute path in FlxG.bitmap
		return FlxG.bitmap.get(absPath) != null;
	}

	static inline function isAbsolute(p:String):Bool
	{
		if (p == null || p == "")
			return false;
		var c0 = p.charAt(0);
		if (c0 == "/" || c0 == "\\")
			return true;
		if (p.length >= 2 && p.charAt(1) == ":")
			return true; // C:\
		return false;
	}
}
