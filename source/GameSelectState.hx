package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import util.Config;
import util.Globals;
import util.Logger.Log;
import util.Logger;

class GameSelectState extends FlxState
{

	public function new()
	{
		super();

	}

	override public function create():Void
	{
		super.create();
		FlxG.cameras.bgColor = 0xFF000000;

		var title = new FlxText(0, 0, FlxG.width, "STLGameDev Launcher\n(Game Select Placeholder)");
		title.setFormat(null, 24, 0xFFFFFFFF, "center");
		title.screenCenter();
		add(title);

		Log.line("[STATE] Enter GameSelectState (theme=" + Globals.cfg.theme + ", mode=" + Globals.cfg.mode + ")");
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (Globals.cfg.mode == "kiosk" && FlxG.keys.justPressed.CONTROL && FlxG.keys.justPressed.ALT && FlxG.keys.justPressed.F12)
		{
			Log.line("[EXIT] Kiosk Mode exit command pressed. Exiting launcher.");
			exit();
		}
		if (Globals.cfg.mode == "normal" && FlxG.keys.justPressed.ESCAPE)
		{
			Log.line("[EXIT] ESC pressed (normal mode). Exiting launcher.");
			exit();
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
}
