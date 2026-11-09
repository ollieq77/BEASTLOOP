package;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxState;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;

class StageAPI
{
    public var stage:Stage;
    public var camera:CameraAPI;

    // The running PlayState, so scripts can add things above the characters.
    public var state:FlxState;

    // The object the game camera follows. Set before onIntro runs.
    public var camFollow:FlxObject;

    // Set these from onSongEnd(nextSong) to carry story-mode state into the next song.
    public var skipNextTransition:Bool = false;
    public var carryCamera:Bool = false;

    // Wired up by PlayState.
    public var startCountdownFn:Void->Void;
    public var setCutsceneFn:Bool->Void;

    public var setGfSpeedFn:Int->Void;
    public var setVocalsVolumeFn:Float->Void;
    public var setMusicVolumeFn:Float->Void;
    public var setCamZoomingFn:Bool->Void;
    public var addCameraZoomFn:Float->Float->Void;
    public var getCamZoomingFn:Void->Bool;
    public var loadDialogueFn:String->Void;

    var boyfriend:Boyfriend;
    var dad:Character;
    var gf:Character;

    public function new(stage:Stage)
    {
        this.stage = stage;
    }

    public function setCharacters(boyfriend:Boyfriend, dad:Character, gf:Character):Void
    {
        this.boyfriend = boyfriend;
        this.dad = dad;
        this.gf = gf;
    }

    public function getCharacter(name:String):Character
    {
        return switch (name.toLowerCase())
        {
            case "boyfriend": boyfriend;
            case "dad": dad;
            case "gf": gf;
            default: null;
        }
    }

    public function setCameras(game:FlxCamera, hud:FlxCamera):Void
    {
        camera = new CameraAPI(game, hud);
    }

    public function getSprite(name:String):FlxSprite
    {
        return stage.getSprite(name);
    }

    public function getObject(name:String):FlxBasic
    {
        return stage.getObject(name);
    }

    public function addObject(object:FlxBasic, name:String):Void
    {
        stage.addObject(object, name);
    }

    public function randomInt(min:Int, max:Int):Int
    {
        return FlxG.random.int(min, max);
    }

    public function randomBool(chance:Float):Bool
    {
        return FlxG.random.bool(chance);
    }

    public function setGfSpeed(value:Int):Void
    {
        if (setGfSpeedFn != null)
            setGfSpeedFn(value);
    }

    public function setVocalsVolume(value:Float):Void
    {
        if (setVocalsVolumeFn != null)
            setVocalsVolumeFn(value);
    }

    public function setMusicVolume(value:Float):Void
    {
        if (setMusicVolumeFn != null)
            setMusicVolumeFn(value);
    }

    public function setCamZooming(value:Bool):Void
    {
        if (setCamZoomingFn != null)
            setCamZoomingFn(value);
    }

    public function addCameraZoom(game:Float, hud:Float):Void
    {
        if (addCameraZoomFn != null)
            addCameraZoomFn(game, hud);
    }

    public var camZooming(get, never):Bool;

    function get_camZooming():Bool
    {
        return getCamZoomingFn != null ? getCamZoomingFn() : false;
    }

    public function loadDialogue(file:String):Void
    {
        if (loadDialogueFn != null)
            loadDialogueFn(file);
    }
    

    // key is a sound name like 'carPass0' (resolved through Paths.sound, so mods can override it).
    // A full path ('assets/sounds/carPass0.ogg') still works for older scripts.
    public function playSound(key:String, volume:Float = 1, ?onComplete:Dynamic):Void
    {
        var done:Void->Void = null;

        if (onComplete != null)
            done = function() onComplete();

        FlxG.sound.play(soundPath(key), volume, false, null, true, done);
    }

    // Path for a sound key, for scripts that need to load one themselves (FlxG.sound.load...).
    public function soundPath(key:String):String
    {
        return StringTools.startsWith(key, 'assets/') ? key : Paths.sound(key);
    }

    // Path for an image key like 'weeb/senpaiCrazy' (no extension).
    public function imagePath(key:String):String
    {
        return Paths.image(key);
    }

    // ---- State access (draws above the stage and the characters) ----

    public function addToState(object:FlxBasic):Void
    {
        if (state != null)
            state.add(object);
    }

    public function removeFromState(object:FlxBasic):Void
    {
        if (state != null)
            state.remove(object);
    }

    // ---- Intro / cutscene control ----

    public function startCountdown():Void
    {
        if (startCountdownFn != null)
            startCountdownFn();
    }

    public function setInCutscene(value:Bool):Void
    {
        if (setCutsceneFn != null)
            setCutsceneFn(value);
    }

    // ---- Helpers so scripts don't need FlxColor / FlxEase / FlxTimer ----

    // Solid colour rectangle. Color is 0xAARRGGBB.
    public function makeSolid(x:Float, y:Float, width:Int, height:Int, color:Int):FlxSprite
    {
        return new FlxSprite(x, y).makeGraphic(width, height, color);
    }

    // Sprite with a Sparrow atlas loaded (add animations on the result).
    // key is the shared png/xml name under assets/images, e.g. 'weeb/senpaiCrazy'.
    public function makeSparrow(x:Float, y:Float, key:String):FlxSprite
    {
        var sprite = new FlxSprite(x, y);
        sprite.frames = Paths.sparrow(key);
        return sprite;
    }

    // The callback receives the FlxTimer, so it can call tmr.reset(...).
    public function timer(seconds:Float, callback:Dynamic, loops:Int = 1):FlxTimer
    {
        return new FlxTimer().start(seconds, function(tmr:FlxTimer)
        {
            if (callback != null)
                callback(tmr);
        }, loops);
    }

    // ease is a name: linear, quadIn/Out/InOut, cubeIn/Out/InOut, sineIn/Out/InOut.
    public function tween(target:Dynamic, values:Dynamic, duration:Float, ease:String = "linear", ?onComplete:Dynamic):FlxTween
    {
        return FlxTween.tween(target, values, duration, {
            ease: getEase(ease),
            onComplete: function(twn:FlxTween)
            {
                if (onComplete != null)
                    onComplete();
            }
        });
    }

    function getEase(name:String):Float->Float
    {
        return switch (name)
        {
            case "quadIn": FlxEase.quadIn;
            case "quadOut": FlxEase.quadOut;
            case "quadInOut": FlxEase.quadInOut;
            case "cubeIn": FlxEase.cubeIn;
            case "cubeOut": FlxEase.cubeOut;
            case "cubeInOut": FlxEase.cubeInOut;
            case "sineIn": FlxEase.sineIn;
            case "sineOut": FlxEase.sineOut;
            case "sineInOut": FlxEase.sineInOut;
            default: FlxEase.linear;
        }
    }

    public var soundExt(get, never):String;

    function get_soundExt():String
    {
        return TitleState.soundExt;
    }
}