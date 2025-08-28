package;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxTimer;
import util.Logger.Log;

using StringTools;

class GameSelectState extends FlxState
{
	var theme:themes.Theme;
	var selected:Int = 0;

	// quick lookup name -> display
	var nodeMap:Map<String, FlxBasic> = new Map();

	var staticTimer:FlxTimer; // null until used

	override public function create():Void
	{
		super.create();
		FlxG.cameras.bgColor = 0xFF000000;

		// Theme already loaded & preloaded by BootState
		theme = (Globals.theme != null) ? Globals.theme : themes.Theme.load("external/themes/arcade-jam-2017");
		theme.buildInto(this);

		// Build node map so we can toggle sprites quickly
		nodeMap = new Map();
		for (n in theme.nodes)
			nodeMap.set(n.name, n.basic());

		// Initial populate (no flash)
		applySelection(true);

		// Ensure static overlay starts hidden
		var stat = getSprite("static");
		if (stat != null)
			stat.visible = false;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// navigation
		var left = FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A;
		var right = FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D;

		if (left)
			moveSelection(-1);
		if (right)
			moveSelection(1);

		// admin exits
		if (Globals.cfg.mode != "kiosk" && FlxG.keys.justPressed.ESCAPE)
			Sys.exit(0);
		if (FlxG.keys.justPressed.F12 && FlxG.keys.pressed.SHIFT && FlxG.keys.pressed.ALT)
			Sys.exit(0);

		if (FlxG.keys.justPressed.ENTER && Globals.games.length > 0)
		{
			var g = Globals.games[selected];
			Log.line('[UI] Selected "' + g.title + '" (id=' + g.id + ')');
			// FlxG.switchState(() -> new PlayingState(g));
		}
	}

	function makeContext():themes.Context
	{
		final sw = FlxG.width;
		final sh = FlxG.height;

		return {
			w: sw,
			h: sh,
			themeDir: theme.dir,
			resolveVar: (name:String, offset:Int) ->
			{
				var n = Globals.games.length;
				if (n == 0)
					return "";

				var idx = (selected + offset) % n;
				if (idx < 0)
					idx += n;

				var g = Globals.games[idx];
				return switch (name)
				{
					case "TITLE": g.title;
					case "YEAR": Std.string(g.year);
					case "DEVS": (g.developers != null && g.developers.length > 0) ? g.developers.join(", ") : "";
					case "GENRES": (g.genres != null && g.genres.length > 0) ? g.genres.join(" • ") : "";
					case "DESC": (g.description != null) ? g.description : "";
					case "BOX": (g.box != null) ? g.box : "";
					case "CART": return (g.cartPath != null) ? g.cartPath : (g.box != null ? g.box : "");

					default: "";
				}
			}
		};
	}

	inline function moveSelection(delta:Int):Void
	{
		var n = Globals.games.length;
		if (n == 0)
			return;
		selected = (selected + delta) % n;
		if (selected < 0)
			selected += n;
		applySelection(false, delta); // pass direction
	}

	// add an optional delta param (default 0)
	function applySelection(initial:Bool, ?delta:Int = 0):Void
	{
		if (Globals.games.length == 0)
			return;

		var cover = getSprite("cover");
		var stat = getSprite("static");

		if (initial)
		{
			updateThemeVars();
			if (stat != null)
				stat.visible = false;
			if (cover != null)
				cover.visible = true;
			return;
		}

		// cancel previous flash
		if (staticTimer != null)
		{
			staticTimer.cancel();
			staticTimer = null;
		}

		if (cover != null)
			cover.visible = false;
		if (stat != null)
		{
			stat.scale.x = (Std.random(2) == 0) ? 1 : -1;
			stat.scale.y = (Std.random(2) == 0) ? 1 : -1;
			stat.visible = true;
		}

		// update under static
		updateThemeVars();

		// ---- trigger carousel wiggle (if present) ----
		var node = theme.getNodeByName("carousel");
		if (node != null)
		{
			var car = Std.downcast(node, themes.CarouselNode);
			if (car != null && delta != 0)
				car.wiggle(delta);
		}

		// drop static after a short delay
		staticTimer = new flixel.util.FlxTimer().start(0.35, (_) ->
		{
			var s1 = getSprite("static");
			var c1 = getSprite("cover");
			if (s1 != null)
				s1.visible = false;
			if (c1 != null)
				c1.visible = true;
			staticTimer = null;
		});
	}

	inline function getSprite(name:String):FlxSprite
	{
		var b = nodeMap.get(name);
		return Std.isOfType(b, FlxSprite) ? cast b : null;
	}

	inline function updateThemeVars():Void
	{
		theme.updateAll(makeContext());
	}
}
