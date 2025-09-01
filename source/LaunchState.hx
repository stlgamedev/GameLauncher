package;

import aseprite.Aseprite;
import flixel.FlxG;
import flixel.FlxState;
import flixel.tweens.FlxTween;
import haxe.io.Eof;
import openfl.Assets;
import openfl.display.BitmapData;
import sys.FileSystem;
import sys.io.Process;
import sys.thread.Thread;

class LaunchState extends FlxState
{
	public var game:util.GameEntry;

	var splash:flixel.FlxSprite; // centered box art (fit)
	var logo:Aseprite; // spinner shown in BR corner (same as BootState)

	var proc:Process = null;
	var procExited:Bool = false;
	var procExitCode:Null<Int> = null;

	// idle / hotkey
	var idleTimeout:Float = 300.0; // seconds; will be set from Globals.cfg.idleSecondsGame
	var hotkeyPressed:Bool = false; // SHIFT+F12 debounce

	var startTimeMs:Float = Date.now().getTime();

	// Optional XInput dynamic
	#if cpp
	var XInputGetState:Dynamic = null;
	#end

	public function new(g:util.GameEntry)
	{
		super();
		this.game = g;
	}

	override public function create():Void
	{
		super.create();
		FlxG.cameras.bgColor = 0xFF000000;

		// --- Box art centered (fit ~80% of screen) ---
		splash = new flixel.FlxSprite();
		var boxPath = game.box;
		if (boxPath != null && FileSystem.exists(boxPath))
		{
			try
			{
				var bd = BitmapData.fromFile(boxPath);
				splash.loadGraphic(bd);
			}
			catch (_:Dynamic) {}
		}
		splash.antialiasing = true;
		add(splash);
		resizeSplash();

		// --- Spinner (same asset/placement as BootState) ---
		try
		{
			var bytes = Assets.getBytes("assets/images/spinning_icon.aseprite");
			logo = Aseprite.fromBytes(bytes);
			logo.play();
			logo.mouseEnabled = logo.mouseChildren = false;
			FlxG.stage.addChild(logo);
			fitOpenFL(logo, FlxG.stage.stageWidth, FlxG.stage.stageHeight);
		}
		catch (_:Dynamic)
		{
			logo = null;
		}

		// Idle timeout from config
		if (Globals.cfg != null && Globals.cfg.idleSecondsGame > 0)
			idleTimeout = Globals.cfg.idleSecondsGame;

		// Start process + monitors
		launchGameAsync();
		#if cpp
		initXInputOptional();
		startIdleAndHotkeyMonitors();
		#end
	}

	override public function destroy():Void
	{
		if (logo != null && logo.parent != null)
			logo.parent.removeChild(logo);
		logo = null;

		if (proc != null)
		{
			try
				proc.close()
			catch (_:Dynamic) {}
			proc = null;
		}
		super.destroy();
	}

	private function returnToGameSelect():Void
	{ // duration since we spawned the process
		var secs = Math.max(0, (Date.now().getTime() - startTimeMs) / 1000.0);
		util.Analytics.recordSession(game.id, secs);

		FlxG.switchState(() -> new GameSelectState());
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Return when game exits
		#if sys
		if (procExited)
		{
			returnToGameSelect();
			return;
		}
		#end

		// Safety: allow ESC to return if not kiosk
		if (Globals.cfg.mode != "kiosk" && FlxG.keys.justPressed.ESCAPE)
		{
			returnToGameSelect();
			return;
		}
	}

	/* ---------------------- layout helpers ---------------------- */
	function resizeSplash():Void
	{
		if (splash == null || splash.frameWidth == 0 || splash.frameHeight == 0)
			return;

		var maxW = Std.int(FlxG.width * 0.80);
		var maxH = Std.int(FlxG.height * 0.80);
		var fw = splash.frameWidth;
		var fh = splash.frameHeight;
		var sc = Math.min(maxW / fw, maxH / fh);

		splash.setGraphicSize(Std.int(fw * sc), Std.int(fh * sc));
		splash.updateHitbox();
		splash.x = Std.int((FlxG.width - splash.width) * 0.5);
		splash.y = Std.int((FlxG.height - splash.height) * 0.5);
	}

