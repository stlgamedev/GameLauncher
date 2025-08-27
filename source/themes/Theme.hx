package themes;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.graphics.FlxGraphic;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import util.Preload;

/** ===== Spec kept here (single-file theme system) ===== */
typedef ThemeSpec =
{
	var id:String;
	var name:String;
	var elements:Array<ThemeElementSpec>;
}

typedef ThemeElementSpec =
{
	var name:String; // e.g., "title", "cover"
	var type:String; // "text" | "graphic" | "rect" | (future: "shader","carousel")
	@:optional var source:String; // for "graphic" (file path or %BOX% / %BOX-1%)
	@:optional var content:String; // for "text" (can include %TITLE% / %TITLE+1%)
	@:optional var pos:String; // "x,y" where x/y can use w/h math
	@:optional var size:String; // "w,h" box to fit into (contain-fit for graphics; width for text/rect)
	@:optional var align:String; // text align: "left"|"center"|"right"
	@:optional var color:String; // "#RRGGBB" (text/rect)
	@:optional var pointSize:Int; // text point size
	@:optional var params:Dynamic; // freeform per type
	@:optional var initialVisible:Null<Bool>; // optional start visibility override
}

/** ===== Runtime update context ===== */
typedef Context =
{
	var w:Int;
	var h:Int; // Flixel world pixels
	var themeDir:String;

	/** Resolve %VARNAME% with optional +/- offset */
	var resolveVar:(name:String, offset:Int) -> String;
}

/** ===== Interface for runtime nodes ===== */
interface IThemeNode
{
	public var name(get, never):String;
	public function basic():FlxBasic;
	public function addTo(state:FlxState):Void;
	public function update(ctx:Context):Void;
}

/** ===== Theme (loader + node builder + utils) ===== */
class Theme
{
	public var dir:String;
	public var spec:ThemeSpec;
	public var nodes:Array<IThemeNode>;

	public function new(dir:String, spec:ThemeSpec)
	{
		this.dir = dir;
		this.spec = spec;
		this.nodes = [];
	}

	public static function load(themeDir:String):Theme
	{
		var jsonPath = PathJoin(themeDir, "theme.json");
		var txt = File.getContent(jsonPath);
		var spec:ThemeSpec = Json.parse(txt);
		return new Theme(themeDir, spec);
	}

	public function preloadAssets():Void
	{
		for (el in spec.elements)
		{
			if (el.type == "graphic" && el.source != null)
			{
				var s = el.source;
				var isPlaceholder = (s.length > 0 && s.charAt(0) == "%");
				if (!isPlaceholder)
				{
					var abs = resolve(s);
					Preload.preloadOne(abs);
				}
			}
		}
	}

	public function buildInto(state:FlxState):Void
	{
		nodes = [];
		for (el in spec.elements)
		{
			var node:IThemeNode = switch el.type
			{
				case "text": new TextNode(el);
				case "graphic": new GraphicNode(el, this);
				case "rect": new RectNode(el);
				default: null;
			}
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

	public inline function resolve(relOrAbs:String):String
	{
		return FileSystem.exists(relOrAbs) ? relOrAbs : PathJoin(dir, relOrAbs);
	}

	public static inline function PathJoin(a:String, b:String):String
	{
		if (a == null || a == "")
			return b;
		if (b == null || b == "")
			return a;
		var sep = (a.charAt(a.length - 1) == "/" || a.charAt(a.length - 1) == "\\") ? "" : "/";
		return a + sep + b;
	}

	/** Expand %KEY% or %KEY+1% / %KEY-2% using ctx.resolveVar. Unknowns -> "" */
	public static inline function expandWithOffsets(s:String, ctx:Context):String
	{
		if (s == null)
			return null;
		var out = new StringBuf();
		var i = 0;
		while (i < s.length)
		{
			var c = s.charAt(i);
			if (c == "%" && i + 1 < s.length)
			{
				var j = i + 1;
				while (j < s.length && s.charAt(j) != "%")
					j++;
				if (j < s.length && s.charAt(j) == "%")
				{
					var token = s.substr(i + 1, j - i - 1); // e.g., TITLE, BOX-1, YEAR+2
					var name = token;
					var off = 0;
					var plus = token.lastIndexOf("+");
					var minus = token.lastIndexOf("-");
					var idx = (plus > 0) ? plus : (minus > 0 ? minus : -1);
					if (idx > 0)
					{
						name = token.substr(0, idx);
						off = Std.parseInt(token.substr(idx)); // includes sign
						if (Math.isNaN(off))
							off = 0;
					}
					var val = ctx.resolveVar(name, off);
					out.add(val != null ? val : "");
					i = j + 1;
					continue;
				}
			}
			out.add(c);
			i++;
		}
		return out.toString();
	}

	/** math helpers */
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
				sign = 1.0;
				i++;
				continue;
			}
			if (ch == "-")
			{
				sign = -1.0;
				i++;
				continue;
			}
			var j = i;
			while (j < e.length && e.charAt(j) != "+" && e.charAt(j) != "-")
				j++;
			var term = StringTools.trim(e.substr(i, j - i));
			var val = parseMulDiv(term);
			total += sign * val;
			i = j;
		}
		return Std.int(total);
	}

	static inline function parseMulDiv(term:String):Float
	{
		if (term == "")
			return 0;
		var parts = term.split("*");
		var val = 1.0;
		for (p in parts)
		{
			var sub = p.split("/");
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
			val *= v;
		}
		return val;
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
			return {w: 0, h: 0};
		var parts = s.split(",");
		return {w: evalExpr(parts[0], w, h), h: evalExpr(parts[1], w, h)};
	}

	public static inline function parseHexRGB(hex:String):Int
	{
		if (hex == null)
			return FlxColor.WHITE;
		var s = StringTools.replace(hex, "#", "");
		return Std.parseInt("0xFF" + s.toUpperCase());
	}

	/** Contain-fit a FlxSprite inside a box (no cumulative scaling). */
	public static inline function fitContainFlx(s:FlxSprite, x:Int, y:Int, boxW:Int, boxH:Int):Void
	{
		var ow = s.frameWidth;
		var oh = s.frameHeight;
		if (ow <= 0 || oh <= 0)
		{
			s.visible = false;
			return;
		}
		// reset transforms so we compute from a clean state
		s.origin.set(0, 0);
		s.offset.set(0, 0);
		s.scale.set(1, 1);
		s.updateHitbox();

		var sc = Math.min(boxW / ow, boxH / oh);
		s.scale.set(sc, sc);
		s.updateHitbox();
		var px = x + Std.int((boxW - s.width) * 0.5);
		var py = y + Std.int((boxH - s.height) * 0.5);
		s.setPosition(px, py);
	}
}

