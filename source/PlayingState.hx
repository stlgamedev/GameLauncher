package;

class PlayingState extends FlxState
{
	var game:util.GameEntry;
	var quitHold:Float = 0.0;

	public function new(g)
	{
		super();
		this.game = g;
	}

	override public function create():Void
	{
		super.create();
		var t = new FlxText(0, FlxG.height * 0.5 - 20, FlxG.width, 'Pretend running: ' + game.title);
		t.setFormat(null, 28, FlxColor.WHITE, "center");
		add(t);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// dev convenience: ESC returns to menu (non-kiosk only)
		if (Globals.cfg.mode != "kiosk" && FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.switchState(() -> new GameSelectState());
		}

		// gamepad quit combo (example: BACK hold 1.5s)
		#if FLX_GAMEPAD
		if (FlxG.gamepads.anyPressed(BACK))
		{
			quitHold += elapsed;
			if (quitHold >= 1.5)
				FlxG.switchState(() -> new GameSelectState());
		}
		else
			quitHold = 0;
		#end
	}
}