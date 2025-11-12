package;

import flixel.FlxG;
import flixel.FlxState;

/**
 * AttractState - Router to the actual attract mode implementation
 * Change which state is used here for easy testing
 */
class AttractState extends FlxState
{
	override public function create():Void
	{
		super.create();
		
		// CHOOSE YOUR ATTRACT MODE:
		// 1. HallwayAttractState - Pseudo-3D maze (doesn't work well)
		// 2. DvdAttractState - DVD logo bounce with floating screenshots (Recommended!)
		
		// FlxG.switchState(() -> new HallwayAttractState());
		FlxG.switchState(() -> new DvdAttractState());
	}
	
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		
		// Fallback exit (in case we're using simple placeholder)
		if (FlxG.keys.anyJustPressed([ANY]))
		{
			FlxG.switchState(() -> new GameSelectState());
		}
	}
}
