package;

import flixel.FlxG;
import flixel.FlxState;
import util.Globals;
import util.UpdateSubState;

class UpdateOnlyState extends FlxState
{
	override public function create():Void
	{
		super.create();
		var cfg = Globals.cfg;
		var subscription = cfg.subscription;
		util.UpdateSubState.checkForAppUpdate(function(bestName:String, bestVer:Int)
		{
			if (bestName != null)
			{
				util.UpdateSubState.appendStatic('[UPDATE] App update found: ' + bestName + ' (ver ' + bestVer + ').');
				util.UpdateSubState.checkAndMaybeUpdateApp(function(updated:Bool)
				{
					Sys.exit(0);
				}, function(err:String)
				{
					util.UpdateSubState.appendStatic('[ERROR] App update failed: ' + err);
					Sys.exit(1);
				});
				return;
			}
			util.UpdateSubState.appendStatic('No app update needed. Checking for content updates…');
			var sub = subscription;
			var substate = new util.UpdateSubState(util.UpdateMode.AppUpdateOrContent(sub), function()
			{
				Sys.exit(0);
			});
			FlxG.state.openSubState(substate);
		}, function(err:String)
		{
			util.UpdateSubState.appendStatic('[ERROR] App update check failed: ' + err);
			Sys.exit(1);
		});
	}
}
