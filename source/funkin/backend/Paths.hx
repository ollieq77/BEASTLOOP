package funkin.backend;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.system.FlxAssets.FlxSoundAsset;
import haxe.io.Bytes;
import lime.graphics.Image;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.utils.AssetType;
import openfl.utils.Assets;
import polymod.backends.PolymodAssets;
import TitleState;

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

    static var sparrowCache:Map<String, FlxAtlasFrames> = new Map();
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

    // ---- existence / listing that can see mod-only files ----
    //
    // Do NOT use PolymodAssets.exists(key) for 'assets/...' keys. It runs Polymod's typed check, which looks
    // the file up under the wrong id and says no, then falls back to "is it in the base assets/ folder?". So
    // it is right for files in assets/ and wrong for any file that exists only in a mod (a mod's stage.json,
    // stage.hxc, song.hxc, chart...). getPath is untyped and finds both, so existence goes through it.

    public static function exists(key:String):Bool
    {
        try
        {
            var path:String = PolymodAssets.getPath(key);

            if (path != null && path != "")
                return true;

            // Assets baked into the exe (embed="true") have no file path.
            return Assets.exists(key);
        }
        catch (e:Dynamic)
        {
            return false;
        }
    }

    // Every file under an asset directory, as full keys ('assets/data/stages/x/stage.json'), mods included.
    // PolymodAssets.list() returns files from assets/ WITH the 'assets/' prefix but mod-only files WITHOUT it,
    // so a plain startsWith('assets/...') filter silently drops everything that only exists in a mod.
    // Each key comes back once, even when a mod overlays a file that is also in assets/.
    public static function listDir(dir:String):Array<String>
    {
        var prefix:String = 'assets/';
        var bare:String = StringTools.startsWith(dir, prefix) ? dir.substr(prefix.length) : dir;
        var out:Array<String> = [];

        for (path in PolymodAssets.list())
        {
            var full:String = null;

            if (StringTools.startsWith(path, prefix + bare))
                full = path;
            else if (StringTools.startsWith(path, bare))
                full = prefix + path;

            if (full != null && out.indexOf(full) == -1)
                out.push(full);
        }

        return out;
    }

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
        var cacheKey:String = imageKey + "|" + xmlKey;
    
        if (sparrowCache.exists(cacheKey))
            return sparrowCache.get(cacheKey);
    
        var g:FlxGraphic = graphic(imageKey);
    
        if (g == null)
            throw 'image not found: $imageKey';

        g.persist = true;
    
        // Hand flixel the xml TEXT, not the path.
        var text:String = PolymodAssets.getText(xmlKey);
    
        if (text == null)
            throw 'atlas xml not found: $xmlKey';
    
        var frames:FlxAtlasFrames = FlxAtlasFrames.fromSparrow(g, text);
    
        sparrowCache.set(cacheKey, frames);
    
        return frames;
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
    //
    // Same story as images: FlxG.sound.play(key) goes through Assets.getSound, which is a TYPED lookup, so a
    // sound that exists ONLY in a mod fails. These return a FlxSoundAsset instead of a bare String: the key
    // itself for anything the normal route can find (assets/ files and mod overlays of them, unchanged), or a
    // ready-made Sound for a mod-only file. Every FlxG.sound.play / playMusic / load / loadEmbedded accepts
    // either, so call sites don't change.

    // Mod-only sounds already decoded, so a sound that plays over and over (missnote, scrollMenu) is only read once.
    static var modSounds:Map<String, Sound> = new Map();

    public static function sound(key:String):FlxSoundAsset
        return audio('assets/sounds/$key${TitleState.soundExt}');

    public static function music(key:String):FlxSoundAsset
        return audio('assets/music/$key${TitleState.soundExt}');

    // Audio for a full asset key ('assets/sounds/foo.ogg'), mod-only files included.
    public static function audio(key:String):FlxSoundAsset
    {
        // assets/ files and mod overlays of them: the normal route.
        if (Assets.exists(key, AssetType.SOUND))
            return key;

        var cached:Sound = modSounds.get(key);

        if (cached != null)
            return cached;

        // getPath is untyped, so it finds mod-only files. Can throw for odd keys, so a miss has to come out as "".
        var path:String = null;

        try
        {
            path = PolymodAssets.getPath(key);
        }
        catch (e:Dynamic)
        {
            path = null;
        }

        // Not found anywhere: hand flixel the key like before, so it reports the missing file the same way.
        if (path == null || path == "")
            return key;

        var snd:Sound = Sound.fromFile(path);

        if (snd == null)
            return key;

        modSounds.set(key, snd);
        return snd;
    }

    // ---- fonts / data ----

    // Font for FlxText.setFormat / .font ('vcr.ttf').
    //
    // FlxText only runs Assets.getFont (a TYPED lookup, same mod-only blind spot as images and sounds) when
    // Assets.exists(font, FONT) says yes. Otherwise it uses the string as a literal font NAME, and openfl's
    // TextEngine.findFont (native) falls back to Font.fromFile(name), i.e. it treats the name as a file path on
    // disk, loads it and keeps it registered. So a mod-only font just needs its REAL file path handed over.
    public static function font(key:String):String
    {
        var full:String = 'assets/fonts/$key';

        // assets/ fonts and mod overlays of them: the normal route, unchanged.
        if (Assets.exists(full, AssetType.FONT))
            return full;

        // getPath is untyped, so it finds mod-only files. Can throw for odd keys, so a miss has to come out as "".
        var path:String = null;

        try
        {
            path = PolymodAssets.getPath(full);
        }
        catch (e:Dynamic)
        {
            path = null;
        }

        // Not found anywhere: same string as before, so it fails the same way it always did.
        if (path == null || path == "")
            return full;

        return path;
    }

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
        return Paths.song(song) + 'song.hxc';

    public static inline function week(id:String):String
        return Paths.data('weeks/$id.json');
}
