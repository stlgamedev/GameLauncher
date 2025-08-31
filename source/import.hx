import StringTools;
import aseprite.Aseprite;
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.system.FlxAssets.FlxShader;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxTimer;
import haxe.Json;
import haxe.ds.StringMap;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.display.ShaderParameter;
import openfl.display.Sprite;
import openfl.media.Sound;
import openfl.text.Font;
import openfl.utils.Assets;
import openfl.utils.ByteArray;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileOutput;
import themes.Theme;
import util.Config;
import util.GameEntry;
import util.GameIndex;
import util.Globals;
import util.Logger.Log;
import util.Logger;
import util.Paths;
import util.Preload;

using StringTools;






