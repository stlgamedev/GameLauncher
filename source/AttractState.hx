package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.io.Path;
import sys.FileSystem;
import hxcodec.flixel.FlxVideoSprite;

class AttractState extends FlxState
{
	var videos:Array<String> = [];
	var vidIdx:Int = -1;
	var label:FlxText;
	var demoText:FlxText;
	var pressAnyText:FlxText;
	var demoTimer:Float = 0;
	var pressAnyTimer:Float = 0;

	var videoSprite:FlxVideoSprite;

	override public function create():Void
	{
		super.create();
		bgColor = 0xFF000000;

		label = new FlxText(0, 0, FlxG.width, "");
		label.setFormat(null, 24, FlxColor.WHITE, "center");
		label.y = FlxG.height - 40;

		buildVideoList();

		if (videos.length == 0)
		{
			label.text = "No trailers found in: " + util.Paths.trailersDir();
			add(label);
			// After a brief pause, go back
			new FlxTimer().start(1.0, _ -> FlxG.switchState(() -> new GameSelectState()));
			return;
		}

		startNextVideo();

		// Add overlays after video for correct layering
		add(label);
		demoText = new FlxText(0, 0, FlxG.width, "DEMO");
		demoText.setFormat(null, 72, FlxColor.YELLOW, "center");
		demoText.y = 120;
		demoText.alpha = 1;
		add(demoText);

		pressAnyText = new FlxText(0, 0, FlxG.width, "Press Any Key");
		pressAnyText.setFormat(null, 40, FlxColor.WHITE, "center");
		pressAnyText.y = FlxG.height - 120;
		pressAnyText.alpha = 1;
		add(pressAnyText);
	}

	override public function destroy():Void
	{
		if (videoSprite != null)
		{
			videoSprite.destroy();
			remove(videoSprite);
			videoSprite = null;
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
			if (videoSprite != null)
				try
					videoSprite.stop()
				catch (_:Dynamic) {}
			videoSprite = null;
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
			FlxG.random.shuffle(videos);
			vidIdx = 0;
		}
		playVideo(videos[vidIdx]);
	}

	function playVideo(path:String):Void
	{
		label.text = ""; // clear any messages

		if (videoSprite != null)
		{
			videoSprite.destroy();
			remove(videoSprite);
			videoSprite = null;
		}

		videoSprite = new FlxVideoSprite();
		videoSprite.bitmap.onEndReached.add(() -> startNextVideo());
		videoSprite.bitmap.onTextureSetup.add(() -> {
			var videoW = videoSprite.bitmap.bitmapData.width;
			var videoH = videoSprite.bitmap.bitmapData.height;
			var screenW = FlxG.width;
			var screenH = FlxG.height;
			var scale = Math.min(screenW / videoW, screenH / videoH);
			videoSprite.setGraphicSize(Std.int(videoW * scale), Std.int(videoH * scale));
			videoSprite.x = Std.int((screenW - videoSprite.width) / 2);
			videoSprite.y = Std.int((screenH - videoSprite.height) / 2);
		});
		videoSprite.play(path, false);
		videoSprite.bitmap.volume = Std.int(FlxG.sound.volume * 100);
		add(videoSprite); // Add before overlays for correct layering
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
