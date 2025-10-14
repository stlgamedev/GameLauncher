package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.io.Path;
import sys.FileSystem;

import hxcodec.flixel.FlxVideo;


class AttractState extends FlxState
{
	var videos:Array<String> = [];
	var vidIdx:Int = -1;
	var label:FlxText;
	var demoText:FlxText;
	var pressAnyText:FlxText;
	var demoTimer:Float = 0;
	var pressAnyTimer:Float = 0;
	
	var player:FlxVideo;


	override public function create():Void
	{
		super.create();
		bgColor = 0xFF000000;

		label = new FlxText(0, 0, FlxG.width, "");
		label.setFormat(null, 24, FlxColor.WHITE, "center");
		label.y = FlxG.height - 40;
		add(label);

		// DEMO overlay
		demoText = new FlxText(0, 0, FlxG.width, "DEMO");
		demoText.setFormat(null, 72, FlxColor.YELLOW, "center");
		demoText.y = 120;
		demoText.alpha = 1;
		add(demoText);

		// Press Any Key overlay
		pressAnyText = new FlxText(0, 0, FlxG.width, "Press Any Key");
		pressAnyText.setFormat(null, 40, FlxColor.WHITE, "center");
		pressAnyText.y = FlxG.height - 120;
		pressAnyText.alpha = 1;
		add(pressAnyText);

		buildVideoList();

		if (videos.length == 0)
		{
			label.text = "No trailers found in: " + util.Paths.trailersDir();
			// After a brief pause, go back
			new FlxTimer().start(1.0, _ -> FlxG.switchState(() -> new GameSelectState()));
			return;
		}
		


	}

	override public function destroy():Void
	{
		
		if (player != null)
		{
			try
				player.stop()
			catch (_:Dynamic) {}
			
			player.dispose();
			player = null;
		}
		
		super.destroy();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Animate DEMO and Press Any Key overlays
		demoTimer += elapsed;
		pressAnyTimer += elapsed;
		// DEMO: fade in/out every 1.2 seconds
		demoText.alpha = 0.5 + 0.5 * Math.sin(demoTimer * Math.PI / 1.2);
		// Press Any Key: fade in/out every 0.8 seconds
		pressAnyText.alpha = 0.5 + 0.5 * Math.sin(pressAnyTimer * Math.PI / 0.8);

		if (anyUserActivity())
		{
			
			if (player != null)
				try
					player.stop()
				catch (_:Dynamic) {}
			
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
			player.dispose();
			player = null;
		}

		player = new FlxVideo();
		player.onEndReached.add(() -> startNextVideo());
		player.play(path, false); // true = loop in codec; we'll still advance manually on complete for robustness
		
	}
	

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
