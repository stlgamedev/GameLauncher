package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.io.Eof;
import openfl.display.BitmapData;
import sys.io.Process;
import sys.thread.Thread;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class LaunchState extends FlxState
{
	// Input
	static inline var HOTKEY_KEY = 0x7B; // F12 (FlxG.keys justPressed.F12 also used)

	// Visuals
	var splash:FlxSprite; // scaled g.box
	var spinner:FlxSprite; // simple rotating indicator
	var msg:FlxText; // small status text (errors/fallback)

	// Process
	var proc:Process = null;
	var procExited:Bool = false;
	var procExitCode:Null<Int> = null;

	// Idle watchdog
	var idleLimit:Float = 300.0; // default, overwritten from Globals.cfg.idleSecondsGame
	var idleTimer:Float = 0.0;

	// Minor feedback SFX (optional from carousel theme if present)
	var sfxStart:FlxSound = null;

	// Game
	var game:util.GameEntry;

	public function new(g:util.GameEntry)
	{
		super();
		this.game = g;
	}

	override public function create():Void
	{
		super.create();

		FlxG.cameras.bgColor = 0xFF000000;

		// Idle limit from config (safe)
		if (Globals.cfg != null && Globals.cfg.idleSecondsGame > 0)
			idleLimit = Globals.cfg.idleSecondsGame;

		// Background splash from g.box (center/fit)
		splash = new FlxSprite();
		splash.antialiasing = true;
		add(splash);

		#if sys
		var boxAbs = game.box;
		if (boxAbs != null && boxAbs != "" && sys.FileSystem.exists(boxAbs))
		{
			try
			{
				var bd = BitmapData.fromFile(boxAbs);
				if (bd != null)
				{
					splash.loadGraphic(bd);
					fitContain(splash, 0, 0, FlxG.width, FlxG.height);
				}
			}
			catch (_:Dynamic) {}
		}
		#end

		// If splash never loaded, make a dim placeholder
		if (splash.pixels == null)
		{
			splash.makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(16, 16, 16));
		}

		// Spinner (small square that rotates; no external dependency)
		spinner = new FlxSprite();
		spinner.makeGraphic(24, 24, FlxColor.WHITE);
		spinner.antialiasing = true;
		spinner.alpha = 0.85;
		spinner.x = FlxG.width - spinner.width - 24;
		spinner.y = FlxG.height - spinner.height - 24;
		add(spinner);

		// Status text (optional)
		msg = new FlxText(0, 0, FlxG.width, "Launching \"" + game.title + "\"…");
		msg.setFormat(null, 16, FlxColor.GRAY, "center");
		msg.y = FlxG.height - 48;
		add(msg);

		// Optional: get launch sound already loaded by CarouselNode (if exists)
		// We won't re-load from disk; we just ask the theme node for its FlxSound.
		var car:themes.CarouselNode = cast Globals.theme.getNodeByName("carousel");
		if (car != null && Reflect.hasField(car, "sfxStart"))
		{
			try
			{
				sfxStart = cast Reflect.field(car, "sfxStart");
			}
			catch (_:Dynamic) {}
		}
		if (sfxStart != null)
		{
			// brief cue; we don't block onComplete here (we go launch in parallel)
			sfxStart.stop();
			sfxStart.play();
		}

		// Start rotating spinner forever (tween resets self)
		spinLoop();

		// Launch game on a background thread, watch process
		launchGameAsync();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Keep spinner visible
		// (rotation handled via tween)

		// Focused hotkey to abort: SHIFT + F12
		if (FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.F12)
		{
			Globals.log.line('[LAUNCH] SHIFT+F12 pressed: killing game and returning.');
			killGameAndReturn();
			return;
		}

		// Idle watchdog: reset if any recent input
		if (anyActivity())
		{
			idleTimer = 0;
		}
		else
		{
			idleTimer += elapsed;
			if (idleTimer >= idleLimit)
			{
				Globals.log.line('[LAUNCH] Idle limit reached (' + idleLimit + 's). Killing game.');
				killGameAndReturn();
				return;
			}
		}

		// If process finished, go back
		if (procExited)
		{
			// Small delay so last frame draws
			FlxG.switchState(() -> new GameSelectState());
			return;
		}
	}

	override public function destroy():Void
	{
		// Ensure we don't leak the child process if the state is torn down
		try
		{
			if (proc != null && proc.exitCode(false) == null)
			{
				proc.kill();
			}
		}
		catch (_:Dynamic) {}
		proc = null;

		super.destroy();
	}

	/* ================= helpers ================= */
	function spinLoop():Void
	{
		spinner.angle = 0;
		FlxTween.tween(spinner, {angle: 360}, 1.0, {
			ease: FlxEase.linear,
			onComplete: _ -> spinLoop()
		});
	}

	// Contain-fit a FlxSprite inside box while centering (origin 0,0)
	static inline function fitContain(s:FlxSprite, x:Int, y:Int, bw:Int, bh:Int):Void
	{
		var fw = s.frameWidth;
		var fh = s.frameHeight;
		if (fw <= 0 || fh <= 0)
			return;
		s.origin.set(0, 0);
		s.offset.set(0, 0);
		s.scale.set(1, 1);
		s.updateHitbox();
		var sc = Math.min(bw / fw, bh / fh);
		s.setGraphicSize(Std.int(fw * sc), Std.int(fh * sc));
		s.updateHitbox();
		s.setPosition(x + Std.int((bw - s.width) * 0.5), y + Std.int((bh - s.height) * 0.5));
	}

	function anyActivity():Bool
	{
		// Keys
		if (FlxG.keys.anyJustPressed([ANY]) || FlxG.keys.anyJustReleased([ANY]))
			return true;
		// Mouse
		if (FlxG.mouse.justMoved || FlxG.mouse.justPressed || FlxG.mouse.justReleased)
			return true;
		// Gamepads (if present)
		#if flixel
		if (FlxG.gamepads != null && FlxG.gamepads.anyButton())
			return true;
		#end
		return false;
	}

	function launchGameAsync():Void
	{
		#if sys
		var exe:String = game.exe; // your helper that returns "<gamesDir>/<id>/<exeName>.exe"
		if (exe == "")
		{
			msg.text = "No executable path.";
			Globals.log.line("[LAUNCH][ERROR] Empty executable path for " + game.id);
			returnToMenuSoon();
			return;
		}

		sys.thread.Thread.create(() ->
		{
			try
			{
				Globals.log.line("[LAUNCH] Starting: " + exe);
				proc = new sys.io.Process(exe);

				// stdout reader
				sys.thread.Thread.create(() ->
				{
					try
					{
						while (proc != null)
						{
							try
							{
								var ln = proc.stdout.readLine();
								Globals.log.line("[GAME OUT] " + ln);
							}
							catch (e:haxe.io.Eof)
							{
								break;
							}
						}
					}
					catch (_:Dynamic) {}
				});

				// stderr reader
				sys.thread.Thread.create(() ->
				{
					try
					{
						while (proc != null)
						{
							try
							{
								var ln = proc.stderr.readLine();
								Globals.log.line("[GAME ERR] " + ln);
							}
							catch (e:haxe.io.Eof)
							{
								break;
							}
						}
					}
					catch (_:Dynamic) {}
				});

				// wait until the game exits
				var code:Null<Int> = null;
				while (proc != null && (code = proc.exitCode(false)) == null)
				{
					Sys.sleep(0.05);
				}
				procExitCode = code;
				Globals.log.line("[LAUNCH] Game exited with code " + Std.string(code));
			}
			catch (e:Dynamic)
			{
				Globals.log.line("[LAUNCH][ERROR] Failed to start or watch game: " + Std.string(e));
			}

			// set exited flag no matter what (acts like 'finally')
			procExited = true;
		});
		#else
		msg.text = "Launching not supported on this target.";
		Globals.log.line("[LAUNCH][WARN] sys target required to spawn process.");
		returnToMenuSoon();
		#end
	}

	function killGameAndReturn():Void
	{
		#if sys
		try
		{
			if (proc != null && proc.exitCode(false) == null)
				proc.kill();
		}
		catch (_:Dynamic) {}
		#end
		returnToMenuSoon();
	}

	function returnToMenuSoon():Void
	{
		// brief delay lets UI update and spinner tick once
		FlxTween.num(0, 1, 0.10, {onComplete: _ -> FlxG.switchState(() -> new GameSelectState())});
	}
}
