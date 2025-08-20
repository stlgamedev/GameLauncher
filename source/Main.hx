package;

import flixel.FlxGame;
import openfl.display.Sprite;
import themes.ThemeLoader;
import util.Config;
import util.Logger;
import util.Paths;

class Main extends Sprite {
    public function new() {
        super();

        Paths.ensureAll();
        final log = new Logger();
        final cfg = Config.loadOrCreate(log);
        final themeId = ThemeLoader.currentThemeId(cfg.theme);
        log.line("[THEME] Using theme: " + themeId);

        final width  = 1920;
        final height = 1080;
        final updateFPS = 60;
        final drawFPS   = 60;
        final skipSplash = true;

        // HF 6.1 signature: (w,h,state,updateFPS,drawFPS,skipSplash)
        addChild(new FlxGame(width, height, () -> new GameSelectState(cfg, log), updateFPS, drawFPS, skipSplash));

    }
}
