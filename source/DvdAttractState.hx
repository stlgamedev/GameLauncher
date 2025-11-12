package;

import flixel.util.FlxAxes;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.util.FlxDestroyUtil;
import openfl.display.BitmapData;
import sys.FileSystem;
import aseprite.Aseprite;
import openfl.Assets;

class DvdAttractState extends FlxState
{

	var possibleAngles:Array<Float> = [-25, -20, -15, -10, 0, 10, 15, 20, 25];
	var lastAngle:Int = -1;

	var logo:Aseprite;
	var logoVelX:Float = 200;
	var logoVelY:Float = 150;

	var starfield:FlxTypedGroup<Star>;

	var screenshotPool:FlxTypedGroup<FloatingScreenshot>;
	
	var lastSpawnTime:Float = 5;
	var spawnInterval:Float = 5;

	var pressAnyText:flixel.text.FlxText;
	var ready:Bool = false;

	override public function create():Void
	{
		super.create();
		bgColor = FlxColor.BLACK;

		createStarfield();
		createScreenshotPool();
		createLogo();
		createPressText();

		Globals.log.line("[DVD] DVD bounce attract mode started");
		ready = true;
	}

	private function createStarfield():Void
	{
		starfield = new FlxTypedGroup<Star>();
		add(starfield);

		var numStars = 200;
		var centerX = FlxG.width * 0.5;
		var centerY = FlxG.height * 0.5;

		for (i in 0...numStars)
		{
			var star = new Star();
			star.reset(centerX, centerY);
			starfield.add(star);
		}
	}

	private function createScreenshotPool():Void
	{
		screenshotPool = new FlxTypedGroup<FloatingScreenshot>();
		add(screenshotPool);

		if (Globals.games != null)
		{
			for (game in Globals.games)
			{
				if (game.box != null && FileSystem.exists(game.box))
				{
					var screenshot = new FloatingScreenshot();
					screenshot.loadBox(game.box);
					screenshot.kill();
					screenshotPool.add(screenshot);
				}
			}
		}

		Globals.log.line("[DVD] Created screenshot pool with " + screenshotPool.length + " screenshots");

		resizeScreenshotsToSmallest();
	}

	private function resizeScreenshotsToSmallest():Void
	{
		if (screenshotPool.length == 0)
			return;

		var minWidth:Float = Math.POSITIVE_INFINITY;
		var minHeight:Float = Math.POSITIVE_INFINITY;

		for (ss in screenshotPool.members)
		{
			if (ss != null && ss.width > 0 && ss.height > 0)
			{
				if (ss.width < minWidth)
					minWidth = ss.width;
				if (ss.height < minHeight)
					minHeight = ss.height;
			}
		}

		if (minWidth == Math.POSITIVE_INFINITY || minHeight == Math.POSITIVE_INFINITY)
			return;

		Globals.log.line("[DVD] Smallest screenshot dimensions: " + minWidth + "x" + minHeight);

		for (ss in screenshotPool.members)
		{
			if (ss != null && ss.width > 0 && ss.height > 0)
			{
				var scaleX = minWidth / ss.width;
				var scaleY = minHeight / ss.height;
				var scale = Math.min(scaleX, scaleY);

				ss.setGraphicSize(Std.int(ss.width * scale), Std.int(ss.height * scale));
				ss.updateHitbox();
			}
		}

		Globals.log.line("[DVD] Resized all screenshots to uniform size");
	}

	private function createLogo():Void
	{
		logo = Aseprite.fromBytes(Assets.getBytes("assets/images/spinning_icon.aseprite"));
		logo.play();
		logo.mouseEnabled = logo.mouseChildren = false;
		FlxG.stage.addChild(logo);

		var targetSize = 120;
		var scale = targetSize / Math.max(logo.width, logo.height);
		logo.scaleX = logo.scaleY = scale;
		logo.x = FlxG.stage.stageWidth * 0.5 - logo.width * 0.5;
		logo.y = FlxG.stage.stageHeight * 0.5 - logo.height * 0.5;
	}

	private function createPressText():Void
	{
		pressAnyText = new flixel.text.FlxText(0, FlxG.height - 80, 0, "- PRESS START -");
		pressAnyText.setFormat(null, 32, FlxColor.WHITE, CENTER);
		pressAnyText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2);
		pressAnyText.alpha = 0;
		pressAnyText.screenCenter(FlxAxes.X);
		add(pressAnyText);

