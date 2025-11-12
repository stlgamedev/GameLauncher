package themes;

using StringTools;

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

typedef Context =
{
	var w:Int;
	var h:Int;
	var themeDir:String;
	var resolveVar:(name:String, offset:Int) -> String;
}

interface IThemeNode
{
	public var name(get, never):String;
	public function basic():FlxBasic;
	public function addTo(state:FlxState):Void;
	public function update(ctx:Context):Void;
}

/* --------------- Theme --------------- */
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
		final jsonPath = Path.join([themeDir, "theme.json"]);
		final txt = File.getContent(jsonPath);
		final spec:ThemeSpec = Json.parse(txt);
		return new Theme(themeDir, spec);
	}

	public function preloadAssets():Void
	{
		for (el in spec.elements)
		{
			if (el.type == "graphic" && el.source != null && el.source != "" && el.source.charAt(0) != "%")
			{
				final abs = resolve(el.source);
				if (FileSystem.exists(abs))
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
				case "glass": new GlassNode(el);
				case "genres": new GenresNode(el, this);
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

	public function getNodeByName<T:IThemeNode>(name:String):Null<T>
	{
		for (n in nodes)
			if (n.name == name)
				return cast n;
		return null;
	}

	// Add near other fields
	public var _fontCache:Map<String, String> = new Map(); // abs path -> fontName

	public function preloadFonts():Void
	{
		// Scan the theme for unique fonts and load once
		if (spec == null || spec.elements == null)
			return;
		for (el in spec.elements)
		{
			if (el.type == "text" && el.params != null && Reflect.hasField(el.params, "font"))
			{
				var rel:String = Std.string(Reflect.field(el.params, "font"));
				if (rel != null && rel != "")
					fontNameFor(rel);
			}
		}
	}

	/** Load font file once and return an OpenFL-registered fontName. */
	public function fontNameFor(relOrAbs:String):String
	{
		var abs = resolve(relOrAbs);
		var cached = _fontCache.get(abs);
		if (cached != null)
			return cached;
		#if sys
		try
		{
			var f = openfl.text.Font.fromFile(abs);
			if (f != null)
			{
				openfl.text.Font.registerFont(f);
				var name = f.fontName;
				_fontCache.set(abs, name);
				return name;
			}
		}
		catch (_:Dynamic) {}
		#end
		// fallback: let Flixel use its default font
		_fontCache.set(abs, null);
		return null;
	}

	/* --------- path helpers --------- */
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
		final c0 = p.charAt(0);
		if (c0 == "/" || c0 == "\\")
			return true;
		if (p.length >= 2 && p.charAt(1) == ":")
			return true;
		return false;
	}

	/* --------- param helpers --------- */
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
			final f = Std.parseFloat((v : String));
			return Math.isNaN(f) ? def : f;
		}
		return def;
	}

	public static function pInt(obj:Dynamic, key:String, def:Int, min:Int = -0x3fffffff, max:Int = 0x3fffffff):Int
	{
		if (obj == null || !Reflect.hasField(obj, key))
			return def;
		var v:Dynamic = Reflect.field(obj, key);
		var out = def;
		if (Std.isOfType(v, Int))
			out = (v : Int);
		else if (Std.isOfType(v, Float))
			out = Std.int(v);
		else if (Std.isOfType(v, String))
		{
			final p = Std.parseInt((v : String));
			out = (p == null) ? def : p;
		}
		if (out < min)
			out = min;
		if (out > max)
			out = max;
		return out;
	}

	/* --------- placement / expr --------- */
	public static inline function evalExpr(expr:String, w:Int, h:Int):Int
	{
		if (expr == null)
			return 0;
		var e = expr.trim();
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
			var term = e.substr(i, j - i).trim();
			var mul = 1.0;
			for (part in term.split("*"))
			{
				var sub = part.split("/");
				var v = Std.parseFloat(sub[0].trim());
				if (Math.isNaN(v))
					v = 0;
				for (k in 1...sub.length)
				{
					var d = Std.parseFloat(sub[k].trim());
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

	public static inline function parseXY(s:String, w:Int, h:Int):{x:Int, y:Int}
	{
		if (s == null)
			return {x: 0, y: 0};
		final parts = s.split(",");
		return {x: evalExpr(parts[0], w, h), y: evalExpr(parts[1], w, h)};
	}

	public static inline function parseWH(s:String, w:Int, h:Int):{w:Int, h:Int}
	{
		if (s == null)
			return {w: w, h: h};
		final parts = s.split(",");
		return {w: evalExpr(parts[0], w, h), h: evalExpr(parts[1], w, h)};
	}

	public static inline function fitContainFlx(s:FlxSprite, x:Int, y:Int, bw:Int, bh:Int):Void
	{
		final fw = s.frameWidth;
		final fh = s.frameHeight;
		if (fw <= 0 || fh <= 0)
		{
			s.visible = false;
			return;
		}
		s.origin.set(0, 0);
		s.offset.set(0, 0);
		s.scale.set(1, 1);
		s.updateHitbox();
		final sc = Math.min(bw / fw, bh / fh);
		s.setGraphicSize(Std.int(fw * sc), Std.int(fh * sc));
		s.updateHitbox();
		s.setPosition(x + Std.int((bw - s.width) * 0.5), y + Std.int((bh - s.height) * 0.5));
	}

	/* --------- token expander %TITLE+1% and %PLAYERS% --------- */
	public static function expandWithOffsets(s:String, ctx:Context):String
	{
		if (s == null)
			return null;
		var out = new StringBuf();
		var i = 0;
		while (i < s.length)
		{
			var ch = s.charAt(i);
			if (ch == "%" && i + 1 < s.length)
			{
				var j = i + 1;
				while (j < s.length && s.charAt(j) != "%")
					j++;
				if (j < s.length && s.charAt(j) == "%")
				{
					var token = s.substr(i + 1, j - i - 1);
					var name = token;
					var off = 0;
					var plus = token.lastIndexOf("+");
					var minus = token.lastIndexOf("-");
					var idx = (plus > 0) ? plus : (minus > 0 ? minus : -1);
					if (idx > 0)
					{
						name = token.substr(0, idx);
						var ofsStr = token.substr(idx);
						var n = Std.parseInt(ofsStr);
						if (n != null)
							off = n;
					}
					var val = ctx.resolveVar(name, off);
					// Default behavior: append the resolved value (or empty string if null).
					// Avoid appending the literal "null" by converting null -> "".
					// (no debug logging here)
					out.add(val != null ? val : "");
					i = j + 1;
					continue;
				}
			}
			out.add(ch);
			i++;
		}
		return out.toString();
	}

	/* --------- cache helper --------- */
	static function addToFlixelCache(abs:String):Void
	{
		if (!FileSystem.exists(abs))
			return;
		var g = FlxG.bitmap.get(abs);
		if (g != null)
			return;
		try
		{
			final bd = BitmapData.fromFile(abs);
			final gr = FlxG.bitmap.add(bd, false, abs);
			if (gr != null)
			{
				gr.persist = true;
				gr.destroyOnNoUse = false;
			}
		}
		catch (_:Dynamic) {}
	}

	/** Get a string param from a specific element in the theme JSON. */
	public function paramString(elementName:String, key:String):Null<String>
	{
		for (el in spec.elements)
		{
			if (el.name == elementName && el.params != null && Reflect.hasField(el.params, key))
			{
				final v:Dynamic = Reflect.field(el.params, key);
				return (v == null) ? null : Std.string(v);
			}
		}
		return null;
	}
}

/* -------------------- Nodes -------------------- */
class TextNode implements IThemeNode
{
	public var name(get, never):String;

	var _name:String;
	var spec:ThemeElementSpec;
	var theme:Theme;
	var text:FlxText;
	// change-detection caches
	var _lastContent:String = null;
	var _lastColor:Int = 0;
	var _lastPointSize:Int = -1;
	var _lastAlign:String = null;
	var _lastFontRel:String = null;
	var _lastFieldW:Int = -1;
	var _lastPosX:Int = -99999;
	var _lastPosY:Int = -99999;

	public function new(spec:ThemeElementSpec, theme:Theme)
	{
		this.spec = spec;
		this.theme = theme;
		_name = spec.name;

		text = new FlxText();
		text.wordWrap = true;
		text.antialiasing = true;
	}

	inline function get_name():String
		return _name;

	inline public function basic():FlxBasic
		return text;

	public function addTo(state:FlxState):Void
		state.add(text);

	public function update(ctx:Context):Void
	{
		var sw = ctx.w, sh = ctx.h;
		// Position/size: only update if box or pos changes
		var pos = Theme.parseXY(spec.pos, sw, sh);
		var fieldW = (spec.size != null) ? Theme.parseWH(spec.size, sw, sh).w : sw;

		if (pos.x != _lastPosX || pos.y != _lastPosY || fieldW != _lastFieldW)
		{
			text.setPosition(pos.x, pos.y);
			text.fieldWidth = fieldW;
			_lastPosX = pos.x;
			_lastPosY = pos.y;
			_lastFieldW = fieldW;
		}

		// Resolve dynamic content (tokens) and properties
		var raw = (spec.content != null ? spec.content : "");
		var content = Theme.expandWithOffsets(raw, ctx);
		var color = (spec.color != null) ? FlxColor.fromString(spec.color) : FlxColor.WHITE;
		var pointSize = (spec.pointSize != null) ? spec.pointSize : 22;
		var align = (spec.align != null) ? spec.align : "left";

		var fontRel:String = null;
		if (spec.params != null && Reflect.hasField(spec.params, "font"))
		{
			fontRel = Std.string(Reflect.field(spec.params, "font"));
			if (fontRel != null && fontRel == "")
				fontRel = null;
		}

		// Re-apply font/format ONLY if something changed
		if (content != _lastContent || color != _lastColor || pointSize != _lastPointSize || align != _lastAlign || fontRel != _lastFontRel)
		{
			var fontName:String = null;
			if (fontRel != null)
				fontName = theme.fontNameFor(fontRel); // cached & registered once

			text.setFormat(fontName, pointSize, color, align);
			text.font = fontName;

			text.text = (content == null) ? "" : content;

			_lastContent = content;
			_lastColor = color;
			_lastPointSize = pointSize;
			_lastAlign = align;
			_lastFontRel = fontRel;

			text.visible = (text.text != "");
		}

		// else: nothing changed → do nothing this frame
	}
}

class GraphicNode implements IThemeNode
{
	public var name(get, never):String;

	var _name:String;
	var spec:ThemeElementSpec;
	var theme:Theme;
	var spr:FlxSprite;

	var isDynamic:Bool;
	var lastKey:String = null;

	public function new(spec:ThemeElementSpec, theme:Theme)
	{
		this.spec = spec;
		this.theme = theme;
		_name = spec.name;
		spr = new FlxSprite();
		spr.antialiasing = true;
		spr.visible = (spec.initialVisible != null) ? spec.initialVisible : (spec.name != "static");
		isDynamic = (spec.source != null && spec.source.indexOf("%") >= 0);
	}

	inline function get_name():String
		return _name;

	inline public function basic():FlxBasic
		return spr;

	public function addTo(state:FlxState):Void
		state.add(spr);

	public function update(ctx:Context):Void
	{
		final sw = ctx.w, sh = ctx.h;
		final pos = Theme.parseXY(spec.pos, sw, sh);
		final wh = (spec.size != null) ? Theme.parseWH(spec.size, sw, sh) : {w: 0, h: 0};

		final raw = (spec.source != null ? spec.source : "");
		final src = Theme.expandWithOffsets(raw, ctx);
		if (src == null || src == "")
		{
			spr.visible = false;
			return;
		}
		final abs = theme.resolve(src);

		// static images: bind once, then only maintain fit/pos
		if (!isDynamic && lastKey != null)
		{
			final bw = (wh.w > 0) ? wh.w : spr.frameWidth;
			final bh = (wh.h > 0) ? wh.h : spr.frameHeight;
			Theme.fitContainFlx(spr, pos.x, pos.y, bw, bh);
			return;
		}

		#if sys
		if (!FileSystem.exists(abs))
		{
			spr.visible = false;
			return;
		}
		#end

		var gr:FlxGraphic = FlxG.bitmap.get(abs);
		if (gr == null)
		{
			#if sys
			try
			{
				final bd = BitmapData.fromFile(abs);
				if (bd != null)
				{
					gr = FlxG.bitmap.add(bd, false, abs);
					if (gr != null)
					{
						gr.persist = true;
						gr.destroyOnNoUse = false;
					}
				}
			}
			catch (_:Dynamic) {}
			#end
		}
		if (gr == null)
		{
			spr.visible = false;
			return;
		}

		spr.loadGraphic(gr);
		final bw = (wh.w > 0) ? wh.w : gr.width;
		final bh = (wh.h > 0) ? wh.h : gr.height;
		Theme.fitContainFlx(spr, pos.x, pos.y, bw, bh);
		lastKey = abs;
	}
}

class RectNode implements IThemeNode
{
	public var name(get, never):String;

	var _name:String;
	var spec:ThemeElementSpec;
	var spr:FlxSprite;

	public function new(spec:ThemeElementSpec)
	{
		this.spec = spec;
		_name = spec.name;
		spr = new FlxSprite();
	}

	inline function get_name():String
		return _name;

	inline public function basic():FlxBasic
		return spr;

	public function addTo(state:FlxState):Void
		state.add(spr);

	public function update(ctx:Context):Void
	{
		final sw = ctx.w, sh = ctx.h;
		final pos = Theme.parseXY(spec.pos, sw, sh);
		final wh = Theme.parseWH(spec.size, sw, sh);
		final col = (spec.color != null) ? FlxColor.fromString(spec.color) : FlxColor.WHITE;
		spr.makeGraphic(wh.w, wh.h, col);
		spr.x = pos.x;
		spr.y = pos.y;
		spr.visible = true;
	}
}

/* ---------------- Carousel ---------------- */
class CarouselNode implements IThemeNode
{
	public var name(get, never):String;

	inline function get_name():String
		return _name;

	// identity
	var _name:String;
	final el:ThemeElementSpec;
	final theme:Theme;

	// display
	var group:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();
	var sprites:Array<FlxSprite> = [];
	var animating:Bool = false;

	// lane (from pos/size)
	var laneX:Int = 0;
	var laneY:Int = 0;
	var laneW:Int = 0;
	var laneH:Int = 0;
	var laneReady:Bool = false;

	// params
	var tiles:Int = 7;
	var tileW:Int = 160;
	var tileH:Int = 100;
	var spacing:Int = 20;
	var centerScale:Float = 1.0;
	var sideScale:Float = 0.9;
	var farScale:Float = 0.75;
	var alphaNear:Float = 1.0;
	var alphaFar:Float = 0.35;
	var tweenTime:Float = 0.66;
	var leanDeg:Float = 10.0;

	// derived
	var mid:Int = 0;

	// tween counter
	var pending:Int = 0;

	// --- SFX (optional, loaded from theme dir; played via Flixel) ---
	var sfxMove:FlxSound = null;
	var sfxStart:FlxSound = null;

	public function new(el:ThemeElementSpec, theme:Theme)
	{
		this.el = el;
		this.theme = theme;
		_name = el.name;

		tiles = Theme.pInt(el.params, "tiles", tiles, 3, 99);
		tileW = Theme.pInt(el.params, "tileW", tileW, 8, 2000);
		tileH = Theme.pInt(el.params, "tileH", tileH, 8, 2000);
		spacing = Theme.pInt(el.params, "spacing", spacing, 0, 2000);
		centerScale = Theme.pFloat(el.params, "centerScale", centerScale);
		sideScale = Theme.pFloat(el.params, "sideScale", sideScale);
		farScale = Theme.pFloat(el.params, "farScale", farScale);
		alphaNear = Theme.pFloat(el.params, "alphaNear", alphaNear);
		alphaFar = Theme.pFloat(el.params, "alphaFar", alphaFar);
		tweenTime = Theme.pFloat(el.params, "tweenTime", tweenTime);
		leanDeg = Theme.pFloat(el.params, "leanDeg", leanDeg);

		sfxMove = loadThemeSfx("sfxMove");
		sfxStart = loadThemeSfx("sfxStart");

		mid = Std.int(tiles / 2);
	}

	inline function loadThemeSfx(key:String):FlxSound
	{
		if (el.params == null || !Reflect.hasField(el.params, key))
			return null;
		var rel:Dynamic = Reflect.field(el.params, key);
		var relStr = rel == null ? "" : Std.string(rel);
		if (relStr == "")
			return null;

		var abs = theme.resolve(relStr);
		var fx:FlxSound = null;
		#if sys
		try
		{
			var raw = Sound.fromFile(abs);
			// Wrap the OpenFL Sound in a FlxSound so we get mute/pause/master volume, etc.
			fx = FlxG.sound.load(raw, 1.0, false, null, false, false);
		}
		catch (_:Dynamic) {}
		#end
		return fx;
	}

	public inline function playMoveSfx():Void
	{
		if (sfxMove != null)
		{
			sfxMove.stop(); // avoid stacking many short bleeps
			sfxMove.play();
		}
	}

	/** Plays the preloaded start/launch sound if available.
		Returns true if it will call `cb` on complete; false if no sound. */
	public function playLaunchSound(cb:Void->Void):Bool
	{
		if (sfxStart == null)
			return false;

		// stop any in-flight playback to avoid overlaps
		sfxStart.stop();
		sfxStart.time = 0;

		// Prefer setting onComplete (older/newer Flixel versions both support this member)
		sfxStart.onComplete = () -> cb();
		sfxStart.play();
		return true;
	}

	public inline function basic():FlxBasic
		return group;

	public function addTo(state:FlxState):Void
		state.add(group);

	public function update(ctx:Context):Void
	{
		// keep lane rect updated (cheap)
		var p = Theme.parseXY(el.pos, ctx.w, ctx.h);
		var s = Theme.parseWH(el.size, ctx.w, ctx.h);
		laneX = p.x;
		laneY = p.y;
		laneW = s.w;
		laneH = s.h;
		laneReady = true;

		// lazy build once
		if (sprites.length == 0)
		{
			for (i in 0...tiles)
			{
				var sp = new FlxSprite();
				sp.antialiasing = true;
				sp.centerOrigin();
				sp.centerOffsets();
				sp.origin.y = 0;
				group.add(sp);
				sprites.push(sp);
			}
			// initial layout from current selection
			layoutInstant(Globals.selectedIndex);
		}
	}

	/* ----- public API used by GameSelectState ----- */
	public inline function isAnimating():Bool
		return animating;

	public function applySelected(sel:Int):Void
	{
		layoutInstant(sel);
	}

	/** Slide by delta (-1 left / +1 right) using pre-rotation so no sprite crosses the whole row. */
	public function move(delta:Int, newSel:Int):Void
	{
		if (!laneReady || sprites.length == 0 || animating)
			return;

		var n = (Globals.games != null) ? Globals.games.length : 0;
		if (n == 0)
			return;

		playMoveSfx();

		animating = true;

		final rowW = tiles * tileW + (tiles - 1) * spacing;
		final startX = laneX + Std.int((laneW - rowW) * 0.5);
		final baseY = laneY + Std.int((laneH - tileH) * 0.5);

		// entering game index at the far edge relative to the *new* selection
		var enteringOffset = (delta > 0) ? mid : -mid;
		var enteringGameIdx = wrap(newSel + enteringOffset, n);

		// Pre-rotate and seed the entering sprite just offscreen so every sprite only moves one slot.
		if (delta > 0)
		{
			// moving right => visuals slide left; reuse leftmost as new right entrant
			var s = sprites.shift();
			bindGraphicForIndex(s, enteringGameIdx);
			// size once (contain) so scale tween works consistently
			if (s.frameWidth > 0 && s.frameHeight > 0)
			{
				var fit = Math.min(tileW / s.frameWidth, tileH / s.frameHeight);
				s.setGraphicSize(Std.int(s.frameWidth * fit), Std.int(s.frameHeight * fit));
				s.updateHitbox();
			}
			s.y = baseY;
			s.x = slotX(startX, tiles); // one slot beyond right edge
			sprites.push(s);
		}
		else if (delta < 0)
		{
			// moving left => visuals slide right; reuse rightmost as new left entrant
			var s2 = sprites.pop();
			bindGraphicForIndex(s2, enteringGameIdx);
			if (s2.frameWidth > 0 && s2.frameHeight > 0)
			{
				var fit2 = Math.min(tileW / s2.frameWidth, tileH / s2.frameHeight);
				s2.setGraphicSize(Std.int(s2.frameWidth * fit2), Std.int(s2.frameHeight * fit2));
				s2.updateHitbox();
			}
			s2.y = baseY;
			s2.x = slotX(startX, -1); // one slot before left edge
			sprites.unshift(s2);
		}
		// Lean direction: RIGHT key => CCW (negative angle), LEFT key => CW (positive)
		final lean = (delta > 0) ? -leanDeg : leanDeg;

		pending = 0;

		for (i in 0...tiles)
		{
			var sp = sprites[i];

			var targetOffset = i - mid;
			var targetX = slotX(startX, i);
			var sc = scaleForOffset(targetOffset);
			// var al        = alphaForOffset(targetOffset);

			FlxTween.cancelTweensOf(sp);
			FlxTween.cancelTweensOf(sp.scale);

			// keep lane line steady
			sp.y = baseY;
			// sp.alpha = al;

			pending += 2;

			FlxTween.tween(sp, {x: targetX}, tweenTime, {
				ease: FlxEase.quadOut,
				onComplete: _ -> onPieceDone()
			});
			FlxTween.tween(sp.scale, {x: sc, y: sc}, tweenTime, {
				ease: FlxEase.quadOut,
				onComplete: _ -> onPieceDone()
			});

			// quick lean, bounce back
			sp.angle = lean;
			FlxTween.tween(sp, {angle: 0}, tweenTime * 0.9, {
				ease: FlxEase.backOut,
				startDelay: 0.02
			});
		}
	}

	inline function slotX(startX:Int, index:Int):Int
		return startX + index * (tileW + spacing);

	function onPieceDone():Void
	{
		pending--;
		if (pending <= 0)
			animating = false;
	}

	/* ----- layout / helpers ----- */
	function layoutInstant(selected:Int):Void
	{
		if (!laneReady || sprites.length == 0)
			return;
		final n = (Globals.games != null) ? Globals.games.length : 0;
		if (n == 0)
			return;

		final rowW = tiles * tileW + (tiles - 1) * spacing;
		final startX = laneX + Std.int((laneW - rowW) * 0.5);
		final baseY = laneY + Std.int((laneH - tileH) * 0.5);

		for (i in 0...tiles)
		{
			var offset = i - mid;
			var gIdx = wrap(selected + offset, n);

			var sp = sprites[i];
			bindGraphicForIndex(sp, gIdx);

			// contain-fit inside tile box
			if (sp.frameWidth > 0 && sp.frameHeight > 0)
			{
				var fit = Math.min(tileW / sp.frameWidth, tileH / sp.frameHeight);
				sp.setGraphicSize(Std.int(sp.frameWidth * fit), Std.int(sp.frameHeight * fit));
				sp.updateHitbox();
			}
			var x = slotX(startX, i);
			var sc = scaleForOffset(offset);
			// var al = alphaForOffset(offset);

			sp.x = x;
			sp.y = baseY;
			sp.scale.set(sc, sc);
			// sp.alpha = al;
			sp.angle = 0;
		}
	}

	static inline function wrap(i:Int, n:Int):Int
	{
		if (n <= 0)
			return 0;
		var r = i % n;
		return (r < 0) ? r + n : r;
	}

	function scaleForOffset(off:Int):Float
	{
		return switch (Std.int(Math.abs(off)))
		{
			case 0: centerScale;
			case 1: sideScale;
			default: farScale;
		}
	}

	function alphaForOffset(off:Int):Float
	{
		return (Math.abs(off) == 0) ? alphaNear : alphaFar;
	}

	function bindGraphicForIndex(sp:FlxSprite, gameIndex:Int):Void
	{
		if (Globals.games == null || gameIndex < 0 || gameIndex >= Globals.games.length)
		{
			sp.visible = false;
			return;
		}
		var g = Globals.games[gameIndex];
		if (g == null)
		{
			sp.visible = false;
			return;
		}
		var path = (g.cartPath != null && g.cartPath != "") ? g.cartPath : g.box;
		#if sys
		if (path == null || path == "" || !FileSystem.exists(path))
		{
			sp.visible = false;
			return;
		}
		#end

		var gr:FlxGraphic = FlxG.bitmap.get(path);
		if (gr == null)
		{
			#if sys
			try
			{
				final bd = BitmapData.fromFile(path);
				if (bd != null)
				{
					gr = FlxG.bitmap.add(bd, false, path);
					if (gr != null)
					{
						gr.persist = true;
						gr.destroyOnNoUse = false;
					}
				}
			}
			catch (_:Dynamic) {}
			#end
		}
		if (gr == null)
		{
			sp.visible = false;
			return;
		}
		sp.loadGraphic(gr);
		sp.visible = true;
	}
}

private class GlassNode implements IThemeNode
{
	public var name(get, never):String;

	inline function get_name():String
		return _name;

	var _name:String;
	var spec:ThemeElementSpec;

	var spr:FlxSprite;
	var lastW:Int = -1;
	var lastH:Int = -1;

	public function new(spec:ThemeElementSpec)
	{
		this.spec = spec;
		this._name = spec.name;
		this.spr = new FlxSprite();
		spr.antialiasing = true;
	}

	public function basic():FlxBasic
		return spr;

	public function addTo(state:FlxState):Void
		state.add(spr);

	public function update(ctx:Context):Void
	{
		final pos = Theme.parseXY(spec.pos, ctx.w, ctx.h);
		final wh = Theme.parseWH(spec.size, ctx.w, ctx.h);

		// Only redraw when size changes (or first time)
		if (wh.w != lastW || wh.h != lastH || spr.pixels == null)
		{
			lastW = wh.w;
			lastH = wh.h;
			spr.loadGraphic(makeGlassBitmap(wh.w, wh.h));
			spr.updateHitbox();
		}
		spr.x = pos.x;
		spr.y = pos.y;

		// Honor alpha param if present
		if (spec.params != null && Reflect.hasField(spec.params, "alpha"))
			spr.alpha = Theme.pFloat(spec.params, "alpha", 1.0);
		else
			spr.alpha = 1.0;

		spr.visible = true;
	}

	function makeGlassBitmap(w:Int, h:Int):BitmapData
	{
		if (w <= 1 || h <= 1)
			return new BitmapData(1, 1, true, 0x00000000);

		// Params
		var r = (spec.params != null
			&& Reflect.hasField(spec.params, "cornerRadius")) ? Theme.pInt(spec.params, "cornerRadius", 18, 0, 256) : 18;

		var gradTop = (spec.params != null
			&& Reflect.hasField(spec.params,
				"gradientTop")) ? FlxColor.fromString(Std.string(Reflect.field(spec.params, "gradientTop"))) : FlxColor.fromRGB(0x1A, 0x24, 0x48);
		var gradBot = (spec.params != null
			&& Reflect.hasField(spec.params,
				"gradientBottom")) ? FlxColor.fromString(Std.string(Reflect.field(spec.params, "gradientBottom"))) : FlxColor.fromRGB(0x15, 0x1B, 0x34);

		var strokeOuter = (spec.params != null
			&& Reflect.hasField(spec.params,
				"strokeOuter")) ? FlxColor.fromString(Std.string(Reflect.field(spec.params, "strokeOuter"))) : FlxColor.fromRGB(0x23, 0x37, 0x4D);
		var strokeInner = (spec.params != null
			&& Reflect.hasField(spec.params,
				"strokeInner")) ? FlxColor.fromString(Std.string(Reflect.field(spec.params, "strokeInner"))) : FlxColor.fromRGB(0x5A, 0xA9, 0xFF);
		var strokeInnerA = (spec.params != null
			&& Reflect.hasField(spec.params, "strokeInnerAlpha")) ? Theme.pFloat(spec.params, "strokeInnerAlpha", 0.25) : 0.25;

		// Optional corner clipping for header “top only”
		var corners = (spec.params != null
			&& Reflect.hasField(spec.params, "corners")) ? Std.string(Reflect.field(spec.params, "corners")) : "all";
		var topOnly = (corners == "top");

		// Draw with OpenFL Shape for nice rounded corners + gradient
		var shape = new openfl.display.Shape();
		var g = shape.graphics;

		// Gradient fill
		var m = new openfl.geom.Matrix();
		m.createGradientBox(w, h, Math.PI / 2);

		g.lineStyle(0, 0, 0);
		g.beginGradientFill(openfl.display.GradientType.LINEAR, [gradTop, gradBot], [1, 1], [0, 255], m);

		if (topOnly)
			drawTopRoundedRect(g, 0, 0, w, h, r);
		else
			g.drawRoundRect(0, 0, w, h, r * 2, r * 2);

		g.endFill();

		// Outer stroke
		g.lineStyle(1, strokeOuter, 1);
		if (topOnly)
			drawTopRoundedRect(g, 0, 0, w, h, r);
		else
			g.drawRoundRect(0, 0, w, h, r * 2, r * 2);

		// Inner stroke (subtle)
		g.lineStyle(1, strokeInner, strokeInnerA);
		if (topOnly)
			drawTopRoundedRect(g, 1, 1, w - 2, h - 2, Math.max(0, r - 1));
		else
			g.drawRoundRect(1, 1, w - 2, h - 2, Math.max(0, r - 1) * 2, Math.max(0, r - 1) * 2);

		var bd = new BitmapData(w, h, true, 0x00000000);
		var mtx = new openfl.geom.Matrix();
		bd.draw(shape, mtx, null, null, null, true);
		return bd;
	}

	inline function drawTopRoundedRect(g:openfl.display.Graphics, x:Float, y:Float, w:Float, h:Float, r:Float):Void
	{
		// Rounded on top-left/top-right, square on bottom
		g.moveTo(x + r, y);
		g.lineTo(x + w - r, y);
		g.curveTo(x + w, y, x + w, y + r);
		g.lineTo(x + w, y + h);
		g.lineTo(x, y + h);
		g.lineTo(x, y + r);
		g.curveTo(x, y, x + r, y);
	}
}

private class GenresNode implements IThemeNode
{
	public var name(get, never):String;

	inline function get_name():String
		return _name;

	var _name:String;
	final el:ThemeElementSpec;
	final theme:Theme;

	var group:flixel.group.FlxGroup;
	var icons:Array<FlxSprite> = [];

	// cached rect
	var x0:Int = 0;
	var y0:Int = 0;
	var rw:Int = 0;
	var rh:Int = 0;

	// params
	var chipW:Int = 96;
	var chipH:Int = 96;
	var gap:Int = 16;
	var align:String = "right"; // "left" | "right"

	// static genre atlas
	static var genreFrames:FlxAtlasFrames = null;

	public function new(el:ThemeElementSpec, theme:Theme)
	{
		this.el = el;
		this.theme = theme;
		this._name = el.name;
		this.group = new flixel.group.FlxGroup();

		// read params
		chipW = Theme.pInt(el.params, "chipW", chipW, 8, 4096);
		chipH = Theme.pInt(el.params, "chipH", chipH, 8, 4096);
		gap = Theme.pInt(el.params, "gap", gap, 0, 4096);
		align = (el.params != null && Reflect.hasField(el.params, "align")) ? Std.string(Reflect.field(el.params, "align")) : "right";

		// Load genre atlas once
		if (genreFrames == null)
		{
			genreFrames = FlxAtlasFrames.fromSparrow("assets/images/genres.png", "assets/images/genres.xml");
		}
	}

	public function basic():FlxBasic
		return group;

	public function addTo(state:FlxState):Void
		state.add(group);

	public function update(ctx:Context):Void
	{
		// Update our rect from pos/size
		var p = Theme.parseXY(el.pos, ctx.w, ctx.h);
		var s = Theme.parseWH(el.size, ctx.w, ctx.h);
		x0 = p.x;
		y0 = p.y;
		rw = s.w;
		rh = s.h;

		// Collect genres via %GENRE1..N% using the existing resolver
		var names = new Array<String>();
		for (k in 1...20) // up to 19 genres; raise if needed
		{
			var v = ctx.resolveVar("GENRE" + k, 0);
			if (v == null || v == "")
				break;
			names.push(v);
		}

		layout(names);
	}

	function layout(genres:Array<String>):Void
	{
		// Ensure pool size
		ensurePool(genres.length);

		// Start horizontally inside our rect; align right by default
		var startX = (align == "right") ? (x0 + rw - chipW) : x0;

		var yTop = y0 + Std.int((rh - chipH) * 0.5); // vertically centered inside our slot

		for (i in 0...icons.length)
		{
			var vis = (i < genres.length);
			icons[i].visible = vis;
			if (!vis)
				continue;

			var bx = (align == "right") ? startX - i * (chipW + gap) : startX + i * (chipW + gap);
			var by = yTop;

			// Set genre icon from atlas
			var frameName = genres[i].toLowerCase();
			if (genreFrames != null && genreFrames.exists(frameName))
			{
				icons[i].frames = genreFrames;
				icons[i].animation.frameName = frameName;
				icons[i].setGraphicSize(chipW, chipH);
				// Ensure FlxGraphic is persistent and not destroyed on non-use
				if (icons[i].graphic != null)
				{
					icons[i].graphic.persist = true;
					icons[i].graphic.destroyOnNoUse = false;
				}
			}
			else
			{
				icons[i].makeGraphic(chipW, chipH, FlxColor.TRANSPARENT);
			}
			icons[i].x = bx;
			icons[i].y = by;
		}
	}

	function ensurePool(n:Int):Void
	{
		// grow
		while (icons.length < n)
		{
			var b = new FlxSprite();
			b.antialiasing = true;
			group.add(b);
			icons.push(b);
		}

		// shrink (hide extras)
		for (i in n...icons.length)
		{
			icons[i].visible = false;
		}
	}
}
