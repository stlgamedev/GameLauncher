package;


class Main extends Sprite
{
	public function new()
	{
		super();

		addChild(new flixel.FlxGame(1920, 1080, () -> new BootState(), 60, 60, true));
	}
}