		FlxTween.tween(pressAnyText, {alpha: 1}, 0.2, {
			type: PINGPONG,
			startDelay: 0.5,
			loopDelay: 0.3
		});
	}

	override public function destroy():Void
	{
		if (logo != null && logo.parent != null)
			logo.parent.removeChild(logo);
		logo = null;

		starfield = FlxDestroyUtil.destroy(starfield);
		pressAnyText = FlxDestroyUtil.destroy(pressAnyText);
		screenshotPool = FlxDestroyUtil.destroy(screenshotPool);

		super.destroy();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		updateStarfield();
		updateLogo(elapsed);
		spawnScreenshots(elapsed);

		if (FlxG.keys.anyJustPressed([ANY]))
		{
			if (!ready)
				return;
			ready = false;
			Globals.log.line("[DVD] User input - returning to menu");
			FlxG.switchState(() -> new GameSelectState());
		}
	}

	private function updateStarfield():Void
	{
		var centerX = FlxG.width * 0.5;
		var centerY = FlxG.height * 0.5;

		for (star in starfield.members)
		{
			if (star != null)
			{
				star.depth += FlxG.elapsed * 80;

				var scale = star.depth / 100;
				star.x = centerX + star.dirX * star.depth;
				star.y = centerY + star.dirY * star.depth;

				var size:Int = Std.int(Math.min(2, Math.max(1, scale * 2)));
				if (size != star.frameWidth)
					star.makeGraphic(size, size, FlxColor.WHITE);

				star.alpha = Math.min(1.0, star.depth / 30);

				if (star.x < -10 || star.x > FlxG.width + 10 || star.y < -10 || star.y > FlxG.height + 10)
				{
					star.reset(centerX, centerY);
				}
			}
		}
	}

	private function updateLogo(elapsed:Float):Void
	{
		logo.x += logoVelX * elapsed;
		logo.y += logoVelY * elapsed;

		if (logo.x <= 0 || logo.x + logo.width >= FlxG.stage.stageWidth)
			logoVelX *= -1;
		if (logo.y <= 0 || logo.y + logo.height >= FlxG.stage.stageHeight)
			logoVelY *= -1;

		logo.x = Math.max(0, Math.min(logo.x, FlxG.stage.stageWidth - logo.width));
		logo.y = Math.max(0, Math.min(logo.y, FlxG.stage.stageHeight - logo.height));
	}

	private function spawnScreenshots(elapsed:Float):Void
	{
		lastSpawnTime -= elapsed;
		if (lastSpawnTime > 0)
			return;
		var availables = screenshotPool.members.filter(s -> !s.exists);
		if (availables.length == 0)
			return;
		FlxG.random.shuffle(availables);
		var ss:FloatingScreenshot = availables.length > 0 ? availables[0] : null;
		if (ss == null)
			return;
		screenshotPool.remove(ss, true);
		screenshotPool.add(ss);
		lastSpawnTime = spawnInterval;
		FlxTween.tween(ss, {alpha: 1}, 1, {
			onStart: (_) ->
			{
				ss.revive();
				
				var pos = findGoodSpawnPosition(ss);
				ss.x = pos.x;
				ss.y = pos.y;
				
				ss.alpha = 0;
				lastAngle = FlxG.random.int(0, possibleAngles.length - 1, [lastAngle]);
				ss.angle = possibleAngles[lastAngle] + FlxG.random.float(-5, 5);
			},
			onComplete: (_) ->
			{
				FlxTween.tween(ss, {alpha: 0}, 1, {
					startDelay: 30,
					onComplete: (_) ->
					{
						ss.kill();
					}
				});
			}
		});
	}

	private function findGoodSpawnPosition(newSprite:FlxSprite):{x:Float, y:Float}
	{
		var minDistance:Float = 150;
		var maxAttempts:Int = 10;
		var bestX:Float = 0;
		var bestY:Float = 0;
		var bestMinDist:Float = 0;

		for (attempt in 0...maxAttempts)
		{
			var testX = FlxG.random.int(20, Std.int(FlxG.width - 20 - newSprite.width));
			var testY = FlxG.random.int(20, Std.int(FlxG.height - 20 - newSprite.height));

			var closestDist:Float = Math.POSITIVE_INFINITY;

			for (ss in screenshotPool.members)
			{
				if (ss != null && ss.exists && ss != newSprite)
				{
					var dx = (testX + newSprite.width * 0.5) - (ss.x + ss.width * 0.5);
					var dy = (testY + newSprite.height * 0.5) - (ss.y + ss.height * 0.5);
					var dist = Math.sqrt(dx * dx + dy * dy);

					if (dist < closestDist)
						closestDist = dist;
				}
			}

			if (closestDist >= minDistance)
			{
				return {x: testX, y: testY};
			}

			if (closestDist > bestMinDist)
			{
				bestMinDist = closestDist;
				bestX = testX;
				bestY = testY;
			}
		}

		return {x: bestX, y: bestY};
	}
}

class Star extends FlxSprite
{
	public var depth:Float = 0;
	public var dirX:Float = 0;
	public var dirY:Float = 0;

	public function new()
	{
		super();
	}

	override public function reset(x:Float, y:Float):Void
	{
		super.reset(x, y);

		depth = FlxG.random.float(1, 10);
		var angle = FlxG.random.float(0, Math.PI * 2);
		dirX = Math.cos(angle);
		dirY = Math.sin(angle);

		makeGraphic(1, 1, FlxColor.WHITE);
		alpha = 0;
	}
}

class FloatingScreenshot extends FlxSprite
{

	public function new()
	{
		super();
		antialiasing = true;
	}

	public function loadBox(path:String):Void
	{
		var graphic:FlxGraphic = FlxG.bitmap.get(path);
		if (graphic == null)
		{
			try
			{
				var bmd = BitmapData.fromFile(path);
				graphic = FlxG.bitmap.add(bmd, false, path);
				if (graphic != null)
				{
					graphic.persist = true;
					graphic.destroyOnNoUse = false;
				}
			}
			catch (e:Dynamic)
			{
				Globals.log.line("[DVD] Failed to load: " + path);
				return;
			}
		}

		if (graphic != null)
			loadGraphic(graphic);
	}
}
