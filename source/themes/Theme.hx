package themes;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/** ===== Spec ===== */
typedef ThemeSpec =
{
	var id:String;
	var name:String;
	var elements:Array<ThemeElementSpec>;
}

typedef ThemeElementSpec =
{
	var name:String;
	var type:String; // "text"|"graphic"|"rect"|"carousel"|"vortex"
	@:optional var source:String;
	@:optional var content:String;
	@:optional var pos:String;
	@:optional var size:String;
	@:optional var align:String;
	@:optional var color:String;
	@:optional var pointSize:Int;
	@:optional var params:Dynamic;
	@:optional var initialVisible:Null<Bool>;
}

/** ===== Runtime update context ===== */
typedef Context =
{
	var w:Int;
	var h:Int;
	var themeDir:String;
	var resolveVar:(name:String, offset:Int) -> String;
}

/** ===== Node interface ===== */
interface IThemeNode
{
	public var name(get, never):String;
	public function basic():FlxBasic;
	public function addTo(state:FlxState):Void;
	public function update(ctx:Context):Void;
}

/** ===== Theme ===== */
class Theme
{
	public var dir:String;
	public var spec:ThemeSpec;
	public var nodes:Array<IThemeNode> = [];

	public function new(dir:String, spec:ThemeSpec)
	{
		this.dir = dir;
		this.spec = spec;
	}

	public static function load(themeDir:String):Theme
	{
		var jsonPath = Path.join([themeDir, "theme.json"]);
		var txt = File.getContent(jsonPath);
		var spec:ThemeSpec = Json.parse(txt);
		return new Theme(themeDir, spec);
	}

	public function preloadAssets():Void
	{
		// graphics only; everything else is dynamic
		for (el in spec.elements)
		{
			if (el.type == "graphic" && el.source != null && el.source != "" && el.source.charAt(0) != "%")
			{
				var abs = resolve(el.source);
				if (!FileSystem.exists(abs))
					util.Logger.Log.line("[THEME] Missing asset (preload): " + abs);
				else
					addToFlixelCache(abs);
			}
		}
	}

	public function buildInto(state:FlxState):Void
	{
		nodes = [];
		for (el in spec.elements)
		{
			var node:IThemeNode = switch (el.type)
			{
				case "text": new TextNode(el, this);
				case "graphic": new GraphicNode(el, this);
				case "rect": new RectNode(el);
				case "carousel": new CarouselNode(el, this);
				case "vortex": new VortexNode(el, this);
				default: null;
			};
			if (node != null)
			{
				node.addTo(state);
				nodes.push(node);
			}
		}
	}

	public inline function updateAll(ctx:Context):Void
	{
		for (n in nodes)
			n.update(ctx);
	}

	/** Allow states to grab a node by name (e.g., vortex to nudge) */
	public function getNodeByName<T:IThemeNode>(name:String):Null<T>
	{
		for (n in nodes)
			if (n.name == name)
				return cast n;
		return null;
	}

	/** Resolve a theme-relative path. */
	public inline function resolve(relOrAbs:String):String
	{
		if (relOrAbs == null || relOrAbs == "")
			return relOrAbs;
		if (isAbsolute(relOrAbs))
			return relOrAbs;
		return Path.join([dir, relOrAbs]);
	}

	static inline function isAbsolute(p:String):Bool
	{
		if (p == null || p == "")
			return false;
		var c0 = p.charAt(0);
		if (c0 == "/" || c0 == "\\")
			return true;
		if (p.length >= 2 && p.charAt(1) == ":")
			return true;
		return false;
	}

	// ---------- param helpers (robust for String/Float/Int JSON) ----------
	public static function pFloat(obj:Dynamic, key:String, def:Float):Float
	{
		if (obj == null || !Reflect.hasField(obj, key))
			return def;
		var v:Dynamic = Reflect.field(obj, key);
		if (Std.isOfType(v, Float))
			return (v : Float);
		if (Std.isOfType(v, Int))
			return (v : Int);
		if (Std.isOfType(v, String))
		{
			var f = Std.parseFloat((v : String));
			return Math.isNaN(f) ? def : f;
		}
		return def;
	}

