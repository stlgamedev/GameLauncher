package themes;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import themes.Theme.IThemeNode;

class VortexNode implements IThemeNode
{
	public var name(get, never):String;

	var _name:String;
	var spr:FlxSprite;
	var shader:BgVortexShader;

	// Tunables (defaults, overridden by JSON)
	var baseSpeed:Float = 1.0;
	var boost:Float = 0.0;
	var boostDecay:Float = 1.6;
	var scaleUniform:Float = 2.2;
	var iterations:Float = 4.0; // 1..8
	var mixDark:Float = 0.35; // 0..1 (higher => darker/more muted)
	var opacity:Float = 1.0; // 0..1
	var downscale:Int = 3; // 2–4 good perf

	// NEW tunables
	var hueSpeed:Float = 0.035; // was hardcoded; now param
	var nudgeAmount:Float = 0.25; // default kick
	var nudgeHalfLife:Float = 0.25; // seconds to halve boost
	var boostMax:Float = 0.5; // clamp ceiling

	// internal
	var lastW:Int = 0;
	var lastH:Int = 0;
	var shaderReady:Bool = false;

	public function new(el:ThemeElementSpec, _theme:Theme)
	{
		_name = el.name;

		// --- Safe param parsing (works for number or string) ---
		inline function getFloat(key:String, def:Float):Float
		{
			if (el.params == null)
				return def;
			var v:Dynamic = Reflect.field(el.params, key);
			if (v == null)
				return def;
			switch (Type.typeof(v))
			{
				case TFloat:
					return v;
				case TInt:
					return v;
				case TClass(String):
					var f = Std.parseFloat(Std.string(v));
					return Math.isNaN(f) ? def : f;
				default:
					return def;
			}
		}
		inline function getInt(key:String, def:Int):Int
		{
			if (el.params == null)
				return def;
			var v:Dynamic = Reflect.field(el.params, key);
			if (v == null)
				return def;
			switch (Type.typeof(v))
			{
				case TInt:
					return v;
				case TFloat:
					return Std.int(v);
				case TClass(String):
					var i = Std.parseInt(Std.string(v));
					return (i == null) ? def : i;
				default:
					return def;
			}
		}

		baseSpeed = getFloat("baseSpeed", baseSpeed);
		boostDecay = getFloat("boostDecay", boostDecay);
		scaleUniform = getFloat("scale", scaleUniform);
		iterations = getFloat("iterations", iterations);
		mixDark = getFloat("mix", mixDark);
		opacity = getFloat("opacity", opacity);
		downscale = getInt("downscale", downscale);
		hueSpeed = getFloat("hueSpeed", hueSpeed);
		nudgeAmount = getFloat("nudgeAmount", nudgeAmount);
		nudgeHalfLife = getFloat("nudgeHalfLife", nudgeHalfLife);
		boostMax = getFloat("boostMax", boostMax);

		shader = new BgVortexShader();
		spr = new FlxSprite();
		spr.scrollFactor.set(0, 0);
		spr.antialiasing = true;
		spr.shader = shader;
		spr.visible = true;
	}

	public inline function get_name():String
		return _name;

	public inline function basic():FlxBasic
		return spr;

	public function addTo(state:FlxState):Void
		state.add(spr);

	public function update(ctx:Context):Void
	{
		// ensure a (small) texture exists and scale sprite to screen
		var w = ctx.w, h = ctx.h;
		if (w != lastW || h != lastH || spr.pixels == null)
		{
			var rw = Std.int(Math.max(1, Std.int(w / Math.max(1, downscale))));
			var rh = Std.int(Math.max(1, Std.int(h / Math.max(1, downscale))));
			spr.makeGraphic(rw, rh, 0xFFFFFFFF, true);
			spr.setGraphicSize(w, h);
			spr.updateHitbox();
			spr.x = 0;
			spr.y = 0;
			lastW = w;
			lastH = h;
		}

		// drive uniforms EVERY FRAME
		var t = FlxG.game.ticks / 1000.0;
		if (boost > 0)
			boost = Math.max(0, boost - boostDecay * FlxG.elapsed);

		shader.time = t;
		shader.data.u_speed.value = [baseSpeed + boost];
		shader.data.u_scale.value = [scaleUniform];
		shader.data.u_iter.value = [iterations];
		shader.data.u_mix.value = [mixDark];
		shader.data.u_hueshift.value = [(t * 0.035) - Math.floor(t * 0.035)];

		// opacity takes effect here
		spr.alpha = opacity;
	}

	/** Call when user moves carousel to add a momentary kick. */
	public function nudge(amount:Float = -1):Void
	{
		var a = (amount >= 0) ? amount : nudgeAmount;
		boost = Math.min(boost + a, boostMax);
	}
}
