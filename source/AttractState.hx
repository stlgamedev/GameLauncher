package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.io.Path;
import sys.FileSystem;
#if hxcodec
import hxcodec.flixel.FlxVideo;
#end

class AttractState extends FlxState
{
	var videos:Array<String> = [];
	var vidIdx:Int = -1;
	var label:FlxText;
	#if hxcodec
	var player:FlxVideo;
	#end

	override public function create():Void
	{
		super.create();
		bgColor = 0xFF000000;

		label = new FlxText(0, 0, FlxG.width, "");
		label.setFormat(null, 24, FlxColor.WHITE, "center");
		label.y = FlxG.height - 40;
		add(label);

		buildVideoList();

		#if hxcodec
		if (videos.length == 0)
		{
			label.text = "No trailers found in: " + util.Paths.trailersDir();
			// After a brief pause, go back
			new FlxTimer().start(1.0, _ -> FlxG.switchState(() -> new GameSelectState()));
			return;
		}
		startNextVideo();
		#else
		label.text = "hxCodec not available on this target.";
		new FlxTimer().start(1.0, _ -> FlxG.switchState(() -> new GameSelectState()));
		#end
	}

	override public function destroy():Void
	{
		#if hxcodec
		if (player != null)
		{
			try
				player.stop()
			catch (_:Dynamic) {}
			remove(player, true);
			player = null;
		}
		#end
		super.destroy();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (anyUserActivity())
		{
			#if hxcodec
			if (player != null)
				try
					player.stop()
				catch (_:Dynamic) {}
			#end
			FlxG.switchState(() -> new GameSelectState());
			return;
		}
	}

	function buildVideoList():Void
	{
		videos = [];
		final dir = util.Paths.trailersDir();

		#if sys
		if (FileSystem.exists(dir) && FileSystem.isDirectory(dir))
		{
			for (name in FileSystem.readDirectory(dir))
			{
				final lower = name.toLowerCase();
				if (StringTools.endsWith(lower, ".mp4") || StringTools.endsWith(lower, ".webm"))
				{
					videos.push(Path.join([dir, name]));
				}
			}
		}
		#end

		if (videos.length > 1)
			FlxG.random.shuffle(videos);
		vidIdx = -1;
	}

	#if hxcodec
	function startNextVideo():Void
	{
		if (videos.length == 0)
			return;
		vidIdx++;
		if (vidIdx >= videos.length)
		{
			// reshuffle each pass to keep it fresh
			FlxG.random.shuffle(videos);
			vidIdx = 0;
		}
		playVideo(videos[vidIdx]);
	}

	function playVideo(path:String):Void
	{
		label.text = ""; // clear any messages

		// Stop and remove existing player
		if (player != null)
		{
			try
				player.stop()
			catch (_:Dynamic) {}
			remove(player, true);
			player = null;
		}

		player = new FlxVideo();
		player.load(path, true); // true = loop in codec; we'll still advance manually on complete for robustness
		player.onEndReached = () -> // when the file finishes, move on
		{
			startNextVideo();
		};

		// Fullscreen to the state camera
		player.x = 0;
		player.y = 0;
		player.setGraphicSize(FlxG.width, FlxG.height);
		player.updateHitbox();

		add(player);
		player.play();
	}
	#end

	inline function anyUserActivity():Bool
	{
		// Keyboard
		if (FlxG.keys.anyJustPressed([ANY]))
			return true;

		// Mouse
		if (FlxG.mouse.justPressed || FlxG.mouse.justPressedRight || FlxG.mouse.justPressedMiddle)
			return true;
		if (FlxG.mouse.wheel != 0)
			return true;

		// (If you later want gamepad here, wire it through your custom input system)
		return false;
	}
}
