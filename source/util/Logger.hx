package util;

import sys.io.FileOutput;
import sys.FileSystem;
import haxe.io.Path;
import sys.io.File;
import util.Paths;
import util.Globals;

class Log
{
	public static inline function line(s:String)
		return Globals.log.line(s);
}

class Logger
{
	var out:FileOutput;
	var dayStamp:String;

	public function new()
	{
		dayStamp = todayStamp();
		if (!FileSystem.exists(Paths.logsRoot()))
			FileSystem.createDirectory(Paths.logsRoot());
		final logPath = Path.join([Paths.logsRoot(), 'gl-' + dayStamp + '.log']);
		out = File.append(logPath, true);
		line("=== Launcher started (build " + getBuildStamp() + ") ===");
	}

	public function line(s:String):Void
	{
		out.writeString('[' + timestamp() + '] ' + s + '\n');
		out.flush();
	}

	public function close():Void
	{
		try
		{
			out.close();
		}
		catch (_:Dynamic) {}
	}

	static inline function pad(n:Int):String
		return (n < 10 ? "0" : "") + n;

	static function todayStamp():String
	{
		final d = Date.now();
		return '${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}';
	}

	static function timestamp():String
	{
		final d = Date.now();
		return '${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}';
	}

	static inline function getBuildStamp():String
		return "1.1.0";
}
