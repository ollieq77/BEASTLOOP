
package funkin.stage;

import hscript.Parser;
import hscript.Interp;
import openfl.utils.Assets;
import flixel.FlxG;
import flixel.addons.effects.FlxTrail;
import polymod.backends.PolymodAssets;
import funkin.backend.Paths;
import funkin.game.PlayState;

import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxBasic;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.math.FlxMath;

import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import flixel.effects.FlxFlicker;

import flixel.system.FlxSound;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.math.FlxAngle;

import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.geom.Point;
import openfl.geom.Rectangle;

import openfl.display.Sprite;
import openfl.display.DisplayObject;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.media.Sound;
import openfl.text.TextField;
import openfl.text.TextFormat;

import haxe.Timer;
import haxe.Json;
import haxe.ds.StringMap;
import haxe.ds.IntMap;
import haxe.Log;

class StageScript
{
    public var stage:Stage;

    public var parser:Parser;
    public var interp:Interp;

    public var scriptPath:String;
    public var api:StageAPI;

    // Only used to tag traces, so a song script's errors don't look like stage script errors.
    public var label:String;

    public var loaded:Bool = false;

    public function new(stage:Stage, scriptPath:String, ?label:String)
    {
        this.stage = stage;
        this.scriptPath = scriptPath;
        this.label = label == null ? "StageScript" : label;

        parser = new Parser();
        parser.allowTypes = true;
        interp = new Interp();

        // Expose the stage to the script.
        interp.variables.set("stage", stage);
        interp.variables.set("curBeat", 0);
        interp.variables.set("daPixelZoom", PlayState.daPixelZoom);
        interp.variables.set("BackgroundGirls", BackgroundGirls);
        interp.variables.set("Type", Type);
        interp.variables.set("Std", Std);
        interp.variables.set("Math", Math);
        interp.variables.set("SONG", PlayState.SONG);
        interp.variables.set("isStoryMode", PlayState.isStoryMode);
        interp.variables.set("FlxTrail", FlxTrail);
        interp.variables.set("FlxTween", FlxTween);
        interp.variables.set("FlxEase", FlxEase);

        interp.variables.set("FlxSprite", FlxSprite);
        interp.variables.set("FlxCamera", FlxCamera);
        interp.variables.set("FlxObject", FlxObject);
        interp.variables.set("FlxBasic", FlxBasic);
        interp.variables.set("FlxState", FlxState);
        interp.variables.set("FlxGroup", FlxGroup);
        interp.variables.set("FlxTypedGroup", FlxTypedGroup);
        interp.variables.set("FlxText", FlxText);
        interp.variables.set("FlxBar", FlxBar);

        interp.variables.set("FlxColor", {
            WHITE: FlxColor.WHITE,
            BLACK: FlxColor.BLACK,
            RED: FlxColor.RED,
            GREEN: FlxColor.GREEN,
            BLUE: FlxColor.BLUE,
            YELLOW: FlxColor.YELLOW,
            CYAN: FlxColor.CYAN,
            MAGENTA: FlxColor.MAGENTA,
            TRANSPARENT: FlxColor.TRANSPARENT
        });
        interp.variables.set("FlxMath", FlxMath);

        interp.variables.set("FlxTimer", FlxTimer);
        interp.variables.set("FlxFlicker", FlxFlicker);

        interp.variables.set("StringTools", StringTools);
        interp.variables.set("Reflect", Reflect);
        interp.variables.set("Date", Date);
        interp.variables.set("EReg", EReg);

        interp.variables.set("FlxSound", FlxSound);
        interp.variables.set("FlxPoint", FlxPoint);
        interp.variables.set("FlxRect", FlxRect);
        interp.variables.set("FlxAngle", FlxAngle);

        interp.variables.set("Lib", Lib);
        interp.variables.set("Assets", Assets);
        interp.variables.set("BitmapData", BitmapData);
        interp.variables.set("BlendMode", {
            NORMAL: BlendMode.NORMAL,
            ADD: BlendMode.ADD,
            MULTIPLY: BlendMode.MULTIPLY,
            SCREEN: BlendMode.SCREEN,
            DARKEN: BlendMode.DARKEN,
            LIGHTEN: BlendMode.LIGHTEN,
            DIFFERENCE: BlendMode.DIFFERENCE,
            INVERT: BlendMode.INVERT,
            OVERLAY: BlendMode.OVERLAY
        });
        interp.variables.set("Point", Point);
        interp.variables.set("Rectangle", Rectangle);

        interp.variables.set("Sprite", Sprite);
        interp.variables.set("DisplayObject", DisplayObject);
        interp.variables.set("Event", Event);
        interp.variables.set("KeyboardEvent", KeyboardEvent);
        interp.variables.set("MouseEvent", MouseEvent);
        interp.variables.set("Sound", Sound);
        interp.variables.set("TextField", TextField);
        interp.variables.set("TextFormat", TextFormat);

        interp.variables.set("Timer", Timer);
        interp.variables.set("Json", Json);
        interp.variables.set("StringMap", StringMap);
        interp.variables.set("IntMap", IntMap);
        interp.variables.set("Log", Log);

        api = new StageAPI(stage);
        interp.variables.set("api", api);
        interp.variables.set("FlxG", FlxG);
    }

    public function destroy():Void
    {
        if (loaded)
            call("onDestroy");

        loaded = false;

        stage = null;
        interp = null;
        parser = null;
    }

    public function load():Bool
    {
        if (!Paths.exists(scriptPath))
        {
            trace('[$label] Script not found: $scriptPath');
            return false;
        }

        try
        {
            var source = PolymodAssets.getText(scriptPath);
            var program = parser.parseString(source, scriptPath);

            interp.execute(program);

            loaded = true;

            trace('[$label] Loaded: $scriptPath');

            return true;
        }
        catch (e:Dynamic)
        {
            trace('[$label] Failed to load $scriptPath: $e');
            return false;
        }
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic
    {
        if (!loaded)
            return null;

        var callback:Dynamic = interp.variables.get(func);

        if (callback == null || !Reflect.isFunction(callback))
            return null;

        if (args == null)
            args = [];

        try
        {
            return Reflect.callMethod(null, callback, args);
        }
        catch (e:Dynamic)
        {
            trace('[$label] Error in $func(): $e');
            return null;
        }
    }

    public function setVariable(name:String, value:Dynamic):Void
    {
        interp.variables.set(name, value);
    }
}
