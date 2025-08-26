package;



class GameSelectState extends FlxState
{
	var items:Array<FlxText> = [];
	var selected:Int = 0;
	var inputCooldown:Float = 0.0;
	final MOVE_COOLDOWN:Float = 0.12;

	var sortMode:SortMode = SortMode.TitleAZ;
	var rngSeed:Int = Std.random(0x7fffffff); // stable per session for Random

	var boxSprite:FlxSprite;

	var rightPaneX:Int = 980; // left edge of the preview area
	var rightPaneY:Int = 100;
	var rightPaneW:Int = 800;
	var rightPaneH:Int = 860;

	public function new()
	{
		super();
	}

	override public function create():Void
	{
		FlxG.cameras.bgColor = 0xFF000000;
		if (Globals.games == null)
			Globals.games = [];
		applySort();
		selected = 0;
		renderList();
		boxSprite = new FlxSprite();
		var panel = new FlxSprite(rightPaneX, rightPaneY);
		panel.makeGraphic(rightPaneW, rightPaneH, 0xFF101014);

		add(panel);
		add(boxSprite);

		refreshRightPane();
		super.create();
	}

	function renderList():Void
	{
		for (t in items)
			remove(t, true);
		items = [];

		if (Globals.games.length == 0)
		{
			var empty = new FlxText(0, 0, FlxG.width, "No games found.");
			empty.setFormat(null, 24, FlxColor.WHITE, "center");
			empty.y = (FlxG.height - empty.height) * 0.5;
			add(empty);
			return;
		}

		var y = 120;
		var x = 120;
		var lineH = 36;

		for (i in 0...Globals.games.length)
		{
			var g = Globals.games[i];
			var t = new FlxText(x, y + i * lineH, 800, g.title);
			t.setFormat(null, 28, (i == selected ? FlxColor.YELLOW : FlxColor.WHITE), "left");
			add(t);
			items.push(t);
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// --- ESC exits the app only when NOT in kiosk mode ---
		if (Globals.cfg.mode != "kiosk" && FlxG.keys.justPressed.ESCAPE)
		{
			Log.line("[ADMIN] ESC -> exit (non-kiosk)");
			exit(0);
			return;
		}
		//  ALT+SHIFT+F12 = force exit from menu
		if (FlxG.keys.justPressed.F12 && FlxG.keys.pressed.SHIFT && FlxG.keys.pressed.ALT)
		{
			Log.line("[ADMIN] ALT+SHIFT+F12 -> exit");
			exit(0);
		}

		if (inputCooldown > 0)
			inputCooldown -= elapsed;

		var up = FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W;
		var down = FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S;

		if (inputCooldown <= 0)
		{
			if (up)
				moveSelection(-1);
			if (down)
				moveSelection(1);
			if (up || down)
				inputCooldown = MOVE_COOLDOWN;
		}
		if (FlxG.keys.justPressed.ENTER)
		{
			if (Globals.games.length > 0)
			{
				var g = Globals.games[selected];
				Log.line('[UI] Selected "' + g.title + '" (id=' + g.id + ')');
			}
		}
	}

	public function exit(?Code:Int = 0):Void
	{
		try
		{
			Globals.log.close();
		}
		catch (_:Dynamic) {}
		Sys.exit(0);
	}
	function moveSelection(delta:Int):Void
	{
		final n = Globals.games.length;
		if (n == 0)
			return;

		selected = (selected + delta) % n;
		if (selected < 0)
			selected += n;

		final limit = items.length;
		for (i in 0...limit)
		{
			items[i].color = (i == selected) ? FlxColor.YELLOW : FlxColor.WHITE;
		}
		refreshRightPane();
	}

	function applySort():Void
	{
		switch (sortMode)
		{
			case SortMode.TitleAZ:
				Globals.games.sort(function(a, b) return Reflect.compare(a.title, b.title));
			case SortMode.YearDesc:
				Globals.games.sort(function(a, b)
				{
					final ay = a.year;
					final by = b.year;
					final cmp = Reflect.compare(by, ay);
					return (cmp != 0) ? cmp : Reflect.compare(a.title, b.title);
				});
			case SortMode.Random:
				// Fisher–Yates with a simple LCG so the order is stable for this session
				var i = Globals.games.length;
				var seed = rngSeed;
				inline function nextRand():Int
				{
					seed = (seed * 1103515245 + 12345) & 0x7fffffff;
					return seed;
				}
				while (i > 1)
				{
					i--;
					var j = nextRand() % (i + 1);
					var tmp = Globals.games[i];
					Globals.games[i] = Globals.games[j];
					Globals.games[j] = tmp;
				}
		}
	}

	function refreshRightPane():Void
	{
		if (Globals.games == null || Globals.games.length == 0)
		{
			boxSprite.visible = false;
			return;
		}
		if (selected < 0 || selected >= Globals.games.length)
			selected = 0;

		final g = Globals.games[selected];
		final key = g.box;
		if (key == null || key == "")
		{
			boxSprite.visible = false;
			return;
		}

		var gr:FlxGraphic = Preload.get(key);
		if (gr != null)
		{
			boxSprite.loadGraphic(gr);
			fitContainFlx(boxSprite, rightPaneX, rightPaneY, rightPaneW, rightPaneH);
			boxSprite.antialiasing = true;
			boxSprite.visible = true;
		}
		else
		{
			boxSprite.visible = false; // or keep last image if you prefer
			Preload.whenReady(key, () ->
			{
				// still selected?
				if (Globals.games.length == 0)
					return;
				var cur = Globals.games[selected];
				if (cur == null || cur.box != key)
					return;
				var gr2 = Preload.get(key);
				if (gr2 != null)
				{
					boxSprite.loadGraphic(gr2);
					fitContainFlx(boxSprite, rightPaneX, rightPaneY, rightPaneW, rightPaneH);
					boxSprite.antialiasing = true;
					boxSprite.visible = true;
				}
			});
		}
	}

	inline function fitContainFlx(s:flixel.FlxSprite, x:Int, y:Int, w:Int, h:Int):Void
	{
		var ow = s.frameWidth; // source dimensions
		var oh = s.frameHeight;
		if (ow <= 0 || oh <= 0)
		{
			s.visible = false;
			return;
		}

		var sc = Math.min(w / ow, h / oh);
		s.scale.set(sc, sc);
		s.updateHitbox();

		s.x = x + Std.int((w - s.width) * 0.5);
		s.y = y + Std.int((h - s.height) * 0.5);
	}
}

enum abstract SortMode(Int) from Int to Int
{
	var TitleAZ;
	var YearDesc;
	var Random;
}
