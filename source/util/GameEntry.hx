package util;



class GameEntry
{
	public var id:String;
	public var title:String;
	public var developers:Array<String>;
	public var description:String;
	public var year:Int;
	public var genres:Array<String>;
	public var box(get, null):String;

	public function new(id:String, title:String, developers:Array<String>, description:String, year:Int, genres:Array<String>)
	{
		this.id = id;
		this.title = title;
		this.developers = developers;
		this.description = description;
		this.year = year;
		this.genres = genres;
	}

	function get_box():String
	{
		return Path.join([Paths.DIR_GAMES, id, "box.png"]);
	}
}