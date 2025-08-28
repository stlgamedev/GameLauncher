package util;

import haxe.crypto.Crc32;
import haxe.io.Bytes;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.utils.ByteArray;

class CartBake
{
	static inline var SUBDIR = "cache/carts";

	// Label window inside the frame (in frame coords)
	static inline var COVER_X = 103;
	static inline var COVER_Y = 138;
	static inline var COVER_W = 627;
	static inline var COVER_H = 474;

	static inline var BACK_COLOR = 0xFF222222; // dark gray behind cover

	// Final cart downscale width (disk-friendly). Height keeps aspect.
	public static var TARGET_WIDTH:Int = 220;

	/** Compose (cover behind tinted frame), scale down, write once. */
	public static function buildAll(games:Array<util.GameEntry>, frameAbs:String):Void
	{
		if (games == null || games.length == 0)
			return;
		if (frameAbs == null || !FileSystem.exists(frameAbs))
		{
			util.Logger.Log.line("[CART] frame missing: " + frameAbs);
			return;
		}

		final outDir = Path.join([Globals.cfg.contentRootDir, SUBDIR]);
		ensureDir(outDir);

		final frameBD = loadBD(frameAbs);
		if (frameBD == null)
		{
			util.Logger.Log.line("[CART] failed to load frame: " + frameAbs);
			return;
		}
		final frameW = frameBD.width;
		final frameH = frameBD.height;
		final frameMT = FileSystem.stat(frameAbs).mtime.getTime();

		for (g in games)
		{
			if (g == null || g.id == null || g.id == "")
				continue;
			if (g.box == null || g.box == "" || !FileSystem.exists(g.box))
			{
				util.Logger.Log.line('[CART] skip (no box): ' + g.id);
				continue;
			}

			final outPng = Path.join([outDir, g.id + ".png"]);
			final outSig = outPng + ".sig";

			final coverMT = FileSystem.stat(g.box).mtime.getTime();
			final sigText = 'frame=${frameMT}|cover=${coverMT}|tw=${TARGET_WIDTH}|v=5|id=${g.id}';
			var need = true;
			if (FileSystem.exists(outPng) && FileSystem.exists(outSig))
			{
				try
				{
					if (File.getContent(outSig) == sigText)
						need = false;
				}
				catch (_:Dynamic) {}
			}
			if (!need)
			{
				// still wire up runtime fields/cache
				g.cartPath = outPng;
				ensureFlixelCache(outPng);
				continue;
			}

			// Compose at frame resolution
			var canvas = new BitmapData(frameW, frameH, true, 0x00000000);

			// Label backer
			var backRect = new Rectangle(COVER_X, COVER_Y, COVER_W, COVER_H);
			canvas.fillRect(backRect, BACK_COLOR);

			// Cover (contain-fit)
			var coverBD = loadBD(g.box);
			if (coverBD != null)
			{
				var sc = Math.min(COVER_W / coverBD.width, COVER_H / coverBD.height);
				var dw = coverBD.width * sc;
				var dh = coverBD.height * sc;
				var dx = COVER_X + Std.int((COVER_W - dw) * 0.5);
				var dy = COVER_Y + Std.int((COVER_H - dh) * 0.5);
				var m = new Matrix();
				m.scale(sc, sc);
				m.translate(dx, dy);
				canvas.draw(coverBD, m, null, null, null, true);
				coverBD.dispose();
			}

			// ----- Subtle tint using Flixel color utilities -----
			// Stable hue from CRC32 of game id
			var crc = Crc32.make(Bytes.ofString(g.id));
			var hue = crc % 360; // 0..359
			// dialed back saturation/brightness
			var sat = 0.45;
			var bri = 0.65;
			var tintColor = FlxColor.fromHSB(hue, sat, bri);

			// Convert to multipliers and mix toward 1.0 to preserve highlights
			// lower mix => more subtle tint
			var mix = 0.35; // was 0.65
			var rm = (tintColor.red / 255.0) * mix + (1 - mix);
			var gm = (tintColor.green / 255.0) * mix + (1 - mix);
			var bm = (tintColor.blue / 255.0) * mix + (1 - mix);
			var ct = new ColorTransform(rm, gm, bm, 1, 0, 0, 0, 0);

			// Draw the frame with the tint transform over the composed cover/backer
			canvas.draw(frameBD, null, ct, null, null, true);

			// Downscale to TARGET_WIDTH
			var targetW = TARGET_WIDTH;
			var scaleDown = targetW / frameW;
			var targetH = Math.ceil(Math.max(1, Std.int(frameH * scaleDown)));
			var small = new BitmapData(targetW, targetH, true, 0x00000000);
			var m2 = new Matrix();
			m2.scale(scaleDown, scaleDown);
			small.draw(canvas, m2, null, null, null, true);

			// Save PNG + sig
			var bytes:ByteArray = small.encode(small.rect, new PNGEncoderOptions());
			File.saveBytes(outPng, bytes);
			File.saveContent(outSig, sigText);

			small.dispose();
			canvas.dispose();

			util.Logger.Log.line('[CART] baked ' + g.id + ' -> ' + outPng);

			// Runtime fields + cache
			g.cartPath = outPng;
			ensureFlixelCache(outPng);
		}

		frameBD.dispose();
	}

	// -------- utils (std / openfl) --------
	static inline function ensureDir(p:String):Void
	{
		if (!FileSystem.exists(p))
			FileSystem.createDirectory(p);
	}

	static function loadBD(abs:String):BitmapData
	{
		try
			return BitmapData.fromFile(abs)
		catch (_:Dynamic) {}
		return null;
	}
	static function ensureFlixelCache(path:String):Void
	{
		var gr:FlxGraphic = FlxG.bitmap.get(path);
		if (gr == null)
		{
			var bd = loadBD(path);
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
	}
}