	inline function fitOpenFL(d:openfl.display.DisplayObject, sw:Int, sh:Int):Void
	{
		// bottom-right 12% (same recipe as BootState)
		var maxW = Std.int(sw * 0.12);
		var maxH = Std.int(sh * 0.12);
		d.scaleX = d.scaleY = 1;
		var ow = d.width, oh = d.height;
		if (ow <= 0 || oh <= 0)
			return;
		var sc = Math.min(maxW / ow, maxH / oh);
		d.scaleX = d.scaleY = sc;
		d.x = sw - Std.int(d.width) - 24;
		d.y = sh - Std.int(d.height) - 24;
	}

	/* ---------------------- process spawn/monitor ---------------------- */
	function launchGameAsync():Void
	{
		#if sys
		var exe:String = game.exe; // you requested this explicit usage
		if (exe == null || exe == "" || !FileSystem.exists(exe))
		{
			Globals.log.line("[LAUNCH][ERROR] Executable missing: " + exe);
			returnToMenuSoon();
			return;
		}

		Thread.create(() ->
		{
			try
			{
				Globals.log.line("[LAUNCH] Starting: " + exe);
				// Use arg array so paths with spaces work without quoting hacks
				proc = new Process(exe, []);

				#if cpp
				// Bind to a Job so child dies if launcher dies
				try
					bindProcessToJob(proc.getPid())
				catch (_:Dynamic) {}
				#end

				// stdout reader
				Thread.create(() ->
				{
					try
					{
						var ln:String;
						while (proc != null)
						{
							try
							{
								ln = proc.stdout.readLine();
								Globals.log.line("[GAME OUT] " + ln);
							}
							catch (e:Eof)
								break;
						}
					}
					catch (_:Dynamic) {}
				});

				// stderr reader
				Thread.create(() ->
				{
					try
					{
						var ln:String;
						while (proc != null)
						{
							try
							{
								ln = proc.stderr.readLine();
								Globals.log.line("[GAME ERR] " + ln);
							}
							catch (e:Eof)
								break;
						}
					}
					catch (_:Dynamic) {}
				});

				// Wait until the game exits
				var code:Null<Int> = null;
				while (proc != null && (code = proc.exitCode(false)) == null)
					Sys.sleep(0.05);

				procExitCode = code;
				Globals.log.line("[LAUNCH] Game exited with code " + Std.string(code));
			}
			catch (e:Dynamic)
			{
				Globals.log.line("[LAUNCH][ERROR] Failed to start or watch game: " + Std.string(e));
			}
			procExited = true; // emulate finally
		});
		#else
		Globals.log.line("[LAUNCH][WARN] sys target required to spawn process.");
		returnToMenuSoon();
		#end
	}

	function returnToMenuSoon():Void
	{
		FlxTween.num(0, 1, 0.25, {onComplete: _ -> FlxG.switchState(() -> new GameSelectState())});
	}

