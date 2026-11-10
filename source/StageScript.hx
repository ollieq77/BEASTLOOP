
package;

import hscript.Parser;
import hscript.Interp;
import openfl.utils.Assets;
import flixel.FlxG;
import flixel.addons.effects.FlxTrail;
import polymod.backends.PolymodAssets;

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

        api = new StageAPI(stage);
        interp.variables.set("api", api);
        interp.variables.set("FlxG", FlxG);
    }

    public function load():Bool
    {
        if (!PolymodAssets.exists(scriptPath))
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

    public function destroy():Void
    {
        if (loaded)
            call("onDestroy");

        loaded = false;

        stage = null;
        interp = null;
        parser = null;
    }
}
