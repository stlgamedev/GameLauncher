package util;

import util.Logger;
import util.Config;
import util.GameEntry;
import themes.Theme;

class Globals
{
	public static var APP_VERSION:Int = 1;
	public static var APP_VERSION_STR:String = "1.0.0";

	public static var log:Logger;
	public static var cfg:Config;
	public static var games:Array<GameEntry>;
	public static var theme:Theme;
	public static var shaderKick:Null<Float> = 0.0;
	public static var selectedIndex:Null<Int> = 0;
	public static var input(get, null):util.InputMap;

	private static function get_input():util.InputMap
	{
		return util.InputMap.inst;
	}
}
