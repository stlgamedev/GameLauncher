package;

class GameSelectState extends FlxState
{
	var theme:Theme;
	var selected:Int = 0;

	// GameSelectState.hx
	override public function create():Void
	{
		super.create();
		FlxG.cameras.bgColor = 0xFF000000;

		// Just reuse the BootState-loaded theme
		theme = Globals.theme;

		// Build nodes and add them to the state
		theme.buildInto(this);

		// Initial populate
		applySelection(0);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Navigation (left/right default; change to up/down if you prefer)
		var left = FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A;
		var right = FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D;

		if (left)
			moveSelection(-1);
		if (right)
			moveSelection(1);

		// Admin exits (keep your existing logic/macros as needed)
		if (Globals.cfg.mode != "kiosk" && FlxG.keys.justPressed.ESCAPE)
		{
			Log.line("[ADMIN] ESC -> exit (non-kiosk)");
			Sys.exit(0);
		}
		if (FlxG.keys.justPressed.F12 && FlxG.keys.pressed.SHIFT && FlxG.keys.pressed.ALT)
		{
			Log.line("[ADMIN] ALT+SHIFT+F12 -> exit");
			Sys.exit(0);
		}

		// ENTER to "play" (we’ll wire real launch next phase)
		if (FlxG.keys.justPressed.ENTER && Globals.games.length > 0)
		{
			var g = Globals.games[selected];
			Log.line('[UI] Selected "' + g.title + '" (id=' + g.id + ')');
			// FlxG.switchState(() -> new PlayingState(g));
		}
	}

	inline function moveSelection(delta:Int):Void
	{
		var n = Globals.games.length;
		if (n == 0)
			return;
		selected = (selected + delta) % n;
		if (selected < 0)
			selected += n;
		applySelection(0); // 0 = no animation yet; animate later if you want
	}

	function applySelection(_anim:Int):Void
	{
		if (Globals.games == null || Globals.games.length == 0)
			return;
		if (selected < 0 || selected >= Globals.games.length)
			selected = 0;

		// Build context vars for placeholders
		var g = Globals.games[selected];
		var vars = new Map<String, String>();
		vars.set("TITLE", g.title);
		vars.set("YEAR", Std.string(g.year));
		vars.set("DEVS", (g.developers != null && g.developers.length > 0) ? g.developers.join(", ") : "");
		vars.set("GENRES", (g.genres != null && g.genres.length > 0) ? g.genres.join(" • ") : "");
		vars.set("DESC", g.description != null ? g.description : "");
		vars.set("BOX", g.box != null ? g.box : ""); // absolute path from your scanner

		var ctx = {
			w: FlxG.width,
			h: FlxG.height,
			vars: vars,
			themeDir: theme.dir
		};

		// Update all nodes in place (no add/remove)
		theme.updateAll(ctx);
	}
}
