package util;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.utils.ByteArray;

class CartBake
{
	// Where we write the final baked carts
	static inline var SUBDIR = "cache/carts";

	// Placement of the cover INSIDE the frame, in frame pixels.
	// You told me: pos: (100, 137), size: (924×476)
	static inline var COVER_X = 100;
	static inline var COVER_Y = 137;
	static inline var COVER_W = 924;
	static inline var COVER_H = 476;

	// Dark gray backer behind cover (in the label window)
	static inline var BACK_COLOR = 0xFF222222;

	// Final cart downscale width (disk-friendly). Height keeps aspect.
	public static var TARGET_WIDTH:Int = 200;

	/** Compose (cover behind frame), scale down, write once. */
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
			final sigText = 'frame=${frameMT}|cover=${coverMT}|tw=${TARGET_WIDTH}|v=2';
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

			if (need)
			{
				// Compose at frame resolution
				var canvas = new BitmapData(frameW, frameH, true, 0x00000000);

				// Fill label window with dark gray backer
				var backRect = new Rectangle(COVER_X, COVER_Y, COVER_W, COVER_H);
				canvas.fillRect(backRect, BACK_COLOR);

				// Draw cover (contain-fit into window)
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

				// Draw frame on top
				canvas.draw(frameBD, null, null, null, null, true);

				// Downscale to TARGET_WIDTH
				var targetW:Int = TARGET_WIDTH;
				var scaleDown = targetW / frameW;
				var targetH:Int = Std.int(Math.max(1, Std.int(frameH * scaleDown)));

				var small = new BitmapData(targetW, targetH, true, 0x00000000);
				var m2 = new Matrix();
				m2.scale(scaleDown, scaleDown);
				small.draw(canvas, m2, null, null, null, true);

				// Write PNG + sig
				var bytes:ByteArray = small.encode(small.rect, new PNGEncoderOptions());
				File.saveBytes(outPng, bytes);
				File.saveContent(outSig, sigText);

				small.dispose();
				canvas.dispose();

				util.Logger.Log.line('[CART] baked ' + g.id + ' -> ' + outPng);
			}

			// Cache into Flixel + remember path for Context %CART%
			g.cartPath = outPng;
			var gr:FlxGraphic = FlxG.bitmap.get(outPng);
			if (gr == null)
			{
				var bd = loadBD(outPng);
				if (bd != null)
				{
					gr = FlxG.bitmap.add(bd, false, outPng);
					if (gr != null)
					{
						gr.persist = true;
						gr.destroyOnNoUse = false;
					}
				}
			}
			g.cartKey = outPng;
		}

		frameBD.dispose();
	}

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
}
