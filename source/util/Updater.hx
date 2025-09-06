package util;

import haxe.Http;
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.zip.Entry;
import haxe.zip.Reader;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;

using StringTools;

class Updater
{
	// ---------- Public API ----------
	public static function checkAndMaybeUpdateApp(onDone:Bool->Void, onError:String->Void):Void
	{
		#if sys
		try
		{
			final base = ensureSlash(Globals.cfg.serverBase);
			final url = base;

			httpGet(url, function(html)
			{
				var bestName:String = null;
				var bestVer:Int = Globals.APP_VERSION; // define in your app
				var re = ~/href="(STLGameLauncher-v(\d+)\.exe)"/ig;

				while (re.match(html))
				{
					final name = re.matched(1);
					final ver = Std.parseInt(re.matched(2));
					if (ver != null && ver > bestVer)
					{
						bestVer = ver;
						bestName = name;
					}
				}

				if (bestName == null)
				{
					onDone(false);
					return;
				}

				Globals.log.line('[UPDATE] New APP installer: ' + bestName + ' (server ver ' + bestVer + ')');
				final tmp = tempPath(bestName);
				downloadFile(url + bestName, tmp, function()
				{
					Globals.log.line('[UPDATE] Running installer: ' + tmp);
					runInstallerAndExit(tmp);
					onDone(true);
				}, onError);
			}, onError);
		}
		catch (e:Dynamic)
		{
			onError(Std.string(e));
		}
		#else
		onDone(false);
		#end
	}

	public static function syncSubscription(subscription:String, onMessage:String->Void, onDone:Void->Void, onError:String->Void):Void
	{
		#if sys
		final base = ensureSlash(Globals.cfg.serverBase);
		final subRoot = base + ensureSlash(subscription);
		final localRoot = Globals.cfg.contentRootDir;
		final gamesLocal = Path.join([localRoot, "games"]);
		final trailersLocal = Path.join([localRoot, "trailers"]);
		final themesLocal = Path.join([localRoot, "theme"]);

		ensureDir(gamesLocal);
		ensureDir(trailersLocal);
		ensureDir(themesLocal);

		onMessage("Checking games…");
		httpList(subRoot + "games/", function(serverGames)
		{
			try
			{
				syncGames(serverGames, gamesLocal, subRoot + "games/", onMessage, function()
				{
					onMessage("Checking trailers…");
					httpList(subRoot + "trailers/", function(serverTrailers)
					{
						try
						{
							syncTrailers(serverTrailers, trailersLocal, subRoot + "trailers/", onMessage, function()
							{
								onMessage("Checking theme…");
								httpList(subRoot, function(rootFiles)
								{
									try
									{
										syncThemeZip(rootFiles, subRoot, themesLocal, onMessage, function()
										{
											onMessage("Sync complete.");
											onDone();
										}, onError);
									}
									catch (e:Dynamic)
										onError(Std.string(e));
								}, onError);
							}, onError);
						}
						catch (e:Dynamic)
							onError(Std.string(e));
					}, onError);
				}, onError);
			}
			catch (e:Dynamic)
				onError(Std.string(e));
		}, onError);
		#else
		onDone();
		#end
	}

	// ---------- Games ----------
	#if sys
	static function syncGames(serverList:Array<String>, localDir:String, serverUrl:String, onMessage:String->Void, onDone:Void->Void, onError:String->Void):Void
	{
		final serverMap = new Map<String, {ver:Int, name:String}>();
		for (fn in serverList)
		{
			if (!fn.toLowerCase().endsWith(".zip"))
				continue;
			final parsed = parseVersionedZip(fn);
			if (parsed == null)
				continue;
			serverMap.set(parsed.base, {ver: parsed.ver, name: fn});
		}

		final localMap = new Map<String, {best:Int, files:Array<String>}>();
		if (FileSystem.exists(localDir))
		{
			for (lf in FileSystem.readDirectory(localDir))
			{
				if (!lf.toLowerCase().endsWith(".zip"))
					continue;
				final parsed = parseVersionedZip(lf);
				if (parsed == null)
					continue;
				final key = parsed.base;
				if (!localMap.exists(key))
					localMap.set(key, {best: parsed.ver, files: [lf]});
				else
				{
					final cur = localMap.get(key);
					cur.best = Std.int(Math.max(cur.best, parsed.ver));
					cur.files.push(lf);
				}
			}
		}

		for (base in localMap.keys())
		{
			final item = localMap.get(base);
			if (!serverMap.exists(base))
			{
				for (lf in item.files)
					safeDeleteFile(Path.join([localDir, lf]), onMessage);
				localMap.remove(base);
				continue;
			}
			final serverVer = serverMap.get(base).ver;
			if (item.best != serverVer)
			{
				for (lf in item.files)
					safeDeleteFile(Path.join([localDir, lf]), onMessage);
				localMap.remove(base);
			}
		}

		downloadGamesSequential(serverMap, localMap, localDir, serverUrl, onMessage, onDone, onError);
	}

