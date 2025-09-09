package util;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import haxe.io.Path;
import openfl.display.BitmapData;
import sys.FileSystem;
import util.Paths;

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
			if (!Paths.normalize(abs).startsWith(Paths.contentRoot()))
			{
				abs = Path.join([Paths.contentRoot(), abs]);
			}
			if (!FileSystem.exists(abs))
				continue;

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
				catch (e:Dynamic) {}
			}
		}
	}

	public static function has(absPath:String):Bool
	{
		// We key by absolute path in FlxG.bitmap
		return FlxG.bitmap.get(absPath) != null;
	}
}
