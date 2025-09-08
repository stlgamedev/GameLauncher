package;

import flixel.FlxG;
import flixel.FlxState;
import util.UpdateSubState;

class UpdateOnlyState extends FlxState {
    override public function create():Void {
        super.create();
        // Load config, get subscription
        var cfg = Globals.cfg;
        var subscription = cfg.subscription;
        // Check for app update first
        util.UpdateSubState.checkForAppUpdate(function(bestName:String, bestVer:Int) {
            if (bestName != null) {
                // App update found: download and run installer silently, then exit
                util.UpdateSubState.appendStatic('[UPDATE] App update found: ' + bestName + ' (ver ' + bestVer + ').');
                util.UpdateSubState.checkAndMaybeUpdateApp(function(updated:Bool) {
                    Sys.exit(0);
                }, function(err:String) {
                    util.UpdateSubState.appendStatic('[ERROR] App update failed: ' + err);
                    Sys.exit(1);
                });
                return;
            }
            // No app update, check for content update
            util.UpdateSubState.appendStatic('No app update needed. Checking for content updates…');
            var sub = subscription;
            var substate = new util.UpdateSubState(util.UpdateMode.AppUpdateOrContent(sub), function() {
                // After content update, exit
                Sys.exit(0);
            });
            FlxG.state.openSubState(substate);
        }, function(err:String) {
            util.UpdateSubState.appendStatic('[ERROR] App update check failed: ' + err);
            Sys.exit(1);
        });
    }
}
