package util;


/**
 * Preloads external images into Flixel's bitmap cache (FlxG.bitmap).
 * Key = absolute file path.
 */
class Preload
{
	// Optional: one-shot listeners for when a specific key finishes loading
	static var onReady:Map<String, Array<Void->Void>> = [];

	public static function preloadGamesBoxArt(games:Array<GameEntry>):Void
	{
		if (games == null)
			return;
		for (g in games)
		{
			if (g.box == null || g.box == "")
				continue;
			preloadOne(g.box);
		}
	}

	public static function has(key:String):Bool
	{
		return key != null && FlxG.bitmap.get(key) != null;
	}

	public static function get(key:String):FlxGraphic
	{
		return key == null ? null : FlxG.bitmap.get(key);
	}

	public static function whenReady(key:String, cb:Void->Void):Void
	{
		if (key == null)
			return;
		if (has(key))
		{
			cb();
			return;
		}
		if (onReady[key] == null)
			onReady[key] = [];
		onReady[key].push(cb);
		preloadOne(key); // ensure a load is in flight
	}

	public static function preloadOne(key:String):Void
	{
		if (key == null || key == "")
			return;
		if (FlxG.bitmap.get(key) != null)
		{
			notify(key);
			return;
		}
		// Load from disk (async) via OpenFL
		BitmapData.loadFromFile(key).onComplete((bmd) ->
		{
			var gr = FlxG.bitmap.add(bmd, true, key); // cache under 'key'
			// Stick around even if not referenced momentarily
			gr.persist = true;
			gr.destroyOnNoUse = false;
			notify(key);
		}).onError((err) ->
			{
				// Failed load -> do nothing; callers can decide how to handle
				notify(key);
			});
	}

	static function notify(key:String):Void
	{
		var arr = onReady[key];
		if (arr != null)
		{
			for (cb in arr)
				try
					cb()
				catch (_:Dynamic) {}
			onReady.remove(key);
		}
	}
}
