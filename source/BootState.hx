import util.GameIndex;
#if sys
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.util.FlxColor;
import openfl.Assets;
import util.Paths;
import util.Globals;
import util.GameEntry;
import util.Logger;
import util.Config;
import util.UpdateSubState;
import util.CartBake;
import util.Analytics;
import util.InputMap;
import themes.Theme;
import flixel.FlxState;
import flixel.text.FlxText;
import aseprite.Aseprite;

typedef UpdateNeeded =
{
	app:Bool,
	content:Bool
};

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
				Globals.cfg = util.Config.load();
				if (Globals.cfg == null)
				{
					Log.line("[BOOT][ERROR] No config found, created default.");
					Sys.exit(1);
				}
				util.InputMap.inst.configure(Globals.cfg.controlsKeys, Globals.cfg.controlsPads);
				// Log only if config is missing or invalid

				// >>> App update check first, only check content if no app update <<<

				if (Globals.cfg.updateOnLaunch)
				{
					// Log only if update check fails
					openSubState(new util.UpdateSubState(util.UpdateMode.AppUpdateOrContent(Globals.cfg.subscription), function()
					{
						stepDone("Config");
					}));
					return;
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
				// Log only if content dir creation fails
				stepDone("Content dirs");

			case 3:
				// Scan games
				Globals.games = GameIndex.scanGames();
				if (Globals.games.length == 0)
					Log.line("[BOOT][ERROR] No games found.");
				stepDone("Scan games");

			case 4:
				// Load theme
				final themeDir = Paths.themeDir();
				Globals.theme = themes.Theme.load(themeDir);
				Globals.theme.preloadAssets();
				Globals.theme.preloadFonts();
				// Removed debug trace

				// Log only if theme load fails
				stepDone("Load theme");

			case 5:
				final frameAbs = Path.join([Globals.theme.dir, "cart_frame.png"]);
				final frameAbs = HxPath.join([Globals.theme.dir, "cart_frame.png"]);
				// Log only if cart frame is missing
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
		// Clean up old logs (>30 days)
		try
		{
			var logDir = Globals.cfg.logsRoot;
			if (FileSystem.exists(logDir) && FileSystem.isDirectory(logDir))
			{
				var now = Date.now().getTime();
				var cutoff = 30 * 24 * 60 * 60 * 1000;
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
							// Only log if a log file is deleted (optional)
						}
					}
					catch (_:Dynamic) {}
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
