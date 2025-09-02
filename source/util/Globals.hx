package util;

class Globals
{
	public static var log:Logger;
	public static var cfg:Config;
	public static var games:Array<GameEntry>;
	public static var theme:Theme;
	public static var shaderKick:Null<Float> = 0.0; // 0..~1; ShaderNode decays it each frame
	public static var selectedIndex:Null<Int> = 0;
	public static var input(get, null):util.InputMap;

	private static function get_input():util.InputMap
	{
		return util.InputMap.inst;
	}
}