	public static function pInt(obj:Dynamic, key:String, def:Int, min:Int = -0x3fffffff, max:Int = 0x3fffffff):Int
	{
		if (obj == null || !Reflect.hasField(obj, key))
			return def;
		var v:Dynamic = Reflect.field(obj, key);
		var out:Int = def;
		if (Std.isOfType(v, Int))
			out = v;
		else if (Std.isOfType(v, Float))
			out = Std.int(v);
		else if (Std.isOfType(v, String))
		{
			var p = Std.parseInt((v : String));
			out = (p == null) ? def : p;
		}
		if (out < min)
			out = min;
		if (out > max)
			out = max;
		return out;
	}

	// ---------- math/placement helpers ----------
	public static inline function evalExpr(expr:String, w:Int, h:Int):Int
	{
		if (expr == null)
			return 0;
		var e = StringTools.trim(expr);
		e = e.split("w").join(Std.string(w)).split("h").join(Std.string(h));
		var total = 0.0;
		var sign = 1.0;
		var i = 0;
		while (i < e.length)
		{
			var ch = e.charAt(i);
			if (ch == "+")
			{
				sign = 1;
				i++;
				continue;
			}
			if (ch == "-")
			{
				sign = -1;
				i++;
				continue;
			}
			var j = i;
			while (j < e.length && e.charAt(j) != "+" && e.charAt(j) != "-")
				j++;
			var term = StringTools.trim(e.substr(i, j - i));
			var mul = 1.0;
			for (part in term.split("*"))
			{
				var sub = part.split("/");
				var v = Std.parseFloat(StringTools.trim(sub[0]));
				if (Math.isNaN(v))
					v = 0;
				for (k in 1...sub.length)
				{
					var d = Std.parseFloat(StringTools.trim(sub[k]));
					if (d == 0)
						d = 1;
					v /= d;
				}
				mul *= v;
			}
			total += sign * mul;
			i = j;
		}
		return Std.int(total);
	}

	// Inside class Theme
	public static inline function expandWithOffsets(s:String, ctx:Context):String
	{
		if (s == null)
			return null;

		var out = new StringBuf();
		var i = 0;

		while (i < s.length)
		{
			var ch = s.charAt(i);

			// Look for %TOKEN%
			if (ch == "%" && i + 1 < s.length)
			{
				var j = i + 1;
				while (j < s.length && s.charAt(j) != "%")
					j++;

				// Found a closing % -> parse token
				if (j < s.length && s.charAt(j) == "%")
				{
					var token = s.substr(i + 1, j - i - 1); // e.g. TITLE, BOX-1, YEAR+2
					var name = token;
					var off = 0;

					// Optional +N / -N offset at the end of the token
					var plus = token.lastIndexOf("+");
					var minus = token.lastIndexOf("-");
					var idx = (plus > 0) ? plus : (minus > 0 ? minus : -1);
					if (idx > 0)
					{
						name = token.substr(0, idx);
						var ofsStr = token.substr(idx); // includes sign
						var n = Std.parseInt(ofsStr);
						if (n != null)
							off = n;
					}

					var val = ctx.resolveVar(name, off);
					out.add(val != null ? val : "");
					i = j + 1;
					continue;
				}
			}
			// Not a token; copy char
			out.add(ch);
			i++;
		}
		return out.toString();
	}

	public static inline function parseXY(s:String, w:Int, h:Int):{x:Int, y:Int}
	{
		if (s == null)
			return {x: 0, y: 0};
		var parts = s.split(",");
		return {x: evalExpr(parts[0], w, h), y: evalExpr(parts[1], w, h)};
	}

	public static inline function parseWH(s:String, w:Int, h:Int):{w:Int, h:Int}
	{
		if (s == null)
			return {w: w, h: h};
		var parts = s.split(",");
		return {w: evalExpr(parts[0], w, h), h: evalExpr(parts[1], w, h)};
	}

