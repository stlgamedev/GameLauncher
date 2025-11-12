package;

import openfl.display.Sprite;
import flixel.FlxGame;
import flixel.FlxState;
import BootState;
import UpdateOnlyState;
#if sys
import util.Globals;
#end

class Main extends Sprite
{
	public function new()
	{
		try
		{
			super();

			// Install global crash logger to capture uncaught errors where possible
			try { util.CrashLogger.install(); } catch (_:Dynamic) {}

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
		catch (e:Dynamic)
		{
			#if sys
			// Log the error and stack trace before restarting
			try
			{
				if (Globals.log != null)
				{
					Globals.log.line('[FATAL] Unhandled exception: ' + Std.string(e));
					var stack = haxe.CallStack.exceptionStack();
					if (stack != null && stack.length > 0)
					{
						for (frame in stack)
						{
							Globals.log.line('  ' + haxe.CallStack.toString([frame]));
						}
					}
				}
			}
			catch (_:Dynamic) {}
			Sys.println('Launcher crashed, restarting...');
			Sys.command(Sys.programPath(), Sys.args());
			#end
		}
	}
}
