package;

import flixel.graphics.frames.FlxAtlasFrames;
import polymod.backends.PolymodAssets;

/**
 * Every asset path in the game should come from here.
 *
 * What these return are asset KEYS ('assets/images/foo.png'). Polymod overlays mod files on top of
 * those keys, so anything loaded through the asset library (FlxSprite.loadGraphic, FlxG.sound.play,
 * openfl.utils.Assets.getText, ...) picks mods up automatically.
 *
 * APIs that read straight from disk and skip the asset library (Sound.fromFile, File.*) need a real
 * file path instead. Wrap the key in Paths.resolve(...) for those.
 */
class Paths
{
    // ---- raw access ----

    // Real file path for a key, mod override included. Only for APIs that bypass the asset library.
    public static inline function resolve(path:String):String
        return PolymodAssets.getPath(path);

    // ---- images ----

    public static inline function image(key:String):String
        return 'assets/images/$key.png';

    public static inline function xml(key:String):String
        return 'assets/images/$key.xml';

    // Sparrow atlas where the png and xml share a key ('alphabet' -> alphabet.png + alphabet.xml).
    public static inline function sparrow(key:String):FlxAtlasFrames
        return FlxAtlasFrames.fromSparrow(image(key), xml(key));

    // ---- audio (extension follows TitleState.soundExt: .ogg on native, .mp3 on web) ----

    public static inline function sound(key:String):String
        return 'assets/sounds/$key${TitleState.soundExt}';

    public static inline function music(key:String):String
        return 'assets/music/$key${TitleState.soundExt}';

    // ---- fonts / data ----

    public static inline function font(key:String):String
        return 'assets/fonts/$key';

    public static inline function data(key:String):String
        return 'assets/data/$key';

    // ---- characters ----

    public static inline function characterDir():String
        return 'assets/data/characters/';

    public static inline function character(id:String):String
        return 'assets/data/characters/$id.json';

    // ---- stages ----

    public static inline function stageData(name:String):String
        return 'assets/data/stages/$name/stage.json';

    public static inline function stageScript(name:String):String
        return 'assets/data/stages/$name/stage.hxc';

    // Art that belongs to one stage. file includes its extension (from the stage json).
    public static inline function stageImage(stage:String, file:String):String
        return 'assets/images/stages/$stage/$file';

    // ---- songs ----

    public static inline function song(song:String):String
        return 'assets/songs/${song.toLowerCase()}/';

    public static inline function songChart(song:String, difficulty:String):String
        return Paths.song(song) + '${difficulty.toLowerCase()}.json';

    public static inline function inst(song:String):String
        return Paths.song(song) + 'Inst${TitleState.soundExt}';

    public static inline function voices(song:String):String
        return Paths.song(song) + 'Voices${TitleState.soundExt}';
}
