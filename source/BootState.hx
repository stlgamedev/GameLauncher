package;

import aseprite.Aseprite;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import haxe.io.Path as HxPath;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.geom.Matrix;
import util.CartBake;
import util.Config;
import util.GameIndex;
import util.Logger.Log;
import util.Paths;

class BootState extends FlxState
{
	var label:FlxText;
	var barBG:FlxSprite;
	var barFG:FlxSprite;
	var logo:Aseprite;

	var step:Int = 0;
	var totalSteps:Int = 7;
	var waitUntil:Float = 0;

	override public function create():Void
	{
		super.create();
		FlxG.cameras.bgColor = 0xFF000000;

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
				Globals.cfg = Config.loadOrCreate();
				Log.line("[BOOT] Config loaded. content_root=" + Globals.cfg.contentRootDir + ", theme=" + Globals.cfg.theme);
				stepDone("Config");

			case 2:
				// Content dirs (after cfg)
				try
					Paths.ensureContent()
				catch (_:Dynamic) {}
				Log.line("[BOOT] Content dirs ensured.");
				stepDone("Content dirs");

			case 3:
				// Scan games
				Globals.games = GameIndex.scanGames();
				Log.line("[BOOT] Discovered " + Globals.games.length + " game(s).");
				stepDone("Scan games");

			case 4:
				// Load theme
				final themeDir = HxPath.join([Paths.themesDir(), Globals.cfg.theme]);
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
				// Small grace so first cover has time to cache
				waitUntil = FlxG.game.ticks / 1000 + 0.35;
				stepDone("Preload settle");

			case 7:
				if ((FlxG.game.ticks / 1000) >= waitUntil)
				{
					FlxG.switchState(() -> new GameSelectState());
				}
		}

		updateProgress();
	}

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
