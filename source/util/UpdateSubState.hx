package util;

import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.Assets;

typedef UpdateSubStateCallback = Void->Void;

enum UpdateMode
{
	AppUpdate(bestName:String, bestVer:Int);
	ContentUpdate(toDelete:Array<String>, toDownload:Array<String>);
	AppUpdateOrContent(subscription:String);
}

class UpdateSubState extends FlxSubState
{
	var logText:FlxText;
	var mode:UpdateMode;
	var onDone:UpdateSubStateCallback;
	var started:Bool = false;

	// --- Semantic version helpers ---
	static function versionToArray(ver:Dynamic):Array<Int>
	{
		if (ver == null)
			return [0];
		var s = Std.string(ver).replace("_", ".");
		var parts = s.split(".");
		if (parts.length == 1 && s.indexOf("_") != -1)
			parts = s.split("_");
		var arr = [];
		for (p in parts)
		{
			var n = Std.parseInt(p);
			arr.push((n == null) ? 0 : n);
		}
		return arr;
	}

	static function compareVersions(a:Array<Int>, b:Array<Int>):Int
	{
		var len:Int = Math.ceil(Math.max(a.length, b.length));
		for (i in 0...len)
		{
			var ai = (i < a.length) ? a[i] : 0;
			var bi = (i < b.length) ? b[i] : 0;
			if (ai > bi)
				return 1;
			if (ai < bi)
				return -1;
		}
		return 0;
	}

	static function arrayToVersion(arr:Array<Int>):Int
	{
		// Return a comparable integer for legacy code (e.g., 1.1.0 => 10100)
		var v = 0;
		for (i in 0...arr.length)
			v = v * 100 + arr[i];
		return v;
	}

	public function new(mode:UpdateMode, onDone:UpdateSubStateCallback)
	{
		super();
		this.mode = mode;
		this.onDone = onDone;
	}

	override public function create():Void
	{
		super.create();
		bgColor = 0xFF000000;

		logText = new FlxText(40, 40, FlxG.width - 80, "Checking for updates…");
		logText.setFormat(null, 18, FlxColor.WHITE, "left");
		add(logText);

		started = false;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (!started)
		{
			started = true;
			append('[DEBUG] UpdateSubState started, mode=' + Std.string(mode));
			switch (mode)
			{
				case AppUpdate(bestName, bestVer):
					append('[DEBUG] AppUpdate mode: bestName=' + bestName + ', bestVer=' + bestVer);
					append('Downloading and running application installer…');
					checkAndMaybeUpdateApp(function(updated:Bool)
					{
						append('[DEBUG] checkAndMaybeUpdateApp callback: updated=' + updated);
						append('Installer launched, exiting app.');
						Sys.exit(0);
					}, function(err:String)
					{
						append('[DEBUG] checkAndMaybeUpdateApp error callback');
						append('[ERROR] App update failed: ' + err);
						closeAndContinue();
					});
				case ContentUpdate(toDelete, toDownload):
					append('[DEBUG] ContentUpdate mode: toDelete=' + toDelete.length + ', toDownload=' + toDownload.length);
					startContentUpdate(toDelete, toDownload);
				case AppUpdateOrContent(subscription):
					append('[DEBUG] AppUpdateOrContent mode: subscription=' + subscription);
					// First, check for app update
					append('Checking for app update…');
					checkForAppUpdate(function(bestName:String, bestVer:Int)
					{
						append('[DEBUG] checkForAppUpdate callback: bestName=' + bestName + ', bestVer=' + bestVer);
						if (bestName != null)
						{
							append('App update found: ' + bestName + ' (ver ' + bestVer + ').');
							// Switch to AppUpdate mode
							mode = AppUpdate(bestName, bestVer);
							started = false;
							return;
						}
						// No app update, check for content update
						append('No app update needed. Checking for content updates…');
						buildContentUpdateLists(subscription, function(toDelete:Array<String>, toDownload:Array<String>)
						{
							append('[DEBUG] buildContentUpdateLists callback: toDelete=' + toDelete.length + ', toDownload=' + toDownload.length);
							if (toDelete.length > 0 || toDownload.length > 0)
							{
								append('Content update needed.');
								mode = ContentUpdate(toDelete, toDownload);
								started = false;
							}
							else
							{
								append('No content update needed.');
								closeAndContinue();
							}
						}, function(err:String)
						{
							append('[DEBUG] buildContentUpdateLists error callback');
							append('[ERROR] Content update check failed: ' + err);
							closeAndContinue();
						});
					}, function(err:String)
					{
						append('[DEBUG] checkForAppUpdate error callback');
						append('[ERROR] App update check failed: ' + err);
						closeAndContinue();
					});
			}
		}
	}