	public static inline function fitContainFlx(s:FlxSprite, x:Int, y:Int, bw:Int, bh:Int):Void
	{
		var fw = s.frameWidth;
		var fh = s.frameHeight;
		if (fw <= 0 || fh <= 0)
		{
			s.visible = false;
			return;
		}
		s.origin.set(0, 0);
		s.offset.set(0, 0);
		s.scale.set(1, 1);
		s.updateHitbox();
		var sc = Math.min(bw / fw, bh / fh);
		s.setGraphicSize(Std.int(fw * sc), Std.int(fh * sc));
		s.updateHitbox();
		s.setPosition(x + Std.int((bw - s.width) * 0.5), y + Std.int((bh - s.height) * 0.5));
	}

	// cache helper
	static function addToFlixelCache(abs:String):Void
	{
		var g = flixel.FlxG.bitmap.get(abs);
		if (g == null)
		{
			try
			{
				var bd = openfl.display.BitmapData.fromFile(abs);
				g = flixel.FlxG.bitmap.add(bd, false, abs);
				if (g != null)
				{
					g.persist = true;
					g.destroyOnNoUse = false;
				}
			}
			catch (_:Dynamic) {}
		}
	}
}

/* -------------------- existing nodes kept as-is -------------------- */
// TextNode, GraphicNode, RectNode, CarouselNode
// (leave your current working versions in place)

/** ===== Nodes ===== */
class TextNode implements IThemeNode
{
	public var name(get, never):String;

	var spec:ThemeElementSpec;
	var theme:Theme;
	var text:FlxText;
	var _name:String;

	public function new(spec:ThemeElementSpec, theme:Theme)
	{
		this.spec = spec;
		this.theme = theme;
		_name = spec.name;
		text = new FlxText();
		text.wordWrap = true;
	}

	public inline function get_name():String
		return _name;

	public inline function basic():FlxBasic
		return text;

	public function addTo(state:FlxState):Void
		state.add(text);

	public function update(ctx:Context):Void
	{
		var sw = ctx.w, sh = ctx.h;
		var pos = Theme.parseXY(spec.pos, sw, sh);
		var w = (spec.size != null) ? Theme.parseWH(spec.size, sw, sh).w : sw;

		text.setPosition(pos.x, pos.y);
		text.fieldWidth = w;

		final str = Theme.expandWithOffsets(spec.content ?? "", ctx);
		final color = (spec.color != null) ? FlxColor.fromString(spec.color) : FlxColor.WHITE;
		final size = spec.pointSize != null ? spec.pointSize : 22;
		final align = spec.align != null ? spec.align : "left";

		// Optional external font from theme
		var fontName:String = null;
		if (spec.params != null && spec.params.font != null)
		{
			var fontPath:String = Std.string(spec.params.font);
			if (fontPath != null && fontPath != "")
			{
				var abs = theme.resolve(fontPath);
				#if sys
				try
				{
					var f = Font.fromFile(abs);
					if (f != null)
						fontName = f.fontName;
				}
				catch (_:Dynamic)
				{/* ignore */}
				#end
			}
		}

		text.setFormat(fontName, size, color, align);
		text.text = str;
		text.visible = (str != null && str != "");
	}
}

class GraphicNode implements IThemeNode
{
	public var name(get, never):String;

	var spec:ThemeElementSpec;
	var theme:Theme;
	var spr:FlxSprite;
	var _name:String;

	var isDynamic:Bool = false;
	var lastKey:String = null;

	public function new(spec:ThemeElementSpec, theme:Theme)
	{
		this.spec = spec;
		this.theme = theme;
		_name = spec.name;
		spr = new FlxSprite();
		spr.antialiasing = true;

		// Default: visible unless explicitly false OR this is "static"
		spr.visible = (spec.initialVisible != null) ? spec.initialVisible : (spec.name != "static");
		isDynamic = (spec.source != null && spec.source.indexOf("%") >= 0);
	}

	public inline function get_name():String
		return _name;

	public inline function basic():FlxBasic
		return spr;

	public function addTo(state:FlxState):Void
		state.add(spr);