/** ===== Nodes ===== */
class TextNode implements IThemeNode
{
	var spec:ThemeElementSpec;
	var text:FlxText;
	var _name:String;

	public var name(get, never):String;

	public function new(spec:ThemeElementSpec)
	{
		this.spec = spec;
		_name = spec.name;
		text = new FlxText();
		text.wordWrap = true;
	}

	public inline function get_name()
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

		var content = Theme.expandWithOffsets(spec.content ?? "", ctx);
		var color = (spec.color != null) ? Theme.parseHexRGB(spec.color) : FlxColor.WHITE;
		var size = spec.pointSize != null ? spec.pointSize : 22;
		var align = spec.align != null ? spec.align : "left";
		text.setFormat(null, size, color, align);
		text.text = content;
		text.visible = (content != null && content != "");
	}
}

class GraphicNode implements IThemeNode
{
	var spec:ThemeElementSpec;
	var theme:Theme;
	var spr:FlxSprite;
	var _name:String;

	public var name(get, never):String;

	public function new(spec:ThemeElementSpec, theme:Theme)
	{
		this.spec = spec;
		this.theme = theme;
		_name = spec.name;
		spr = new FlxSprite();
		spr.antialiasing = true;

		// Default: visible unless explicitly off OR this is the 'static' node
		if (spec.initialVisible != null)
		{
			spr.visible = spec.initialVisible;
		}
		else
		{
			spr.visible = (spec.name != "static");
		}
	}

	public inline function get_name()
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

		var abs = src;
		#if sys
		var isAbs = (abs.length > 1 && abs.charAt(1) == ":") || abs.charAt(0) == "/" || abs.charAt(0) == "\\";
		if (!isAbs)
			abs = theme.resolve(abs);
		#end

		var gr:FlxGraphic = FlxG.bitmap.get(abs);
		if (gr == null)
		{
			Preload.preloadOne(abs);
			Preload.whenReady(abs, () ->
			{
				var g2 = FlxG.bitmap.get(abs);
				if (g2 != null)
				{
					spr.loadGraphic(g2);
					var bw = (wh.w > 0) ? wh.w : g2.width;
					var bh = (wh.h > 0) ? wh.h : g2.height;
					Theme.fitContainFlx(spr, pos.x, pos.y, bw, bh);
					// NOTE: do NOT force spr.visible here; state controls visibility
				}
				else
				{
					spr.visible = false;
				}
			});
			// leave current visibility as-is
			return;
		}

		spr.loadGraphic(gr);
		var bw = (wh.w > 0) ? wh.w : gr.width;
		var bh = (wh.h > 0) ? wh.h : gr.height;
		Theme.fitContainFlx(spr, pos.x, pos.y, bw, bh);
		// NOTE: do NOT force spr.visible here; state controls visibility
	}
}

class RectNode implements IThemeNode
{
	var spec:ThemeElementSpec;
	var spr:FlxSprite;
	var _name:String;

	public var name(get, never):String;

	public function new(spec:ThemeElementSpec)
	{
		this.spec = spec;
		_name = spec.name;
		spr = new FlxSprite();
	}

	public inline function get_name()
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
		var col = Theme.parseHexRGB(spec.color);
		spr.makeGraphic(wh.w, wh.h, col);
		spr.x = pos.x;
		spr.y = pos.y;
		spr.visible = true;
	}
}