	static function downloadGamesSequential(serverMap:Map<String, {ver:Int, name:String}>, localMap:Map<String, {best:Int, files:Array<String>}>,
			localDir:String, serverUrl:String, onMessage:String->Void, onDone:Void->Void, onError:String->Void):Void
	{
		var toGet:Array<{base:String, name:String}> = [];
		for (base in serverMap.keys())
			if (!localMap.exists(base))
				toGet.push({base: base, name: serverMap.get(base).name});

		function loop(i:Int)
		{
			if (i >= toGet.length)
			{
				onDone();
				return;
			}
			final item = toGet[i];
			final dest = Path.join([localDir, item.name]);
			onMessage('Downloading game ${item.name}…');
			downloadFile(serverUrl + item.name, dest, function()
			{
				onMessage('Downloaded ${item.name}');
				loop(i + 1);
			}, onError);
		}
		loop(0);
	}

	static function parseVersionedZip(name:String):{base:String, ver:Int}
	{
		final m = ~/^(.*?)-v(\d+)\.zip$/i;
		if (!m.match(name))
			return null;
		final base = m.matched(1);
		final ver = Std.parseInt(m.matched(2));
		return (ver == null) ? null : {base: base, ver: ver};
	}
	#end

	// ---------- Trailers ----------
	#if sys
	static function syncTrailers(serverList:Array<String>, localDir:String, serverUrl:String, onMessage:String->Void, onDone:Void->Void,
			onError:String->Void):Void
	{
		final serverSet = new Map<String, Bool>();
		for (fn in serverList)
			if (isTrailerName(fn))
				serverSet.set(fn, true);

		if (FileSystem.exists(localDir))
		{
			for (lf in FileSystem.readDirectory(localDir))
			{
				if (!isTrailerName(lf))
					continue;
				if (!serverSet.exists(lf))
					safeDeleteFile(Path.join([localDir, lf]), onMessage);
			}
		}

		var toGet = [];
		for (fn in serverSet.keys())
		{
			final dest = Path.join([localDir, fn]);
			if (!FileSystem.exists(dest))
				toGet.push(fn);
		}

		function loop(i:Int)
		{
			if (i >= toGet.length)
			{
				onDone();
				return;
			}
			final name = toGet[i];
			onMessage('Downloading trailer ${name}…');
			downloadFile(serverUrl + name, Path.join([localDir, name]), function()
			{
				onMessage('Downloaded ${name}');
				loop(i + 1);
			}, onError);
		}
		loop(0);
	}

	static inline function isTrailerName(fn:String):Bool
	{
		final low = fn.toLowerCase();
		return low.endsWith(".mp4") || low.endsWith(".mov") || low.endsWith(".m4v") || low.endsWith(".webm");
	}
	#end

	// ---------- Theme ----------
	#if sys
	static function syncThemeZip(rootList:Array<String>, rootUrl:String, themeDestDir:String, onMessage:String->Void, onDone:Void->Void,
			onError:String->Void):Void
	{
		var best:String = null;
		var bestVer:Int = -1;
		for (fn in rootList)
		{
			final m = ~/^theme-v(\d+)\.zip$/i;
			if (m.match(fn))
			{
				final v = Std.parseInt(m.matched(1));
				if (v != null && v > bestVer)
				{
					bestVer = v;
					best = fn;
				}
			}
		}
		if (best == null)
		{
			onDone();
			return;
		}

		onMessage('Updating theme from ${best}…');
		final tmp = tempPath(best);
		downloadFile(rootUrl + best, tmp, function()
		{
			try
			{
				deleteDirRecursive(themeDestDir);
				ensureDir(themeDestDir);
				unzipTo(tmp, themeDestDir);
				onMessage("Theme updated.");
				safeDeleteFile(tmp, function(_) {});
				onDone();
			}
			catch (e:Dynamic)
			{
				onError(Std.string(e));
			}
		}, onError);
	}
	#end

