package;

import flixel.FlxGame;
import openfl.display.Sprite;
import themes.ThemeLoader;
import util.Config;
import util.GameIndex;
import util.Globals;
import util.Logger.Log;
import util.Logger;
import util.Paths;

class Main extends Sprite
{
	public function new()
	{
		super();

		Paths.ensureLogs();
		Globals.log = new Logger();
		Log.line("[BOOT] Logs ready.");

		Globals.cfg = util.Config.loadOrCreate();
		Log.line("[BOOT] Config loaded. content_root=" + Globals.cfg.contentRootDir);

		// Phase C: Ensure content dirs based on config
		Paths.ensureContent();
		Log.line("[BOOT] Content dirs ensured.");

		// Phase D: (Phase 1‑A) discover games
		util.Globals.games = util.GameIndex.scanGames();
		Log.line("[BOOT] Discovered " + Globals.games.length + " game(s).");

		// ... continue to FlxGame
		addChild(new flixel.FlxGame(1920, 1080, () -> new GameSelectState(), 60, 60, true));
	}
}
