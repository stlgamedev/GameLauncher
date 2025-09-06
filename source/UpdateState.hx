package;

import aseprite.Aseprite;
import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.Assets;
import util.Updater;

class UpdateState extends FlxState
{
	var logText:FlxText;
	var spinner:Aseprite;

	override public function create():Void
	{
		super.create();
		bgColor = 0xFF000000;

		logText = new FlxText(40, 40, FlxG.width - 80, "Checking for updates…");
		logText.setFormat(null, 18, FlxColor.WHITE, "left");
		add(logText);

		// BR spinner (same asset/placement as other states)
		try
		{
			var bytes = Assets.getBytes("assets/images/spinning_icon.aseprite");
			spinner = Aseprite.fromBytes(bytes);
			spinner.play();
			spinner.mouseEnabled = spinner.mouseChildren = false;
			FlxG.stage.addChild(spinner);
			fitOpenFL(spinner, FlxG.stage.stageWidth, FlxG.stage.stageHeight);
		}
		catch (_:Dynamic) {}

		runPipeline();
	}

	override public function destroy():Void
	{
		if (spinner != null && spinner.parent != null)
			spinner.parent.removeChild(spinner);
		spinner = null;
		super.destroy();
	}

	inline function fitOpenFL(d:openfl.display.DisplayObject, sw:Int, sh:Int):Void
	{
		var maxW = Std.int(sw * 0.12), maxH = Std.int(sh * 0.12);
		d.scaleX = d.scaleY = 1;
		var ow = d.width, oh = d.height;
		if (ow <= 0 || oh <= 0)
			return;
		var sc = Math.min(maxW / ow, maxH / oh);
		d.scaleX = d.scaleY = sc;
		d.x = sw - Std.int(d.width) - 24;
		d.y = sh - Std.int(d.height) - 24;
	}

	/* ----------------------------------------------------------- */
	/*						 PIPELINE                            */
	/* ----------------------------------------------------------- */
	function runPipeline():Void
	{
		// 1) Check app installer
		append("[1/2] Checking application installer…");
		Updater.checkAndMaybeUpdateApp(function(updated:Bool)
		{
			if (updated)
			{
				// We launched the installer and exited; this instance likely won’t continue.
				// If it does, still continue to content (harmless).
			}
			else
			{
				append("[1/2] App up-to-date.");
			}
			// 2) Content sync for the single subscription
			startContentSync();
		}, function(err:String)
		{
			append("[ERROR] App update: " + err);
			// Continue with content even if app check failed
			startContentSync();
		});
	}

	function startContentSync():Void
	{
		final cfg = Globals.cfg;
		if (cfg == null)
		{
			fail("[UPDATE] No config loaded.");
			return;
		}

		var sub = (cfg.subscription != null && cfg.subscription != "") ? cfg.subscription : "default";
		note("[2/2] Syncing content for subscription = " + sub);

		Updater.syncSubscription(sub, function(msg:String)
		{
			note(msg); // per-step messages from util.Updater
		}, function()
		{
			note("[2/2] Content sync complete.");
			done();
		}, function(err:String)
		{
			fail("[UPDATE] Content sync failed: " + err);
			done(); // still return to app so user can proceed
		});
	}

	/* ----------------------------------------------------------- */
	/*					LOG/PROGRESS HELPERS                     */
	/* ----------------------------------------------------------- */
	inline function append(line:String):Void
	{
		Globals.log.line("[UPDATE] " + line);
		logText.text = logText.text + "\n" + line;
	}

	inline function note(line:String):Void
	{
		append(line);
	}

	inline function fail(line:String):Void
	{
		append(line);
	}

	function done():Void
	{
		append("Returning to launcher…");
		// Go back to BootState so it can continue its normal flow.
		FlxG.switchState(() -> new BootState());
	}
}
