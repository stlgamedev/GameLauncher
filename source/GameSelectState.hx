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

	var nodeMap:Map<String, FlxBasic> = new Map();
	var staticTimer:FlxTimer;

	override public function create():Void
	{
		super.create();
		FlxG.cameras.bgColor = 0xFF000000;

		theme = (Globals.theme != null) ? Globals.theme : themes.Theme.load("external/themes/arcade-jam-2017");
		theme.buildInto(this);

		nodeMap = new Map();
		for (n in theme.nodes)
			nodeMap.set(n.name, n.basic());

		applySelection(true);

		var stat = getSprite("static");
		if (stat != null)
			stat.visible = false;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// KEEP THEME ANIMATIONS ALIVE (vortex etc.)
		theme.updateAll(makeContext());

		var left = FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A;
		var right = FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D;

		if (left)
			moveSelection(-1);
		if (right)
			moveSelection(1);

		if (Globals.cfg.mode != "kiosk" && FlxG.keys.justPressed.ESCAPE)
			Sys.exit(0);
		if (FlxG.keys.justPressed.F12 && FlxG.keys.pressed.SHIFT && FlxG.keys.pressed.ALT)
			Sys.exit(0);

		if (FlxG.keys.justPressed.ENTER && Globals.games.length > 0)
		{
			var g = Globals.games[selected];
			Log.line('[UI] Selected "' + g.title + '" (id=' + g.id + ')');
		}
	}

	inline function moveSelection(delta:Int):Void
	{
		var n = Globals.games.length;
		if (n == 0)
			return;

		// Wrap around selection index
		selected = (selected + delta + n) % n;

		// Nudge the vortex background for a satisfying kick
		var v:themes.VortexNode = cast theme.getNodeByName("vortex");
		if (v != null)
			v.nudge(); // uses JSON nudgeAmount (e.g., 0.20)

		applySelection(false);
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
					case "CART": (g.cartPath != null) ? g.cartPath : (g.box != null ? g.box : "");
					default: "";
				}
			}
		};
	}

	function applySelection(initial:Bool):Void
	{
		if (Globals.games.length == 0)
			return;

		var cover = getSprite("cover");
		var stat = getSprite("static");

		if (initial)
		{
			theme.updateAll(makeContext());
			if (stat != null)
				stat.visible = false;
			if (cover != null)
				cover.visible = true;
			return;
		}

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

		// theme.updateAll(makeContext());

		staticTimer = new FlxTimer().start(0.30, (_) ->
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
}