	public function update(ctx:Context):Void
	{
		var sw = ctx.w, sh = ctx.h;
		var pos = Theme.parseXY(spec.pos, sw, sh);
		var wh = (spec.size != null) ? Theme.parseWH(spec.size, sw, sh) : {w: 0, h: 0};

		var src = Theme.expandWithOffsets(spec.source ?? "", ctx);
		if (src == null || src == "")
		{
			spr.visible = false;
			return;
		}

		var abs = theme.resolve(src);

		// --- short-circuit for static nodes: bind once then skip ---
		if (!isDynamic && lastKey != null)
		{
			// size/pos may still need to be enforced (if you resize window),
			// so keep the fit call using current spr.frame size:
			var bw = (wh.w > 0) ? wh.w : spr.frameWidth;
			var bh = (wh.h > 0) ? wh.h : spr.frameHeight;
			Theme.fitContainFlx(spr, pos.x, pos.y, bw, bh);
			return;
		}

		#if sys
		if (!sys.FileSystem.exists(abs))
		{
			util.Logger.Log.line('[THEME] Missing asset: ' + abs);
			spr.visible = false;
			return;
		}
		#end

		if (!FileSystem.exists(abs))
		{
			spr.visible = false;
			return;
		}

		// Cache or get
		var gr:flixel.graphics.FlxGraphic = flixel.FlxG.bitmap.get(abs);
		if (gr == null)
		{
			#if sys
			try
			{
				var bd = openfl.display.BitmapData.fromFile(abs);
				if (bd != null)
				{
					gr = flixel.FlxG.bitmap.add(bd, false, abs);
					if (gr != null)
					{
						gr.destroyOnNoUse = false;
						gr.persist = true;
					}
				}
			}
			catch (e:Dynamic)
			{
				util.Logger.Log.line("[THEME] Load failed: " + abs + " :: " + Std.string(e));
			}
			#end
		}
		if (gr == null)
		{
			spr.visible = false;
			return;
		}

		spr.loadGraphic(gr);

		var bw = (wh.w > 0) ? wh.w : gr.width;
		var bh = (wh.h > 0) ? wh.h : gr.height;
		Theme.fitContainFlx(spr, pos.x, pos.y, bw, bh);
		// NOTE: do NOT force spr.visible = true; state controls visibility (for "static")
		lastKey = abs; // remember what we bound last time
	}
}

class RectNode implements IThemeNode
{
	public var name(get, never):String;

	var spec:ThemeElementSpec;
	var spr:FlxSprite;
	var _name:String;

	public function new(spec:ThemeElementSpec)
	{
		this.spec = spec;
		_name = spec.name;
		spr = new FlxSprite();
	}

	public inline function get_name():String
		return _name;

	public inline function basic():FlxBasic
		return spr;

	public function addTo(state:FlxState):Void
		state.add(spr);

	public function update(ctx:Context):Void
	{
		var sw = ctx.w, sh = ctx.h;
		var pos = Theme.parseXY(spec.pos, sw, sh);
		var wh = Theme.parseWH(spec.size, sw, sh);
		var col = (spec.color != null) ? FlxColor.fromString(spec.color) : FlxColor.WHITE;
		spr.makeGraphic(wh.w, wh.h, col);
		spr.x = pos.x;
		spr.y = pos.y;
		spr.visible = true;
	}
}

class CarouselNode implements IThemeNode
{
	public var name(get, never):String;

	inline function get_name()
		return _name;

	var _name:String;
	var spec:ThemeElementSpec;
	var theme:Theme;

	var group:FlxTypedGroup<FlxSprite>;
	var tiles:Int;
	var tileW:Int;
	var tileH:Int;
	var spacing:Int;
	var centerScale:Float;
	var sideScale:Float;
	var farScale:Float;
	var alphaNear:Float;
	var alphaFar:Float;

	var sprites:Array<FlxSprite> = [];
	var lastTiles:Int = -1;
	var centerSprite:FlxSprite = null;

