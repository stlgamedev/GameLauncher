package;



class BootState extends FlxState
{
	var label:FlxText;
	var barBG:FlxSprite;
	var barFG:FlxSprite;
	var logo:Aseprite;

	var step:Int = 0;
	var totalSteps:Int = 6;
	var waitUntil:Float = 0; // for the preload grace window

	override public function create():Void
	{
		super.create();
		FlxG.cameras.bgColor = 0xFF000000;

		label = new FlxText(0, FlxG.height * 0.6, FlxG.width, "Loading…");
		label.setFormat(null, 24, FlxColor.WHITE, "center");
		add(label);

		barBG = new FlxSprite(FlxG.width * 0.2, FlxG.height * 0.7).makeGraphic(Std.int(FlxG.width * 0.6), 12, 0xFF303036);
		barFG = new FlxSprite(barBG.x, barBG.y).makeGraphic(1, 12, 0xFFE0E0E0);
		add(barBG);
		add(barFG);

		logo = Aseprite.fromBytes(Assets.getBytes("assets/images/spinning_icon.aseprite"));

		logo.play();
		logo.mouseEnabled = logo.mouseChildren = false;
		FlxG.stage.addChild(logo);
		var sw = FlxG.stage.stageWidth;
		var sh = FlxG.stage.stageHeight;

		var maxW = Std.int(sw * 0.12);
		var maxH = Std.int(sh * 0.12);
		fitContainOpenFL(logo, sw - maxW - 24, sh - maxH - 24, maxW, maxH);
		// Start at step 0
		step = 0;
	}

	inline function fitContainOpenFL(d:openfl.display.DisplayObject, x:Int, y:Int, w:Int, h:Int):Void
	{
		// compute natural size at scale = 1
		d.scaleX = d.scaleY = 1;
		var ow = d.width, oh = d.height;
		if (ow <= 0 || oh <= 0)
			return;

		var sc = Math.min(w / ow, h / oh);
		d.scaleX = d.scaleY = sc;

		d.x = x + Std.int((w - d.width) * 0.5);
		d.y = y + Std.int((h - d.height) * 0.5);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		switch (step)
		{
			case 0:
				// Logs
				try
					Paths.ensureLogs()
				catch (_:Dynamic) {}
				Globals.log = new Logger();
				Globals.log.line("[BOOT] Logs ready.");
				stepDone("Logs");
			case 1:
				// Config
				Globals.cfg = Config.loadOrCreate();
				Globals.log.line("[BOOT] Config loaded. content_root=" + Globals.cfg.contentRootDir);
				stepDone("Config");
			case 2:
				// Content dirs
				try
					Paths.ensureContent()
				catch (_:Dynamic) {}
				Globals.log.line("[BOOT] Content dirs ensured.");
				stepDone("Content dirs");
			case 3:
				// Scan games
				Globals.games = GameIndex.scanGames();
				Globals.log.line("[BOOT] Discovered " + Globals.games.length + " game(s).");
				stepDone("Scan games");
			case 4:
				Globals.theme = Theme.load(Path.join([Paths.DIR_THEMES, Globals.cfg.theme]));
				Globals.theme.preloadAssets();
				// Globals.theme = Theme.load(Globals.cfg.themeDir);
				stepDone("Load theme");
			case 5:
				// Preload box art (Flixel cache)
				Preload.preloadGamesBoxArt(Globals.games);
				// small grace period so first cover likely shows
				waitUntil = FlxG.game.ticks / 1000 + 0.5; // ~500ms
				stepDone("Preload covers (kickoff)");
			case 6:
				// Wait until either all covers cached or we hit the time budget
				if (coversReady() || (FlxG.game.ticks / 1000) >= waitUntil)
				{
					stepDone("Preload covers (settled)");
				}
			case 7:
				// Go!
				FlxG.switchState(() -> new GameSelectState());
		}

		updateProgress();
	}

	inline function stepDone(name:String):Void
	{
		Globals.log.line("[BOOT] " + name + " done.");
		step++;
	}

	function coversReady():Bool
	{
		for (g in Globals.games)
		{
			if (g.box == null || g.box == "")
				continue;
			if (!Preload.has(g.box))
				return false;
		}
		return true;
	}

	function updateProgress():Void
	{
		var pct:Float = Math.min(step / totalSteps, 1.0);
		label.text = "Loading… " + Std.int(pct * 100) + "%";
		var w:Int = Std.int((barBG.width) * pct);
		barFG.makeGraphic(Std.int(Math.max(w, 1)), 12, 0xFFE0E0E0);
	}

	override public function destroy()
	{
		label = FlxDestroyUtil.destroy(label);
		barBG = FlxDestroyUtil.destroy(barBG);
		barFG = FlxDestroyUtil.destroy(barFG);
		if (logo != null)
		{
			if (logo.parent != null)
			{
				logo.parent.removeChild(logo);
			}

			logo = null;
		}
		super.destroy();
	}
}