	// ---------- HTTP ----------
	#if sys
	static function httpGet(url:String, onData:String->Void, onError:String->Void):Void
	{
		var h = new Http(url);
		h.onError = e -> onError(e);
		h.onData = d -> onData(d);
		h.request(false);
	}

	static function httpList(url:String, onList:Array<String>->Void, onError:String->Void):Void
	{
		httpGet(url, function(html)
		{
			var out = new Array<String>();
			var re = ~/href="([^"?"]+)"/ig;
			while (re.match(html))
			{
				var link = re.matched(1);
				if (link == "../")
					continue;
				if (link.endsWith("/"))
					continue;
				out.push(link);
			}
			onList(out);
		}, onError);
	}

	static function downloadFile(url:String, dest:String, onOk:Void->Void, onError:String->Void):Void
	{
		var h = new Http(url);
		h.onError = e -> onError(e);
		h.onBytes = function(b:Bytes)
		{
			try
			{
				ensureParentDir(dest);
				File.saveBytes(dest, b);
				onOk();
			}
			catch (e:Dynamic)
				onError(Std.string(e));
		}
		h.request(false);
	}

	static function runInstallerAndExit(absExe:String):Void
	{
		try
		{
			var p = new sys.io.Process(absExe, []);
			Sys.exit(0);
		}
		catch (e:Dynamic)
		{
			Globals.log.line("[UPDATE][ERROR] Failed to launch installer: " + Std.string(e));
		}
	}
	#end

	// ---------- Zip ----------
	#if sys
	static function unzipTo(zipPath:String, destDir:String):Void
	{
		var fin:FileInput = null;
		fin = File.read(zipPath, true);
		var reader = new Reader(fin);
		var entries = reader.read();
		// close early (Reader buffers internally)
		try
			fin.close()
		catch (_:Dynamic) {}

		for (e in entries)
			writeEntry(e, destDir);
	}

	static function writeEntry(e:Entry, destDir:String):Void
	{
		var name = e.fileName.replace("\\", "/");
		while (name.startsWith("/"))
			name = name.substr(1);
		if (name.indexOf("..") >= 0)
			return;

		var abs = Path.join([destDir, name]);

		if (e.fileSize == 0 && e.dataSize == 0 && (name.endsWith("/") || name.endsWith("\\")))
		{
			ensureDir(abs);
			return;
		}

		ensureParentDir(abs);
		var data = Reader.unzip(e);
		File.saveBytes(abs, data);
	}
	#end

	// ---------- FS helpers ----------
	#if sys
	static function tempPath(name:String):String
	{
		var base = Sys.getEnv("TEMP");
		if (base == null || base == "")
			base = Sys.getCwd();
		return Path.join([base, name]);
	}

	static function ensureSlash(s:String):String
		return (s != null && s != "" && !s.endsWith("/")) ? s + "/" : s;

	static function ensureDir(dir:String):Void
	{
		if (dir == null || dir == "")
			return;
		if (!FileSystem.exists(dir))
			FileSystem.createDirectory(dir);
	}

	static function ensureParentDir(path:String):Void
	{
		var d = Path.directory(path);
		if (d != "" && !FileSystem.exists(d))
			FileSystem.createDirectory(d);
	}

	static function safeDeleteFile(path:String, onMessage:String->Void):Void
	{
		try
		{
			if (FileSystem.exists(path) && !FileSystem.isDirectory(path))
			{
				FileSystem.deleteFile(path);
				onMessage("Deleted " + path);
			}
		}
		catch (e:Dynamic)
		{
			Globals.log.line("[UPDATE][WARN] Could not delete file: " + path + " :: " + Std.string(e));
		}
	}

	static function deleteDirRecursive(dir:String):Void
	{
		if (!FileSystem.exists(dir))
			return;
		if (!FileSystem.isDirectory(dir))
		{
			safeDeleteFile(dir, _ -> {});
			return;
		}
		for (f in FileSystem.readDirectory(dir))
		{
			var abs = Path.join([dir, f]);
			if (FileSystem.isDirectory(abs))
				deleteDirRecursive(abs);
			else
				safeDeleteFile(abs, _ -> {});
		}
		try
			FileSystem.deleteDirectory(dir)
		catch (_:Dynamic) {}
	}
	#end
}