	// --- App update logic ---
	static public function checkForAppUpdate(onResult:String->Int->Void, onError:String->Void):Void
	{
		#if sys
		try
		{
			final base = ensureSlash(Globals.cfg.serverBase);
			final url = base;
			httpGet(url, function(html)
			{
				appendStatic('[DEBUG] Server response for app update check:');
				appendStatic(html);
				var bestName:String = null;
				var bestVer:Array<Int> = versionToArray(Globals.APP_VERSION_STR);
				var re = ~/href="(STLGameLauncher-Setup-v([\d_]+)\.exe)"/ig;
				while (re.match(html))
				{
					final name = re.matched(1);
					final verStr = re.matched(2);
					final verArr = versionToArray(verStr);
					if (compareVersions(verArr, bestVer) > 0)
					{
						bestVer = verArr;
						bestName = name;
					}
				}
				if (bestName != null)
					onResult(bestName, arrayToVersion(bestVer));
				else
					onResult(null, -1);
			}, onError);
		}
		catch (e:Dynamic)
		{
			onError(Std.string(e));
		}
		#else
		onResult(null, -1);
		#end
	}

	static public function checkAndMaybeUpdateApp(onDone:Bool->Void, onError:String->Void):Void
	{
		#if sys
		try
		{
			final base = ensureSlash(Globals.cfg.serverBase);
			final url = base;
			httpGet(url, function(html)
			{
				var bestName:String = null;
				var bestVer:Array<Int> = versionToArray(Globals.APP_VERSION_STR);
				var re = ~/href="(STLGameLauncher-Setup-v([\d_]+)\.exe)"/ig;
				while (re.match(html))
				{
					final name = re.matched(1);
					final verStr = re.matched(2);
					final verArr = versionToArray(verStr);
					if (compareVersions(verArr, bestVer) > 0)
					{
						bestVer = verArr;
						bestName = name;
					}
				}
				if (bestName == null)
				{
					onDone(false);
					return;
				}
				appendStatic('[UPDATE] New APP installer: ' + bestName + ' (server ver ' + arrayToVersion(bestVer) + ')');
				final tmp = tempPath(bestName);
				downloadFile(url + bestName, tmp, function()
				{
					appendStatic('[UPDATE] Running installer: ' + tmp);
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

	// --- Content update logic ---
	function buildContentUpdateLists(subscription:String, onResult:Array<String>->Array<String>->Void, onError:String->Void):Void
	{
		#if sys
		try
		{
			final base = ensureSlash(Globals.cfg.serverBase);
			final subRoot = base + ensureSlash(subscription);
			final localRoot = Globals.cfg.contentRootDir;
			final gamesLocal = haxe.io.Path.join([localRoot, "games"]);
			final trailersLocal = haxe.io.Path.join([localRoot, "trailers"]);
			final themesLocal = haxe.io.Path.join([localRoot, "theme"]);

			var toDelete:Array<String> = [];
			var toDownload:Array<String> = [];

			// --- Games ---
			httpList(subRoot + "games/", function(serverGames)
			{
				append('[DEBUG] Server response for games list:');
				append(Std.string(serverGames));
				var serverMap = new Map<String, {ver:Int, name:String}>();
				for (fn in serverGames)
				{
					if (!fn.toLowerCase().endsWith(".zip"))
						continue;
					var parsed = parseVersionedZip(fn);
					if (parsed == null)
						continue;
					serverMap.set(parsed.base, {ver: parsed.ver, name: fn});
				}
				var localMap = new Map<String, Int>(); // base -> version
				if (sys.FileSystem.exists(gamesLocal))
				{
					for (lf in sys.FileSystem.readDirectory(gamesLocal))
					{
						var versionFile = haxe.io.Path.join([gamesLocal, lf, ".version"]);
						if (sys.FileSystem.isDirectory(haxe.io.Path.join([gamesLocal, lf])) && sys.FileSystem.exists(versionFile))
						{
							try
							{
								var v = Std.parseInt(sys.io.File.getContent(versionFile));
								if (v != null)
									localMap.set(lf, v);
							}
							catch (_:Dynamic) {}
						}
					}
				}
				// Debug: print local and server versions for each game
				for (base in serverMap.keys())
				{
					var serverVer = serverMap.get(base).ver;
					var localVer = localMap.exists(base) ? localMap.get(base) : null;
					append('[DEBUG] Game: ' + base + ' | serverVer=' + serverVer + ' | localVer=' + localVer);
					if (!localMap.exists(base) || localMap.get(base) != serverVer)
						toDownload.push(subRoot + "games/" + serverMap.get(base).name);
				}

				// --- Trailers ---
				httpList(subRoot + "trailers/", function(serverTrailers)
				{
					append('[DEBUG] Server response for trailers list:');
					append(Std.string(serverTrailers));
					var serverSet = new Map<String, Bool>();
					for (fn in serverTrailers)
						serverSet.set(fn, true);
					var localSet = new Map<String, Bool>();
					if (sys.FileSystem.exists(trailersLocal))
					{
						for (lf in sys.FileSystem.readDirectory(trailersLocal))
							localSet.set(lf, true);
					}
					// ToDelete: local trailers not on server
					for (lf in localSet.keys())
						if (!serverSet.exists(lf))
							toDelete.push(haxe.io.Path.join([trailersLocal, lf]));
					// ToDownload: server trailers not local
					for (fn in serverSet.keys())
						if (!localSet.exists(fn))
							toDownload.push(subRoot + "trailers/" + fn);

					// --- Theme ---
					httpList(subRoot, function(rootFiles)
					{
						append('[DEBUG] Server response for theme/root files list:');
						append(Std.string(rootFiles));
						var best:Int = -1;
						var bestName:String = null;
						for (fn in rootFiles)
						{
							var m = ~/^theme-v(\d+)\.zip$/i;
							if (m.match(fn))
							{
								var v = Std.parseInt(m.matched(1));
								if (v != null && v > best)
								{
									best = v;
									bestName = fn;
								}
							}
						}
						var localBest = -1;
						var versionFile = haxe.io.Path.join([themesLocal, ".version"]);
						if (sys.FileSystem.exists(versionFile))
						{
							try
							{
								var v = Std.parseInt(sys.io.File.getContent(versionFile));
								if (v != null)
									localBest = v;
							}
							catch (_:Dynamic) {}
						}
						// ToDownload: new theme zip
						if (best > localBest && bestName != null)
							toDownload.push(subRoot + bestName);

						onResult(toDelete, toDownload);
					}, onError);
				}, onError);
			}, onError);
		}
		catch (e:Dynamic)
		{
			onError(Std.string(e));
		}
		#else
		onResult([], []);
		#end
	}

	function startContentUpdate(toDelete:Array<String>, toDownload:Array<String>):Void
	{
		#if sys
		append('Starting content update...');
		var i = 0;
		var total = toDelete.length + toDownload.length;
		var self = this;
		// Remove manual update/draw pumping. Flixel handles UI updates automatically.
		// If you need to keep UI responsive, break up work into async callbacks and avoid blocking loops.
		function next()
		{
			// No manual event pumping needed. All work is async and UI remains responsive.
			if (i < toDelete.length)
			{
				var file = toDelete[i++];
				append('[STEP] Deleting ' + file + '...');
				try
				{
					if (sys.FileSystem.exists(file))
					{
						if (sys.FileSystem.isDirectory(file))
							sys.FileSystem.deleteDirectory(file);
						else
							sys.FileSystem.deleteFile(file);
						append('[STEP] Deleted ' + file);
					}
				}
				catch (e:Dynamic)
				{
					append('[ERROR] Failed to delete ' + file + ': ' + Std.string(e));
				}
				   // [TEMP DEBUG] Commented out async event pumping for troubleshooting
				   // haxe.Timer.delay(next, 10);
				   next();
				   return;
			}
			if (i - toDelete.length < toDownload.length)
			{
				var idx = i - toDelete.length;
				var url = toDownload[idx];
				var dest = getLocalPathForDownload(url);
				append('[STEP] Downloading ' + url + '...');
				downloadFile(url, dest, function()
				{
					append('[STEP] Downloaded ' + dest);
					// Unzip ANY zip file after download, write .version, then delete zip
					if (dest.toLowerCase().endsWith('.zip'))
					{
						append('[STEP] Unpacking zip...');
						try
						{
							var base = null;
							var ver = null;
							var m = ~/^(.*?)-v(\d+)\.zip$/i;
							var fname = haxe.io.Path.withoutDirectory(haxe.io.Path.normalize(dest));
							if (m.match(fname))
							{
								base = m.matched(1);
								ver = Std.parseInt(m.matched(2));
							}
							var outDir = null;
							if (url.indexOf('/games/') != -1 && base != null)
								outDir = haxe.io.Path.join([haxe.io.Path.directory(dest), base]);
							else if (url.toLowerCase().indexOf('theme-v') != -1)
								outDir = haxe.io.Path.directory(dest);
							if (outDir != null)
							{
								unzipTo(dest, outDir);
								append('[STEP] Unpacked zip.');
								// Write .version file
								if (ver != null)
								{
									var versionFile = haxe.io.Path.join([outDir, ".version"]);
									sys.io.File.saveContent(versionFile, Std.string(ver));
								}
								// Delete zip after extraction
								try
									sys.FileSystem.deleteFile(dest)
								catch (_:Dynamic) {}
							}
						}
						catch (e:Dynamic)
						{
							append('[ERROR] Failed to unpack zip: ' + Std.string(e));
						}
					}
					i++;
					   // [TEMP DEBUG] Commented out async event pumping for troubleshooting
					   // haxe.Timer.delay(next, 10);
					   next();
				}, function(err:String)
				{
					append('[ERROR] Failed to download ' + url + ': ' + err);
					i++;
					   // [TEMP DEBUG] Commented out async event pumping for troubleshooting
					   // haxe.Timer.delay(next, 10);
					   next();
				});
				return;
			}
			append('[STEP] Content update complete.');
			closeAndContinue();
		}
		next(); // All work is async, UI will remain responsive
		#else
		append('Content update not supported on this platform.');
		closeAndContinue();
		#end
	}

	// --- Helper for ToDownload local path ---
	function getLocalPathForDownload(url:String):String
	{
		var localRoot = Globals.cfg.contentRootDir;
		if (url.indexOf('/games/') != -1)
			return haxe.io.Path.join([localRoot, 'games', url.substr(url.lastIndexOf('/') + 1)]);
		if (url.indexOf('/trailers/') != -1)
			return haxe.io.Path.join([localRoot, 'trailers', url.substr(url.lastIndexOf('/') + 1)]);
		if (url.toLowerCase().indexOf('theme-v') != -1)
			return haxe.io.Path.join([localRoot, 'theme', url.substr(url.lastIndexOf('/') + 1)]);
		return haxe.io.Path.join([localRoot, url.substr(url.lastIndexOf('/') + 1)]);
	}

	// --- Zip extraction ---
	#if sys
	static function unzipTo(zipPath:String, destDir:String):Void
	{
		var fin:sys.io.FileInput = null;
		fin = sys.io.File.read(zipPath, true);
		var reader = new haxe.zip.Reader(fin);
		var entries = [for (e in reader.read()) e]; // Convert haxe.ds.List to Array
		try
			fin.close()
		catch (_:Dynamic) {}

		// Detect top-level folder
		var topLevel:String = null;
		for (e in entries)
		{
			var name = e.fileName.replace("\\", "/");
			while (name.startsWith("/"))
				name = name.substr(1);
			if (name.indexOf("..") >= 0)
				continue;
			var parts = name.split("/");
			if (parts.length > 1)
			{
				if (topLevel == null)
					topLevel = parts[0];
				else if (topLevel != parts[0])
				{
					topLevel = null;
					break;
				}
			}
			else
			{
				topLevel = null;
				break;
			}
		}

		for (e in entries)
		{
			var name = e.fileName.replace("\\", "/");
			while (name.startsWith("/"))
				name = name.substr(1);
			if (name.indexOf("..") >= 0)
				continue;
			var relName = name;
			if (topLevel != null && relName.startsWith(topLevel + "/"))
				relName = relName.substr(topLevel.length + 1);
			if (relName == "")
				continue;
			writeEntryWithName(e, destDir, relName);
		}
	}

	static function writeEntryWithName(e:haxe.zip.Entry, destDir:String, relName:String):Void
	{
		var name = relName;
		if (name.indexOf("..") >= 0)
			return;
		var abs = haxe.io.Path.join([destDir, name]);
		if (e.fileSize == 0 && e.dataSize == 0 && (name.endsWith("/") || name.endsWith("\\")))
		{
			if (!sys.FileSystem.exists(abs))
				sys.FileSystem.createDirectory(abs);
			return;
		}
		ensureParentDir(abs);
		var data = haxe.zip.Reader.unzip(e);
		sys.io.File.saveBytes(abs, data);
	}

	static function writeEntry(e:haxe.zip.Entry, destDir:String):Void
	{
		var name = e.fileName.replace("\\", "/");
		while (name.startsWith("/"))
			name = name.substr(1);
		if (name.indexOf("..") >= 0)
			return;
		var abs = haxe.io.Path.join([destDir, name]);
		if (e.fileSize == 0 && e.dataSize == 0 && (name.endsWith("/") || name.endsWith("\\")))
		{
			if (!sys.FileSystem.exists(abs))
				sys.FileSystem.createDirectory(abs);
			return;
		}
		ensureParentDir(abs);
		var data = haxe.zip.Reader.unzip(e);
		sys.io.File.saveBytes(abs, data);
	}
	#end

	// --- Versioned zip parser ---
	function parseVersionedZip(name:String):{base:String, ver:Int}
	{
		var m = ~/^(.*?)-v(\d+)\.zip$/i;
		if (!m.match(name))
			return null;
		var base = m.matched(1);
		var ver = Std.parseInt(m.matched(2));
		if (ver == null)
			return null;
		return {base: base, ver: ver};
	}

	// --- HTTP directory listing ---
	static function httpList(url:String, onList:Array<String>->Void, onError:String->Void):Void
	{
		httpGet(url, function(html)
		{
			var out = new Array<String>();
			var re = ~/href="([^"?]+)"/ig;
			var pos = 0;
			while (true)
			{
				if (!re.matchSub(html, pos))
					break;
				var link = re.matched(1);
				if (link != "../" && !link.endsWith("/"))
					out.push(link);
				pos = re.matchedPos().pos + re.matchedPos().len;
			}
			onList(out);
		}, onError);
	}

	inline function append(line:String):Void
	{
		Globals.log.line('[UPDATE] ' + line);
		logText.text = logText.text + "\n" + line;
	}

	public static function appendStatic(line:String):Void
	{
		Globals.log.line(line);
	}

	function closeAndContinue():Void
	{
		close();
		if (onDone != null)
			onDone();
	}

	// --- Utility functions (from Updater) ---
	#if sys
	static function ensureSlash(s:String):String
		return (s != null && s != "" && !s.endsWith("/")) ? s + "/" : s;

	static function tempPath(name:String):String
	{
		var base = Sys.getEnv("TEMP");
		if (base == null || base == "")
			base = Sys.getCwd();
		return haxe.io.Path.join([base, name]);
	}

	static function httpGet(url:String, onData:String->Void, onError:String->Void):Void
	{
		var h = new haxe.Http(url);
		h.onError = e -> onError(e);
		h.onData = d -> onData(d);
		h.request(false);
	}

	static function downloadFile(url:String, dest:String, onOk:Void->Void, onError:String->Void):Void
	{
		var h = new haxe.Http(url);
		h.onError = e -> onError(e);
		h.onBytes = function(b:haxe.io.Bytes)
		{
			try
			{
				ensureParentDir(dest);
				sys.io.File.saveBytes(dest, b);
				onOk();
			}
			catch (e:Dynamic)
				onError(Std.string(e));
		}
		h.request(false);
	}

	static function ensureParentDir(path:String):Void
	{
		var d = haxe.io.Path.directory(path);
		if (d != "" && !sys.FileSystem.exists(d))
			sys.FileSystem.createDirectory(d);
	}

	static function runInstallerAndExit(absExe:String):Void
	{
		try
		{
			var args = ["/VERYSILENT", "/NORESTART"];
			#if sys
			var wantUpdate = false;
			for (a in Sys.args())
				if (a == "--update")
				{
					wantUpdate = true;
					break;
				}
			if (wantUpdate)
				args.push("/LAUNCHUPDATE");
			#end
			var p = new sys.io.Process(absExe, args);
			Sys.exit(0);
		}
		catch (e:Dynamic)
		{
			Globals.log.line("[UPDATE][ERROR] Failed to launch installer: " + Std.string(e));
		}
	}
	#end
}
