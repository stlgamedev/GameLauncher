package;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxTimer;

using StringTools;

class GameSelectState extends FlxState
{
	var theme:themes.Theme;
	var selected:Int = 0;

	var nodeMap:Map<String, FlxBasic> = new Map();
	var staticTimer:FlxTimer;
	var launching:Bool = false;

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

		// Always tick theme animations (vortex, etc.)
		theme.updateAll(makeContext());

		// Hard admin exits
		if (Globals.cfg.mode != "kiosk" && FlxG.keys.justPressed.ESCAPE)
		{
			Sys.exit(0);
		}
		if (FlxG.keys.justPressed.F12 && FlxG.keys.pressed.SHIFT && FlxG.keys.pressed.ALT)
		{
			Sys.exit(0);
		}

		// If we're launching, ignore all inputs (still let background animate)
		if (launching)
		{
			return;
		}

		// Carousel navigation (guarded by animation lock)
		var car:themes.CarouselNode = cast theme.getNodeByName("carousel");
		var canNavigate = (car == null) || !car.isAnimating();

		if (canNavigate)
		{
			var delta = 0;
			if (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A)
				delta = -1;
			if (FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D)
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

		// Launch game on ENTER (theme-provided launch sound, then switch)
		if (Globals.games.length > 0 && FlxG.keys.justPressed.ENTER)
		{
			launching = true; // lock all inputs

			var g = Globals.games[selected];
			var go = function()
			{
				util.Analytics.recordLaunch(g.id);
				FlxG.switchState(() -> new LaunchState(g));
			};

			var car:themes.CarouselNode = cast theme.getNodeByName("carousel");
			if (car != null && car.playLaunchSound(go))
			{
				// switch happens in onComplete
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

		// kick vortex (optional)
		var vort:themes.VortexNode = cast theme.getNodeByName("vortex");
		if (vort != null)
		{
			// your VortexNode should expose a nudge(); if not, remove this
			try
			{
				untyped vort.nudge();
			}
			catch (_:Dynamic) {}
		}

		// animate carousel THEN snap to newSel inside carousel
		var car:themes.CarouselNode = cast theme.getNodeByName("carousel");
		if (car != null)
			car.move(delta, newSel);

		// commit selection immediately (context will read this)
		selected = newSel;

		// update text/cover under the CRT with static flash
		applySelection(false);
	}

	function makeContext():themes.Context
	{
		final sw = FlxG.width;
		final sh = FlxG.height;

		return {
			w: sw,
			h: sh,
			themeDir: Globals.theme != null ? Globals.theme.dir : "external/themes/arcade-jam-2017",
			resolveVar: (name:String, offset:Int) ->
			{
				final n = Globals.games.length;
				if (n == 0)
					return "";
				var idx = (selected + offset) % n;
				if (idx < 0)
					idx += n;
				final g = Globals.games[idx];
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

		// update content under static
		theme.updateAll(makeContext());

		// reveal cover
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
