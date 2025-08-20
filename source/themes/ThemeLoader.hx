package themes;

class ThemeLoader
{
	public static function currentThemeId(?requested:String):String
	{
		return requested == null || requested == "" ? "default" : requested;
	}
	// Later: load .theme zip or fallback to embedded /assets/theme_default
}
