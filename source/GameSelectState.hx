package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import util.Config;
import util.Logger;

class GameSelectState extends FlxState
{
	var cfg:Config;
	var log:Logger;

	public function new(cfg:Config, log:Logger)
	{
		super();
		this.cfg = cfg;
		this.log = log;
	}

	override public function create():Void
	{
		super.create();
		FlxG.cameras.bgColor = 0xFF000000;

		var title = new FlxText(0, 0, FlxG.width, "STLGameDev Launcher\n(Game Select Placeholder)");
		title.setFormat(null, 24, 0xFFFFFFFF, "center");
		title.screenCenter();
		add(title);

		log.line("[STATE] Enter GameSelectState (theme=" + cfg.theme + ", mode=" + cfg.mode + ")");
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (cfg.mode == "kiosk" && FlxG.keys.justPressed.CONTROL && FlxG.keys.justPressed.ALT && FlxG.keys.justPressed.F12)
		{
			log.line("[EXIT] Kiosk Mode exit command pressed. Exiting launcher.");
			exit();
		}
		if (cfg.mode == "normal" && FlxG.keys.justPressed.ESCAPE)
		{
			log.line("[EXIT] ESC pressed (normal mode). Exiting launcher.");
			exit();
		}
	}

	public function exit(?Code:Int = 0):Void
	{
		try
		{
			log.close();
		}
		catch (_:Dynamic) {}
		Sys.exit(0);
	}
}
