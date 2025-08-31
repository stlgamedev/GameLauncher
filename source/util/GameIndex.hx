package util;



using StringTools;

class GameIndex
{
	public static function scanGames():Array<GameEntry>
	{
		var games:Array<GameEntry> = [];
		for (name in safeReadDir(Paths.gamesDir()))
		{
			if (name.length == 0 || name.charAt(0) == '.')
				continue;
			final gPath:String = Path.join([Paths.gamesDir(), name]);
			if (!FileSystem.isDirectory(gPath))
				continue;
			final jsonPath:String = Path.join([gPath, "game.json"]);
			if (!FileSystem.exists(jsonPath))
			{
				Log.line("GameIndex.scanGames: Skipping game without game.json: " + gPath);
				continue;
			}

			trace("GameIndex.scanGames: Scanning game: " + name);

			try
			{
				final rawJson:String = File.getContent(jsonPath);
				final data:Dynamic = Json.parse(rawJson);

				final title:Null<String> = strOrNull(data.title);

				if (title == null || title == "")
				{
					Log.line('GameIndex: "$name" missing "title"');
					continue;
				}

				var devs:Array<String> = [];
				if (Std.isOfType(data.developers, String))
				{
					devs = [Std.string(data.developers)];
				}
				else if (Std.isOfType(data.developers, Array))
				{
					devs = cast data.developers;
					if (devs == null)
						devs = [];
				}
				devs.map(function(d:String):String
				{
					return d.trim();
				});

				var year:Int = 0;
				if (data.year != null)
					year = data.year;

				var desc:String = strOrEmpty(data.description);

				var genres:Array<String> = [];
				if (Std.isOfType(data.genres, String))
				{
					genres = [Std.string(data.genres)];
				}
				else if (Std.isOfType(data.genres, Array))
				{
					genres = cast data.genres;
					if (genres == null)
						genres = [];
				}
				genres.map(function(g:String):String
				{
					return g.trim();
				});

				final exeName:Null<String> = strOrNull(data.exe);

				games.push(new GameEntry(name, title, devs, desc, year, genres, exeName));
			}
		}
		return games;
	}

	static inline function safeReadDir(dir:String):Array<String>
	{
		try
			return FileSystem.readDirectory(dir)
		catch (_:Dynamic)
			return [];
	}

	static inline function strOrNull(v:Dynamic):Null<String>
	{
		return v == null ? null : Std.string(v).trim();
	}

	static inline function strOrEmpty(v:Dynamic):String
	{
		return v == null ? "" : Std.string(v).trim();
	}
}
