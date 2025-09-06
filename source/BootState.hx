package;

#if sys
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

class BootState extends FlxState
{
	var label:FlxText;
	var barBG:FlxSprite;
	var barFG:FlxSprite;
	var logo:Aseprite;

	var step:Int = 0;
	var totalSteps:Int = 8;
	var waitUntil:Float = 0;

	override public function create():Void
	{
		super.create();
		FlxG.cameras.bgColor = 0xFF000000;
		FlxG.mouse.visible = FlxG.mouse.enabled = false;

		label = new FlxText(0, Std.int(FlxG.height * 0.60), FlxG.width, "Loading…");
		label.setFormat(null, 24, FlxColor.WHITE, "center");
		add(label);

		barBG = new FlxSprite(Std.int(FlxG.width * 0.20), Std.int(FlxG.height * 0.70)).makeGraphic(Std.int(FlxG.width * 0.60), 12, 0xFF303036);
		barFG = new FlxSprite(barBG.x, barBG.y).makeGraphic(1, 12, 0xFFE0E0E0);
		add(barBG);
		add(barFG);

		logo = Aseprite.fromBytes(Assets.getBytes("assets/images/spinning_icon.aseprite"));
		logo.play();
		logo.mouseEnabled = logo.mouseChildren = false;
		FlxG.stage.addChild(logo);
		fitOpenFL(logo, FlxG.stage.stageWidth, FlxG.stage.stageHeight);

		step = 0;
	}

	inline function fitOpenFL(d:openfl.display.DisplayObject, sw:Int, sh:Int):Void
	{
		// bottom-right 12%
		var maxW = Std.int(sw * 0.12);
		var maxH = Std.int(sh * 0.12);
		d.scaleX = d.scaleY = 1;
		var ow = d.width, oh = d.height;
		if (ow <= 0 || oh <= 0)
			return;
		var sc = Math.min(maxW / ow, maxH / oh);
		d.scaleX = d.scaleY = sc;
		d.x = sw - Std.int(d.width) - 24;
		d.y = sh - Std.int(d.height) - 24;
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
				Globals.log = new util.Logger();
				Log.line("=== Launcher started ===");
				stepDone("Logs");
			case 1:
				// Config
				Globals.cfg = util.Config.loadOrCreate();
				util.InputMap.inst.configure(Globals.cfg.controlsKeys, Globals.cfg.controlsPads);
				Log.line("[BOOT] Config loaded. content_root=" + Globals.cfg.contentRootDir + ", subscription=" + Globals.cfg.subscription);

				// >>> Add this early exit for auto-update <<<
				if (Globals.cfg.updateOnLaunch)
				{
					Log.line("[BOOT] update_on_launch=true -> switching to UpdateState");
					FlxG.switchState(() -> new UpdateState());
					return; // IMPORTANT: stop the boot pipeline; UpdateState will come back to BootState
				}

				stepDone("Config");

			case 2:
				// Content dirs (after cfg)
				try
					Paths.ensureContent()
				catch (_:Dynamic) {}
				#if sys
				cleanupLogs();
				#end
				Log.line("[BOOT] Content dirs ensured.");
				stepDone("Content dirs");

			case 3:
				// Scan games
				Globals.games = GameIndex.scanGames();
				Log.line("[BOOT] Discovered " + Globals.games.length + " game(s).");
				stepDone("Scan games");

			case 4:
				// Load theme
				final themeDir = Paths.themeDir();
				Globals.theme = themes.Theme.load(themeDir);
				Globals.theme.preloadAssets();
				Globals.theme.preloadFonts();
				trace('Font cache size: ' + Globals.theme._fontCache); // or expose a method to read it

				Log.line("[BOOT] Theme loaded from: " + themeDir);
				stepDone("Load theme");

			case 5:
				// Bake Carts (small, disk-friendly)
				final frameAbs = HxPath.join([Globals.theme.dir, "cart_frame.png"]);
				Log.line("[BOOT] Cart frame = " + frameAbs);
				CartBake.TARGET_WIDTH = 200; // tweakable
				CartBake.buildAll(Globals.games, frameAbs);
				stepDone("Bake carts");

			case 6:
				util.Analytics.init(Globals.cfg.contentRootDir);
				stepDone("Analytics");

			case 7:
				// Small grace so first cover has time to cache
				waitUntil = FlxG.game.ticks / 1000 + 0.35;
				stepDone("Preload settle");

			case 8:
				if ((FlxG.game.ticks / 1000) >= waitUntil)
				{
					FlxG.switchState(() -> new GameSelectState());
				}
		}

		updateProgress();
	}

	#if sys
	function cleanupLogs():Void
	{
		// --- Clean up old logs (>30 days) ---
		try
		{
			var logDir = Globals.cfg.logsRoot; // already normalized by Config
			if (FileSystem.exists(logDir) && FileSystem.isDirectory(logDir))
			{
				var now = Date.now().getTime();
				var cutoff = 30 * 24 * 60 * 60 * 1000; // 30 days in ms

				for (f in FileSystem.readDirectory(logDir))
				{
					var abs = Path.join([logDir, f]);
					try
					{
						var stat = FileSystem.stat(abs);
						var age = now - stat.mtime.getTime();
						if (age > cutoff)
						{
							FileSystem.deleteFile(abs);
							Globals.log.line("[LOG] Deleted old log: " + abs);
						}
					}
					catch (_:Dynamic)
					{
						// ignore bad entries
					}
				}
			}
		}
		catch (e:Dynamic)
		{
			Globals.log.line("[LOG][ERROR] Failed log cleanup: " + Std.string(e));
		}
	}
	#end

	inline function stepDone(name:String):Void
	{
		Log.line("[BOOT] " + name + " done.");
		step++;
	}

	function updateProgress():Void
	{
		var pct:Float = Math.min(step / totalSteps, 1.0);
		label.text = "Loading… " + Std.int(pct * 100) + "%";
		var w:Int = Std.int((barBG.width) * pct);
		barFG.makeGraphic((w <= 0 ? 1 : w), 12, 0xFFE0E0E0);
	}

	override public function destroy()
	{
		label = FlxDestroyUtil.destroy(label);
		barBG = FlxDestroyUtil.destroy(barBG);
		barFG = FlxDestroyUtil.destroy(barFG);
		if (logo != null && logo.parent != null)
			logo.parent.removeChild(logo);
		logo = null;
		super.destroy();
	}
}
