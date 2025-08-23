package util;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import util.Globals;
import util.Logger.Log;

using StringTools;

typedef GameEntry =
{
	id:String,
	title:String,
	developers:Array<String>,
	year:Int,
	description:String,
	genres:Array<String>
}

class GameIndex
{
	public static function scanGames():Array<GameEntry>
	{
		var games:Array<GameEntry> = [];
		trace("GameIndex.scanGames: Scanning games in " + Paths.DIR_GAMES);
		trace(safeReadDir(Paths.DIR_GAMES));
		for (name in safeReadDir(Paths.DIR_GAMES))
		{
			if (name.length == 0 || name.charAt(0) == '.')
				continue;
			final gPath:String = Path.join([Paths.DIR_GAMES, name]);
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
					year = Std.parseInt(data.year);

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

				games.push({
					id: name,
					title: title,
					developers: devs,
					year: year,
					description: desc,
					genres: genres
				});
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