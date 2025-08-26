package themes;

using StringTools;

/** ===== Spec (in the same file on purpose) ===== */
typedef ThemeSpec =
{
	var id:String;
	var name:String;
	var elements:Array<ThemeElementSpec>;
}

typedef ThemeElementSpec =
{
	var name:String; // e.g., "title", "cover"
	var type:String; // "text" | "graphic" | (future: "shader","carousel",...)
	@:optional var source:String; // for "graphic" (file path or "%BOX%")
	@:optional var content:String; // for "text" (can include %TITLE% etc.)
	@:optional var pos:String; // "x,y" where x/y can use w/h math, e.g. "w-10, h-140"
	@:optional var size:String; // "w,h" box to fit into (contain-fit for graphics; width for text)
	@:optional var align:String; // text align: "left"|"center"|"right"
	@:optional var color:String; // "#RRGGBB" for text
	@:optional var pointSize:Int; // text point size
	@:optional var params:Dynamic; // future extensibility
}

/** ===== Runtime update context ===== */
typedef Context =
{
	var w:Int;
	var h:Int; // Flixel world pixels (screen/backbuffer)
	var vars:Map<String, String>; // %VARS% -> values (TITLE, YEAR, BOX, ...)
	var themeDir:String; // absolute dir for the theme
}

/** ===== Interface all runtime elements implement ===== */
interface IThemeNode
{
	public function addTo(state:FlxState):Void;
	public function update(ctx:Context):Void; // called on selection change AND once in create()
}

/** ===== The Theme (loader + element builder + utils all in one) ===== */
class Theme
{
	public var dir:String; // absolute path to theme folder
	public var spec:ThemeSpec; // parsed JSON
	public var nodes:Array<IThemeNode>; // created once, updated every selection

	public function new(dir:String, spec:ThemeSpec)
	{
		this.dir = dir;
		this.spec = spec;
		this.nodes = [];
	}

	/** Load a theme.json from a folder. */
	public static function load(themeDir:String):Theme
	{
		var jsonPath = PathJoin(themeDir, "theme.json");
		var txt = File.getContent(jsonPath);
		var spec:ThemeSpec = Json.parse(txt);
		return new Theme(themeDir, spec);
	}

	/** Preload concrete graphics referenced by spec (skip placeholders like %BOX%). */
	public function preloadAssets():Void
	{
		for (el in spec.elements)
		{
			if (el.type == "graphic" && el.source != null && !el.source.startsWith("%"))
			{
				var abs = resolve(el.source);
				Preload.preloadOne(abs);
			}
		}
	}

	/** Create runtime nodes in spec order (z-order = array order), add to state once. */
	public function buildInto(state:FlxState):Void
	{
		nodes = [];
		for (el in spec.elements)
		{
			var node:IThemeNode = switch el.type
			{
				case "text": new TextNode(el);
				case "graphic": new GraphicNode(el, this);
				// future: case "shader": new ShaderNode(el, this);
				// future: case "carousel": new CarouselNode(el, this);
				default: null;
			}
			if (node != null)
			{
				node.addTo(state);
				nodes.push(node);
			}
		}
	}

	/** Update all nodes with a given context (call in create() and on selection change). */
	public inline function updateAll(ctx:Context):Void
	{
		for (n in nodes)
			n.update(ctx);
	}

	/** ====== Helpers (kept here to avoid ThemeUtils sprawl) ====== */
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

	/** Expand "%VARNAME%" with ctx.vars values. Unknowns -> empty. */
	public static inline function expand(s:String, vars:Map<String, String>):String
	{
		if (s == null)
			return null;
		// simple loop to avoid regex allocations on kiosk
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
					var key = s.substr(i + 1, j - i - 1);
					out.add(vars.exists(key) ? vars.get(key) : "");
					i = j + 1;
					continue;
				}
			}
			out.addChar(s.charCodeAt(i));
			i++;
		}
		return out.toString();
	}

	/** Very small expression evaluator supporting w,h numbers and +,-,*,/ (no parentheses). */
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
		// "#RRGGBB" -> 0xFFRRGGBB
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
		var sc = Math.min(boxW / ow, boxH / oh);
		s.scale.set(sc, sc);
		s.updateHitbox();
		s.x = x + Std.int((boxW - s.width) * 0.5);
		s.y = y + Std.int((boxH - s.height) * 0.5);
	}
}

/** ===== Concrete runtime nodes ===== */
private class TextNode implements IThemeNode
{
	var spec:ThemeElementSpec;
	var text:FlxText;

	public function new(spec:ThemeElementSpec)
	{
		this.spec = spec;
		text = new FlxText();
		text.wordWrap = true;
	}

	public function addTo(state:FlxState):Void
	{
		state.add(text);
	}

	public function update(ctx:Context):Void
	{
		var sw = ctx.w, sh = ctx.h;
		var pos = Theme.parseXY(spec.pos, sw, sh);
		var w = (spec.size != null) ? Theme.parseWH(spec.size, sw, sh).w : sw;

		text.setPosition(pos.x, pos.y);
		text.fieldWidth = w;

		var content = Theme.expand(spec.content ?? "", ctx.vars);
		var color = (spec.color != null) ? Theme.parseHexRGB(spec.color) : FlxColor.WHITE;
		var size = spec.pointSize != null ? spec.pointSize : 22;
		var align = spec.align != null ? spec.align : "left";
		text.setFormat(null, size, color, align);
		text.text = content;
		text.visible = (content != null && content != "");
	}
}

private class GraphicNode implements IThemeNode
{
	var spec:ThemeElementSpec;
	var theme:Theme;
	var spr:FlxSprite;

	public function new(spec:ThemeElementSpec, theme:Theme)
	{
		this.spec = spec;
		this.theme = theme;
		spr = new FlxSprite();
		spr.antialiasing = true; // change to false if you prefer crisp
	}

	public function addTo(state:FlxState):Void
	{
		state.add(spr);
	}

	public function update(ctx:Context):Void
	{
		var sw = ctx.w, sh = ctx.h;
		var pos = Theme.parseXY(spec.pos, sw, sh);
		var wh = (spec.size != null) ? Theme.parseWH(spec.size, sw, sh) : {w: 0, h: 0};

		// Resolve source (placeholders allowed, e.g., %BOX%)
		var src = Theme.expand(spec.source ?? "", ctx.vars);
		if (src == null || src == "")
		{
			spr.visible = false;
			return;
		}

		// Theme-relative if file doesn't exist as-typed
		if (!FileSystem.exists(src))
			src = theme.resolve(src);

		// If graphic not in cache yet, kick preload and try again on completion
		var gr:FlxGraphic = FlxG.bitmap.get(src);
		if (gr == null)
		{
			spr.visible = false;
			Preload.whenReady(src, () ->
			{
				var gr2 = FlxG.bitmap.get(src);
				if (gr2 != null)
				{
					spr.loadGraphic(gr2);
					var bw = (wh.w > 0) ? wh.w : gr2.width;
					var bh = (wh.h > 0) ? wh.h : gr2.height;
					Theme.fitContainFlx(spr, pos.x, pos.y, bw, bh);
					spr.visible = true;
				}
			});
			return;
		}

		// Bind & fit
		spr.loadGraphic(gr);
		var bw = (wh.w > 0) ? wh.w : gr.width;
		var bh = (wh.h > 0) ? wh.h : gr.height;
		Theme.fitContainFlx(spr, pos.x, pos.y, bw, bh);
		spr.visible = true;
	}
}
