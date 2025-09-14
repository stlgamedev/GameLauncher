package util;

using StringTools;

class GameIndex
{
	public static function scanGames():Array<GameEntry>
	{
		var games:Array<GameEntry> = [];
		for (name in Paths.safeReadDir(Paths.gamesDir()))
		{
			if (name.length == 0 || name.charAt(0) == '.')
				continue;
			final gPath:String = Path.join([Paths.gamesDir(), name]);
			if (!FileSystem.isDirectory(gPath))
				continue;
			final jsonPath:String = Path.join([gPath, "game.json"]);
			if (!FileSystem.exists(jsonPath))
				continue;
			try
			{
				final rawJson:String = File.getContent(jsonPath);
				final data:Dynamic = Json.parse(rawJson);
				final title:Null<String> = Paths.strOrNull(data.title);
				if (title == null || title == "")
					continue;
				var devs:Array<String> = [];
				if (Std.isOfType(data.developers, String))
					devs = [Std.string(data.developers)];
				else if (Std.isOfType(data.developers, Array))
					devs = cast data.developers;
				if (devs == null)
					devs = [];
				devs.map(function(d:String):String return d.trim());
				var year:Int = 0;
				if (data.year != null)
					year = data.year;
				var desc:String = Paths.strOrEmpty(data.description);
				var genres:Array<String> = [];
				if (Std.isOfType(data.genres, String))
					genres = [Std.string(data.genres)];
				else if (Std.isOfType(data.genres, Array))
					genres = cast data.genres;
				if (genres == null)
					genres = [];
				genres.map(function(g:String):String return g.trim());
				final exeName:Null<String> = Paths.strOrNull(data.exe);
				games.push(new GameEntry(name, title, devs, desc, year, genres, exeName));
			}
			catch (_:Dynamic) {}
		}
		return games;
	}
}