	/* ---------------------- Idle + Hotkey (Windows / C++) ---------------------- */
	#if cpp
	inline function startIdleAndHotkeyMonitors():Void
	{
		Thread.create(() ->
		{
			var running = true;
			var lastInputTick:Int = 0;

			while (running)
			{
				Sys.sleep(0.10);

				// stop if process died
				if (proc == null || procExited)
					break;

				// Global hotkey: SHIFT+F12 (no focus required)
				var down:Int = 0;
				untyped __cpp__('
					{ down = ((GetAsyncKeyState(VK_SHIFT)&0x8000) && (GetAsyncKeyState(VK_F12)&0x8000)) ? 1 : 0; }
				');
				if (down != 0)
				{
					if (!hotkeyPressed)
					{
						hotkeyPressed = true;
						Globals.log.line("[HOTKEY] SHIFT+F12 pressed -> kill game");
						forceKillGame();
					}
				}
				else
				{
					hotkeyPressed = false;
				}

				// Idle: keyboard/mouse inactivity using GetLastInputInfo
				var nowTick:Int = 0;
				var lastTick:Int = 0;
				untyped __cpp__('
					{
						LASTINPUTINFO lii; lii.cbSize = sizeof(LASTINPUTINFO);
						if (GetLastInputInfo(&lii)) { lastTick = (int)lii.dwTime; }
						nowTick = (int)GetTickCount();
					}
				');
				var idleMs = nowTick - lastTick;
				var idleSec = idleMs / 1000.0;

				// Optional gamepad activity keeps it alive
				if (idleSec >= 0.5 && checkXInputChanged())
				{
					// treat as activity -> set idleSec small
					idleSec = 0.0;
				}

				if (idleSec >= idleTimeout)
				{
					Globals.log.line("[IDLE EXIT] No activity for " + idleTimeout + "s -> kill game");
					forceKillGame();
					break;
				}
			}
		});
	}

	inline function forceKillGame():Void
	{
		try
		{
			if (proc != null)
			{
				var pid = proc.getPid();
				// TerminateProcess by PID (in case Process.kill() fails)
				untyped __cpp__('
					{
						HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, (DWORD){0});
						if (h) { TerminateProcess(h, 1); CloseHandle(h); }
					}
				', pid);
				try
					proc.kill()
				catch (_:Dynamic) {}
			}
		}
		catch (_:Dynamic) {}
	}

	// Bind child to a Job so it dies if the launcher dies
	inline function bindProcessToJob(pid:Int):Void
	{
		untyped __cpp__('
			{
				static HANDLE gJob = NULL;
				if (!gJob)
				{
					gJob = CreateJobObject(NULL, NULL);
					if (gJob)
					{
						JOBOBJECT_EXTENDED_LIMIT_INFORMATION jeli;
						ZeroMemory(&jeli, sizeof(jeli));
						jeli.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
						SetInformationJobObject(gJob, JobObjectExtendedLimitInformation, &jeli, sizeof(jeli));
					}
				}
				if (gJob)
				{
					HANDLE hProc = OpenProcess(PROCESS_ALL_ACCESS, FALSE, (DWORD){0});
					if (hProc) { AssignProcessToJobObject(gJob, hProc); CloseHandle(hProc); }
				}
			}
		', pid);
	}

	// -------- Optional XInput polling --------
	var lastPadHash:Int = 0;

	inline function initXInputOptional():Void
	{
		// Try multiple DLL names; ignore failures
		try
			XInputGetState = cpp.Lib.load("xinput1_4", "XInputGetState", 2)
		catch (_:Dynamic) {}
		if (XInputGetState == null)
			try
				XInputGetState = cpp.Lib.load("xinput1_3", "XInputGetState", 2)
			catch (_:Dynamic) {}
	}

	inline function checkXInputChanged():Bool
	{
		if (XInputGetState == null)
			return false;

		var hash:Int = 0;
		for (i in 0...4)
		{
			var ok:Int = 0;
			var buttons:Int = 0;
			var lx:Int = 0, ly:Int = 0, rx:Int = 0, ry:Int = 0, lt:Int = 0, rt:Int = 0;

			untyped __cpp__('
				{
					XINPUT_STATE st; ZeroMemory(&st, sizeof(st));
					ok = (XInputGetState({0}, &st) == ERROR_SUCCESS) ? 1 : 0;
					if (ok)
					{
						buttons = (int)st.Gamepad.wButtons;
						lx = (int)st.Gamepad.sThumbLX; ly = (int)st.Gamepad.sThumbLY;
						rx = (int)st.Gamepad.sThumbRX; ry = (int)st.Gamepad.sThumbRY;
						lt = (int)st.Gamepad.bLeftTrigger; rt = (int)st.Gamepad.bRightTrigger;
					}
				}
			', i);

			if (ok != 0)
				hash ^= (buttons ^ lx ^ ly ^ rx ^ ry ^ lt ^ rt);
		}

		if (hash != 0 && hash != lastPadHash)
		{
			lastPadHash = hash;
			return true;
		}
		return false;
	}
	#end
}
