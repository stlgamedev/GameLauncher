package;

import flixel.FlxState;
import themes.Theme.Context;

using StringTools;

class GameSelectState extends FlxState
{
	var theme:themes.Theme;
	var selected:Int = 0;

	var nodeMap:Map<String, FlxBasic> = new Map();
	var staticTimer:FlxTimer;
	var launching:Bool = false;
	var idleMenuTimer:Float = 0;

	override public function create():Void
	{
		super.create();
		FlxG.cameras.bgColor = 0xFF000000;

		theme = (Globals.theme != null) ? Globals.theme : themes.Theme.load("external/themes/arcade-jam-2017");
		theme.buildInto(this);

		// name -> FlxBasic for quick lookup (cover/static)
		nodeMap = new Map();
		for (n in theme.nodes)
			nodeMap.set(n.name, n.basic());

		// prime carousel & theme to current selection
		var car:themes.CarouselNode = cast theme.getNodeByName("carousel");
		if (car != null)
			car.applySelected(selected);

		applySelection(true);

		var stat = getSprite("static");
		if (stat != null)
			stat.visible = false;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		theme.updateAll(makeContext());

		if (launching)
		{
			return;
		}
		if (Globals.input.justPressed(Action.AdminExit))
		{
			Sys.exit(0);
			return;
		}

		final left = Globals.input.justPressed(Action.Prev);
		final right = Globals.input.justPressed(Action.Next);
		final enter = Globals.input.justPressed(Action.Select);

		if (left || right || enter)
			idleMenuTimer = 0;
		else
		{
			idleMenuTimer += elapsed;
			if (Globals.cfg != null && idleMenuTimer >= Globals.cfg.idleSecondsMenu)
			{
				FlxG.switchState(() -> new AttractState());
			}
			return;
		}

		var car:themes.CarouselNode = cast theme.getNodeByName("carousel");
		var canNavigate = (car == null) || !car.isAnimating();

		if (canNavigate)
		{
			var delta = 0;
			if (left)
				delta = -1;
			if (right)
				delta = 1;

			if (delta != 0 && Globals.games.length > 0)
			{
				// Compute new selection first (single source of truth)
				var n = Globals.games.length;
				var newSel = (selected + delta + n) % n;

				// Animate the carousel row if present
				if (car != null)
				{
					car.move(delta, newSel);
				}

				// Commit selection immediately so text/cover update under the static flash
				selected = newSel;

				// Update other theme nodes (cover, text, etc.)
				applySelection(false);
			}
		}

		if (Globals.games.length > 0 && enter)
		{
			launching = true;
			var g = Globals.games[selected];
			var go = function()
			{
				util.Analytics.recordLaunch(g.id);
				FlxG.switchState(() -> new LaunchState(g));
			};
			var car:themes.CarouselNode = cast theme.getNodeByName("carousel");
			if (car != null && car.playLaunchSound(go))
			{
				// switch happens onComplete
			}
			else
			{
				go();
			}
		}
	}

	inline function moveSelection(delta:Int):Void
	{
		final n = Globals.games.length;
		if (n == 0)
			return;

		final newSel = (selected + delta + n) % n;

		var vort:themes.VortexNode = cast theme.getNodeByName("vortex");
		if (vort != null)
		{
			try
			{
				untyped vort.nudge();
			}
			catch (_:Dynamic) {}
		}

		var car:themes.CarouselNode = cast theme.getNodeByName("carousel");
		if (car != null)
			car.move(delta, newSel);

		selected = newSel;
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

				// --- dynamic GENREn support ---
				// %GENRE1%, %GENRE2%, %GENRE3%, ... (1-based indices)
				if (name != null && StringTools.startsWith(name, "GENRE"))
				{
					var numStr = name.substr(5); // chars after "GENRE"
					var k = Std.parseInt(numStr);
					if (k != null && k > 0 && g.genres != null && k - 1 < g.genres.length)
						return g.genres[k - 1];
					return "";
				}

				return switch (name)
				{
					case "TITLE": g.title;
					case "YEAR": Std.string(g.year);
					case "DEVS": (g.developers != null && g.developers.length > 0) ? g.developers.join(", ") : "";
					case "GENRES": (g.genres != null && g.genres.length > 0) ? g.genres.join(" • ") : "";
					case "DESC": (g.description != null) ? g.description : "";
					case "BOX": (g.box != null) ? g.box : "";
					case "CART": (g.cartPath != null) ? g.cartPath : (g.box != null ? g.box : "");
					case "PLAYERS": (Reflect.hasField(g, "players") && g.players != null) ? g.players : "";
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

		// cancel any earlier flash
		if (staticTimer != null)
		{
			staticTimer.cancel();
			staticTimer = null;
		}

		// hide cover, show static briefly
		if (cover != null)
			cover.visible = false;
		if (stat != null)
		{
			stat.scale.x = (Std.random(2) == 0) ? 1 : -1;
			stat.scale.y = (Std.random(2) == 0) ? 1 : -1;
			stat.visible = true;
		}

		theme.updateAll(makeContext());

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