	public function new(spec:ThemeElementSpec, theme:Theme)
	{
		this.spec = spec;
		this.theme = theme;
		this._name = spec.name;

		tiles = getInt("tiles", 7);
		tileW = getInt("tileW", 150);
		tileH = getInt("tileH", 90);
		spacing = getInt("spacing", 18);
		centerScale = getFloat("centerScale", 1.08);
		sideScale = getFloat("sideScale", 0.90);
		farScale = getFloat("farScale", 0.75);
		alphaNear = getFloat("alphaNear", 1.0);
		alphaFar = getFloat("alphaFar", 0.35);

		group = new FlxTypedGroup<FlxSprite>();
	}

	inline function getInt(k:String, d:Int):Int
	{
		return (spec.params != null && Reflect.hasField(spec.params, k)) ? Std.parseInt(Std.string(Reflect.field(spec.params, k))) : d;
	}

	inline function getFloat(k:String, d:Float):Float
	{
		return (spec.params != null && Reflect.hasField(spec.params, k)) ? Std.parseFloat(Std.string(Reflect.field(spec.params, k))) : d;
	}

	public function basic():FlxBasic
		return group;

	public function addTo(state:FlxState):Void
		state.add(group);

	public function update(ctx:Context):Void
	{
		var pos = Theme.parseXY(spec.pos, ctx.w, ctx.h);
		var wh = Theme.parseWH(spec.size, ctx.w, ctx.h);

		if (tiles != lastTiles)
		{
			rebuildSprites();
			lastTiles = tiles;
		}

		var totalW = tiles * tileW + (tiles - 1) * spacing;
		var startX = pos.x + Std.int((wh.w - totalW) * 0.5);
		var y = pos.y + Std.int((wh.h - tileH) * 0.5);

		var mid = Std.int(tiles / 2);
		centerSprite = null;

		for (i in 0...tiles)
		{
			var offset = i - mid;
			var s = sprites[i];

			var path = ctx.resolveVar("CART", offset);
			if (path == null || path == "")
				path = ctx.resolveVar("BOX", offset);
			if (path == null || path == "" || !sys.FileSystem.exists(path))
			{
				s.visible = false;
				continue;
			}

			var gr = FlxG.bitmap.get(path);
			if (gr == null)
			{
				try
				{
					var bd = BitmapData.fromFile(path);
					gr = FlxG.bitmap.add(bd, false, path);
					if (gr != null)
					{
						gr.persist = true;
						gr.destroyOnNoUse = false;
					}
				}
				catch (_:Dynamic) {}
			}
			if (gr == null)
			{
				s.visible = false;
				continue;
			}

			s.loadGraphic(gr);
			s.setGraphicSize(tileW, tileH);
			s.updateHitbox();

			s.x = startX + i * (tileW + spacing);
			s.y = y;
			s.antialiasing = true;
			s.visible = true;

			var dist = (offset < 0) ? -offset : offset;
			var sc = (dist == 0) ? centerScale : (dist == 1 ? sideScale : farScale);
			var al = (dist == 0) ? alphaNear : alphaFar;
			s.scale.set(sc, sc);
			s.alpha = al;

			if (dist == 0)
				centerSprite = s;
		}

		if (centerSprite != null)
		{
			group.remove(centerSprite, true);
			group.add(centerSprite);
		}
	}

	/** Wiggle *all* tiles with tiny stagger and bounce-back. */
	public function wiggle(direction:Int):Void
	{
		// small tilt per tile, fading with distance
		var mid = Std.int(tiles / 2);
		for (i in 0...sprites.length)
		{
			var s = sprites[i];
			if (s == null || !s.visible)
				continue;
			var offset = i - mid;
			var dist = (offset < 0) ? -offset : offset;

			flixel.tweens.FlxTween.cancelTweensOf(s);
			var base = (direction < 0) ? 6 : -6;
			var amt = base * Math.max(0.25, 1.0 - dist * 0.22);
			s.angle = amt;

			var delay = dist * 0.02;
			flixel.tweens.FlxTween.tween(s, {angle: 0}, 0.28, {
				startDelay: delay,
				ease: flixel.tweens.FlxEase.backOut
			});
		}
	}

	function rebuildSprites():Void
	{
		group.clear();
		sprites = [];
		for (_ in 0...tiles)
		{
			var s = new FlxSprite();
			s.antialiasing = true;
			group.add(s);
			sprites.push(s);
		}
	}
}
