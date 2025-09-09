package util;

import flixel.FlxG;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;

enum abstract Action(String) from String to String
{
	public var Prev = "prev";
	public var Next = "next";
	public var Select = "select";
	public var Back = "back";
	public var AdminExit = "admin_exit";
}

class InputMap
{
	public static var inst(default, null):InputMap = new InputMap();

	// action (lowercase) -> tokens (UPPERCASE)
	private var bindings:Map<String, Array<String>> = new Map();

	public function new() {}

	/** Merge keyboard + pad maps into a single normalized token list per action. */
	public function configure(keys:Map<String, Array<String>>, pads:Map<String, Array<String>>):Void
	{
		bindings = new Map();

		inline function normTok(t:String):String
			return (t == null) ? "" : t.toUpperCase().trim();
		inline function isPad(t:String):Bool
			return t.indexOf("PAD_") == 0;
		inline function normPad(tok:String):String
		{
			var t = normTok(tok);
			if (t == "PAD_SELECT")
				t = "PAD_BACK"; // alias
			return t;
		}

		var seen = new Map<String, Bool>();

		// First: keyboard
		for (action in keys.keys())
		{
			var a = action.toLowerCase();
			var arr = new Array<String>();
			for (k in keys.get(action))
			{
				var t = normTok(k);
				if (t != "" && !isPad(t))
				{
					var key = a + "|" + t;
					if (!seen.exists(key))
					{
						arr.push(t);
						seen.set(key, true);
					}
				}
			}
			bindings.set(a, arr);
		}

		// Then: pads
		for (action in pads.keys())
		{
			var a = action.toLowerCase();
			var arr = bindings.exists(a) ? bindings.get(a) : new Array<String>();
			for (p in pads.get(action))
			{
				var t = normPad(p);
				if (t != "" && isPad(t))
				{
					var key = a + "|" + t;
					if (!seen.exists(key))
					{
						arr.push(t);
						seen.set(key, true);
					}
				}
			}
			bindings.set(a, arr);
		}
	}

	/* ---------- Back-compat API: Action overloads ---------- */
	public inline function has(action:Action):Bool
		return hasStr(action);

	public inline function isPressed(action:Action):Bool
		return isPressedStr(action);

	public inline function justPressed(action:Action):Bool
		return justPressedStr(action);

	/* ---------- String-based API (also kept) ---------- */
	public inline function hasStr(action:String):Bool
		return bindings != null && bindings.exists(action.toLowerCase());

	public function isPressedStr(action:String):Bool
	{
		var list = bindings.get(action.toLowerCase());
		if (list == null)
			return false;

		for (t in list)
		{
			if (isKeyboardToken(t))
			{
				// SHIFT+F12 combo support
				if (t == "SHIFT+F12")
				{
					if (FlxG.keys.pressed.SHIFT && FlxG.keys.pressed.F12)
						return true;
					continue;
				}
				var k = keyFromToken(t);
				if (k != FlxKey.NONE && FlxG.keys.anyPressed([k]))
					return true;
			}
			else
			{
				var tk = padFromToken(t);
				if (tk != FlxGamepadInputID.NONE && anyPadPressed(tk))
					return true;
			}
		}
		return false;
	}

	public function justPressedStr(action:String):Bool
	{
		var list = bindings.get(action.toLowerCase());
		if (list == null)
			return false;

		for (t in list)
		{
			if (isKeyboardToken(t))
			{
				if (t == "SHIFT+F12")
				{
					if (FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.F12)
						return true;
					if (FlxG.keys.justPressed.SHIFT && FlxG.keys.justPressed.F12)
						return true;
					continue;
				}
				var k = keyFromToken(t);
				if (k != FlxKey.NONE && FlxG.keys.anyJustPressed([k]))
					return true;
			}
			else
			{
				var tk:FlxGamepadInputID = padFromToken(t);
				if (tk != FlxGamepadInputID.NONE && anyPadJustPressed(tk))
					return true;
			}
		}
		return false;
	}

	/* ---------- Internals ---------- */
	function isKeyboardToken(t:String):Bool
		return t.indexOf("PAD_") != 0;

	inline function keyFromToken(t:String):FlxKey
	{
		switch (t)
		{
			case "ENTER":
				return FlxKey.ENTER;
			case "SPACE":
				return FlxKey.SPACE;
			case "COMMA":
				return FlxKey.COMMA;
			case "SLASH":
				return FlxKey.SLASH;
			case "LEFT":
				return FlxKey.LEFT;
			case "RIGHT":
				return FlxKey.RIGHT;
			case "UP":
				return FlxKey.UP;
			case "DOWN":
				return FlxKey.DOWN;
			case "ESCAPE":
				return FlxKey.ESCAPE;
			case "SHIFT":
				return FlxKey.SHIFT;
			case "F12":
				return FlxKey.F12;
			case "A":
				return FlxKey.A;
			case "D":
				return FlxKey.D;
			default:
				return FlxKey.NONE;
		}
	}

	inline function padFromToken(t:String):FlxGamepadInputID
	{
		switch (t)
		{
			case "PAD_A":
				return FlxGamepadInputID.A;
			case "PAD_B":
				return FlxGamepadInputID.B;
			case "PAD_X":
				return FlxGamepadInputID.X;
			case "PAD_Y":
				return FlxGamepadInputID.Y;
			case "PAD_START":
				return FlxGamepadInputID.START;
			case "PAD_BACK":
				return FlxGamepadInputID.BACK;
			case "PAD_LEFT":
				return FlxGamepadInputID.DPAD_LEFT;
			case "PAD_RIGHT":
				return FlxGamepadInputID.DPAD_RIGHT;
			case "PAD_UP":
				return FlxGamepadInputID.DPAD_UP;
			case "PAD_DOWN":
				return FlxGamepadInputID.DPAD_DOWN;
			default:
				return FlxGamepadInputID.NONE;
		}
	}

	function anyPadPressed(id:FlxGamepadInputID):Bool
	{
		if (id == FlxGamepadInputID.NONE)
			return false;
		for (p in FlxG.gamepads.getActiveGamepads())
		{
			if (p != null)
				return p.anyPressed([id]);
		}

		return false;
	}

	function anyPadJustPressed(id:FlxGamepadInputID):Bool
	{
		if (id == FlxGamepadInputID.NONE)
			return false;
		for (p in FlxG.gamepads.getActiveGamepads())
			if (p != null)
				return p.anyJustPressed([id]);
		return false;
	}
}
