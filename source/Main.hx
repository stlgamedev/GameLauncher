package;

import openfl.display.Sprite;
import flixel.FlxGame;
import flixel.FlxState;
import BootState;
import UpdateOnlyState;

class Main extends Sprite
{
	public function new()
	{
		super();

		var wantUpdate = false;
		#if sys
		for (a in Sys.args())
			if (a == "--update")
			{
				wantUpdate = true;
				break;
			}
		#end

		var initState:Class<flixel.FlxState> = wantUpdate ? UpdateOnlyState : BootState;

		addChild(new flixel.FlxGame(1920, 1080, initState, 60, 60, true));
	}
}
