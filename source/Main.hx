package;


class Main extends Sprite
{
	public function new()
	{

		super();

		#if haxeui_flixel
		if (!haxe.ui.Toolkit.initialized) {
			haxe.ui.Toolkit.init();
		}
		#end

		addChild(new flixel.FlxGame(1920, 1080, () -> new BootState(), 60, 60, true));
	}
}

