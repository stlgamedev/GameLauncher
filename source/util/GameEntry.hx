package util;

class GameEntry
{
	public var id:String;
	public var title:String;
	public var developers:Array<String>;
	public var description:String;
	public var year:Int;
	public var genres:Array<String>;
	public var players:Null<String>; // new field
	public var box(get, null):String;
	public var cartKey:Null<String>;
	public var cartPath:Null<String>;
	public var exe(get, null):String;

	public function new(id:String, title:String, developers:Array<String>, description:String, year:Int, genres:Array<String>, ?exeName:Null<String>,
			?players:Null<String>)
	{
		this.id = id;
		this.title = title;
		this.developers = developers;
		this.description = description;
		this.year = year;
		this.genres = genres;
		this.exe = exeName;
		this.players = players;
	}

	function get_box():String
	{
		return Path.join([Paths.gamesDir(), id, "box.png"]);
	}

	function get_exe():String
	{
		return Path.join([Paths.gamesDir(), id, exe]);
	}
}
