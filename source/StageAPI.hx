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

    /**
     * Initializes the StageAPI instance with the active stage reference.
     * @param stage The active Stage instance being managed.
     */
    public function new(stage:Stage)
    {
        this.stage = stage;
    }

    /**
     * Assigns the main character instances (Boyfriend, Opponent, and Girlfriend) to the API.
     * @param boyfriend The player character instance.
     * @param dad The opponent character instance.
     * @param gf The girlfriend character instance.
     */
    public function setCharacters(boyfriend:Boyfriend, dad:Character, gf:Character):Void
    {
        this.boyfriend = boyfriend;
        this.dad = dad;
        this.gf = gf;
    }

    /**
     * Retrieves a specific character instance by their string identifier name (case-insensitive).
     * @param name The string name of the character ("boyfriend", "dad", or "gf").
     */
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

    /**
     * Sets up the game and HUD cameras, initializing the internal CameraAPI wrapper.
     * @param game The main gameplay FlxCamera instance.
     * @param hud The user interface / HUD FlxCamera instance.
     */
    public function setCameras(game:FlxCamera, hud:FlxCamera):Void
    {
        camera = new CameraAPI(game, hud);
    }

    /**
     * Gets a specific FlxSprite from the stage by its name.
     * @param name The string identifier of the sprite.
     */
    public function getSprite(name:String):FlxSprite
    {
        return stage.getSprite(name);
    }

    /**
     * Gets a generic FlxBasic object from the stage by its name.
     * @param name The string identifier of the object.
     */
    public function getObject(name:String):FlxBasic
    {
        return stage.getObject(name);
    }

    /**
     * Adds a basic object to the stage with an assigned name identifier.
     * @param object The FlxBasic object instance to add.
     * @param name The string identifier key for the object.
     */
    public function addObject(object:FlxBasic, name:String):Void
    {
        stage.addObject(object, name);
    }

    /**
     * Returns a random integer between min and max (inclusive).
     * @param min The minimum integer bound.
     * @param max The maximum integer bound.
     */
    public function randomInt(min:Int, max:Int):Int
    {
        return FlxG.random.int(min, max);
    }

    /**
     * Returns true or false based on a given percentage chance (0 to 100).
     * @param chance The success probability percentage (0 to 100).
     */
    public function randomBool(chance:Float):Bool
    {
        return FlxG.random.bool(chance);
    }

    /**
     * Sets the dancing/animation speed multiplier for Girlfriend.
     * @param value The speed factor integer.
     */
    public function setGfSpeed(value:Int):Void
    {
        if (setGfSpeedFn != null)
            setGfSpeedFn(value);
    }

    /**
     * Adjusts the volume level of the song vocals dynamically.
     * @param value The target volume level (0.0 to 1.0).
     */
    public function setVocalsVolume(value:Float):Void
    {
        if (setVocalsVolumeFn != null)
            setVocalsVolumeFn(value);
    }

    /**
     * Adjusts the volume level of the instrumental music track dynamically.
     * @param value The target volume level (0.0 to 1.0).
     */
    public function setMusicVolume(value:Float):Void
    {
        if (setMusicVolumeFn != null)
            setMusicVolumeFn(value);
    }

    /**
     * Enables or disables automatic camera zooming on beat hits.
     * @param value True to enable beat zooming, false to disable.
     */
    public function setCamZooming(value:Bool):Void
    {
        if (setCamZoomingFn != null)
            setCamZoomingFn(value);
    }

    /**
     * Adds an instant zoom offset to both the game and HUD cameras.
     * @param game The zoom value modifier for the game camera.
     * @param hud The zoom value modifier for the HUD camera.
     */
    public function addCameraZoom(game:Float, hud:Float):Void
    {
        if (addCameraZoomFn != null)
            addCameraZoomFn(game, hud);
    }

    public var camZooming(get, never):Bool;

    /**
     * Getter for the current camera zooming status (whether zoom on beat is active).
     */
    function get_camZooming():Bool
    {
        return getCamZoomingFn != null ? getCamZoomingFn() : false;
    }

    /**
     * Loads a dialogue script/file into the game state.
     * @param file The filename or path of the dialogue asset.
     */
    public function loadDialogue(file:String):Void
    {
        if (loadDialogueFn != null)
            loadDialogueFn(file);
    }
    
    /**
     * Plays a sound effect through the sound manager.
     * @param key A sound name like 'carPass0' (resolved through Paths.sound) or a full path.
     * @param volume The playback volume level, default is 1.0.
     * @param onComplete Optional callback function triggered when the sound finishes playing.
     */
    public function playSound(key:String, volume:Float = 1, ?onComplete:Dynamic):Void
    {
        var done:Void->Void = null;

        if (onComplete != null)
            done = function() onComplete();

        FlxG.sound.play(soundPath(key), volume, false, null, true, done);
    }

    /**
     * Starts a music track and fades it in.
     * @param key The music track name like 'Lunchbox', resolved through Paths.music.
     * @param volume The target playback volume level.
     * @param fadeInSeconds Duration in seconds for the music to fade in (0 for instant).
     */
    public function playMusic(key:String, volume:Float = 1, fadeInSeconds:Float = 0):Void
    {
        FlxG.sound.playMusic(Paths.music(key), fadeInSeconds > 0 ? 0 : volume);

        if (fadeInSeconds > 0)
            FlxG.sound.music.fadeIn(fadeInSeconds, 0, volume);
    }

    /**
     * Resolves the full path for a sound key, for scripts that need to load one themselves.
     * @param key The sound name or full asset path.
     */
    public function soundPath(key:String):String
    {
        return StringTools.startsWith(key, 'assets/') ? key : Paths.sound(key);
    }

    /**
     * Resolves the path for an image key (e.g., 'weeb/senpaiCrazy' with no extension).
     * @param key The image asset key.
     */
    public function imagePath(key:String):String
    {
        return Paths.image(key);
    }

    // ---- State access (draws above the stage and the characters) ----

    /**
     * Adds a custom object directly to the active PlayState so it renders above characters and stage elements.
     * @param object The FlxBasic object instance to add to the state.
     */
    public function addToState(object:FlxBasic):Void
    {
        if (state != null)
            state.add(object);
    }

    /**
     * Removes an object from the active PlayState.
     * @param object The FlxBasic object instance to remove from the state.
     */
    public function removeFromState(object:FlxBasic):Void
    {
        if (state != null)
            state.remove(object);
    }

    // ---- Intro / cutscene control ----

    /**
     * Triggers the gameplay countdown sequence to begin.
     */
    public function startCountdown():Void
    {
        if (startCountdownFn != null)
            startCountdownFn();
    }

    /**
     * Sets whether the game is currently in a cutscene state (disabling inputs/gameplay elements).
     * @param value True to enter cutscene mode, false to exit.
     */
    public function setInCutscene(value:Bool):Void
    {
        if (setCutsceneFn != null)
            setCutsceneFn(value);
    }

    // ---- Helpers so scripts don't need FlxColor / FlxEase / FlxTimer ----

    /**
     * Creates a solid colour rectangle sprite.
     * @param x The X position coordinate.
     * @param y The Y position coordinate.
     * @param width The pixel width of the rectangle.
     * @param height The pixel height of the rectangle.
     * @param color The color hex value (formatted as 0xAARRGGBB).
     */
    public function makeSolid(x:Float, y:Float, width:Int, height:Int, color:Int):FlxSprite
    {
        return new FlxSprite(x, y).makeGraphic(width, height, color);
    }

    /**
     * Creates a sprite with a single image loaded from assets/images.
     * @param x The X position coordinate.
     * @param y The Y position coordinate.
     * @param key The image name under assets/images, e.g. 'weeb/spiritFaceForward'.
     */
    public function makeImage(x:Float, y:Float, key:String):FlxSprite
    {
        return new FlxSprite(x, y).loadGraphic(Paths.image(key));
    }

    /**
     * Creates a sprite with a Sparrow sprite sheet atlas loaded.
     * @param x The X position coordinate.
     * @param y The Y position coordinate.
     * @param key The shared png/xml asset name under assets/images, e.g. 'weeb/senpaiCrazy'.
     */
    public function makeSparrow(x:Float, y:Float, key:String):FlxSprite
    {
        var sprite = new FlxSprite(x, y);
        sprite.frames = Paths.sparrow(key);
        return sprite;
    }

    /**
     * Starts a timer with a callback function. The callback receives the FlxTimer so it can call tmr.reset(...).
     * @param seconds Duration of the timer in seconds.
     * @param callback Function called when the timer fires or loops.
     * @param loops Number of times the timer should repeat (defaults to 1).
     */
    public function timer(seconds:Float, callback:Dynamic, loops:Int = 1):FlxTimer
    {
        return new FlxTimer().start(seconds, function(tmr:FlxTimer)
        {
            if (callback != null)
                callback(tmr);
        }, loops);
    }

    /**
     * Creates a property tween animation.
     * @param target The object or structure being tweened.
     * @param values An anonymous object containing target properties and end values.
     * @param duration Duration of the tween in seconds.
     * @param ease The easing function name (e.g., linear, quadIn/Out, cubeIn/Out, sineIn/Out).
     * @param onComplete Optional callback function triggered when the tween finishes.
     */
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

    /**
     * Resolves a string ease name into its corresponding FlxEase function reference.
     * @param name The string identifier name of the ease function.
     */
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

    /**
     * Getter that returns the audio file extension format used by the title state/game settings.
     */
    function get_soundExt():String
    {
        return TitleState.soundExt;
    }
}