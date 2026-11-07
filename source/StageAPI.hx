
package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;

class StageAPI
{
    public var stage:Stage;
    public var camera:CameraAPI;

    var boyfriend:Boyfriend;
    var dad:Character;
    var gf:Character;

    public function new(stage:Stage)
    {
        this.stage = stage;
    }

    public function setCharacters(
        boyfriend:Boyfriend,
        dad:Character,
        gf:Character
    ):Void
    {
        this.boyfriend = boyfriend;
        this.dad = dad;
        this.gf = gf;
    }

    // Characters

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

    // Stage sprites

    public function getSprite(name:String):FlxSprite
    {
        return stage.getSprite(name);
    }

    // Randomness

    public function randomInt(min:Int, max:Int):Int
    {
        return FlxG.random.int(min, max);
    }

    public function randomBool(chance:Float):Bool
    {
        return FlxG.random.bool(chance);
    }

    // Audio

    public function playSound(path:String, volume:Float = 1):Void
    {
        FlxG.sound.play(path, volume);
    }

    public var soundExt(get, never):String;

    function get_soundExt():String
    {
        return TitleState.soundExt;
    }
}
