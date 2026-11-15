package;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.io.Bytes;
import lime.graphics.Image;
import openfl.display.BitmapData;
import openfl.utils.AssetType;
import openfl.utils.Assets;
import polymod.backends.PolymodAssets;

/**
 * Every asset path in the game should come from here.
 *
 * What these return are asset KEYS ('assets/images/foo.png'). Polymod overlays mod files on top of
 * those keys, so anything loaded through the asset library (FlxSprite.loadGraphic, FlxG.sound.play,
 * openfl.utils.PolymodAssets.getText, ...) picks mods up automatically.
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

    // Health bar icon: images/icons/icon-<name>.png, two 150px frames side by side (normal, losing), like Psych.
    public static inline function icon(name:String):String
        return image('icons/icon-$name');

    // Sparrow atlas where the png and xml share a key ('alphabet' -> alphabet.png + alphabet.xml).
    public static function sparrow(key:String):FlxAtlasFrames
        return sparrowFrom(image(key), xml(key));

    // ---- mod-safe image / atlas loading ----
    //
    // Why these exist: Polymod's TYPED lookup (Assets.exists(key, IMAGE), which FlxG.bitmap.add(key) and
    // loadGraphic(key) both go through) looks mod files up under the full 'assets/...' id, but it indexes
    // them without the 'assets/' prefix, so it misses them. A png/xml that exists ONLY in a mod then fails with
    // "There is no IMAGE asset with an ID of 'assets/images/...'". Mod overlays of files that also exist in
    // assets/ work by accident, because the assets copy answers the lookup. UNTYPED lookups (getBytes, getText)
    // find both, so everything below goes through those.

    // Graphic for an image key, mod-only images included. null if it can't be found.
    public static function graphic(key:String):FlxGraphic
    {
        var cached:FlxGraphic = FlxG.bitmap.get(key);

        if (cached != null)
            return cached;

        // assets/ files and mod overlays of them: the normal route, unchanged.
        if (Assets.exists(key, AssetType.IMAGE))
            return FlxG.bitmap.add(key);

        // Mod-only file: decode it the same way Polymod's own library does, and cache it under the asset key so
        // later FlxG.bitmap.add(key) / loadGraphic(key) calls for it hit the cache.
        // getBytes can THROW for a key that exists nowhere (the base library tries to read a null path), so a
        // missing file has to come out as null here, not as an exception.
        var bytes:Bytes = null;

        try
        {
            bytes = PolymodAssets.getBytes(key);
        }
        catch (e:Dynamic)
        {
            bytes = null;
        }

        if (bytes == null)
            return null;

        var img:Image = Image.fromBytes(bytes);

        if (img == null)
            return null;

        return FlxG.bitmap.add(BitmapData.fromImage(img), false, key);
    }

    // Sparrow atlas from an image key + an xml key. Either may live only in a mod. Throws (with the key) if one is missing.
    public static function sparrowFrom(imageKey:String, xmlKey:String):FlxAtlasFrames
    {
        var g:FlxGraphic = graphic(imageKey);

        if (g == null)
            throw 'image not found: $imageKey';

        // Hand flixel the xml TEXT, not the path: it only treats the description as a path if Assets.exists()
        // says so, which has the same mod-only blind spot as above.
        var text:String = PolymodAssets.getText(xmlKey);

        if (text == null)
            throw 'atlas xml not found: $xmlKey';

        return FlxAtlasFrames.fromSparrow(g, text);
    }

    // Same as sparrowFrom, for SpriteSheetPacker .txt atlases.
    public static function packerFrom(imageKey:String, txtKey:String):FlxAtlasFrames
    {
        var g:FlxGraphic = graphic(imageKey);

        if (g == null)
            throw 'image not found: $imageKey';

        var text:String = PolymodAssets.getText(txtKey);

        if (text == null)
            throw 'atlas txt not found: $txtKey';

        return FlxAtlasFrames.fromSpriteSheetPacker(g, text);
    }

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

    // Optional per-song script. Same API as a stage script.
    public static inline function songScript(song:String):String
        return 'songs/${song.toLowerCase()}/song.hxc';

    public static inline function week(id:String):String
        return Paths.data('weeks/$id.json');
}
