package;

import flixel.graphics.frames.FlxAtlasFrames;
import polymod.backends.PolymodAssets;
import funkin.backend.Paths;

class CharacterLoader
{
    public static function load(character:Character, id:String, ?data:Dynamic):Void
    {
        if (data == null)
        {
            var path = Paths.character(id);
            var rawData:String = PolymodAssets.getText(path);
            data = haxe.Json.parse(rawData);
        }
    
        // Paths.sparrowFrom / packerFrom, not FlxAtlasFrames directly: they also find images and atlases
        // that only exist in a mod.
        if (data.atlas.xml != null)
        {
            character.frames = Paths.sparrowFrom(data.atlas.image, data.atlas.xml);
        }
        else if (data.atlas.txt != null)
        {
            character.frames = Paths.packerFrom(data.atlas.image, data.atlas.txt);
        }
        else if (data.atlas.image != null)
        {
            // Neither xml nor txt listed: the xml sits next to the png with the same name.
            var img:String = data.atlas.image;
            var xmlPath:String = StringTools.endsWith(img, ".png") ? img.substr(0, img.length - 4) + ".xml" : img + ".xml";

            character.frames = Paths.sparrowFrom(img, xmlPath);
        }

        // Load animations
        
        var animations:Array<Dynamic> = cast(data.animations, Array<Dynamic>);

        for (anim in animations)
        {
            addAnimation(character, anim);
        }

        // Load position offsets
        if (data.position != null)
            character.positionOffset = [data.position[0], data.position[1]];

        if (data.cameraPosition != null)
            character.cameraOffset = [data.cameraPosition[0], data.cameraPosition[1]];

        // Load display properties
        if (data.display != null)
        {
            if (data.display.antialiasing != null)
                character.antialiasing = data.display.antialiasing;
        
            if (data.display.flipX != null)
                character.flipX = data.display.flipX;
        
            if (data.display.scale != null)
            {
                character.setGraphicSize(
                    Std.int(character.width * data.display.scale)
                );
                character.updateHitbox();
            }
        }

        // Load behaviour properties
        if (data.behaviour != null)
        {
            if (data.behaviour.isPlayerCharacter != null)
                character.isPlayerCharacter = data.behaviour.isPlayerCharacter;
        }
    }

    /**
     * Every character id the game can load: the assets folder plus every enabled mod.
     *
     * PolymodAssets.list() is inconsistent about prefixes: files that exist in assets/ come back as
     * 'assets/data/characters/bf.json', but files that only exist in a mod come back relative to the
     * mod folder as 'data/characters/foo.json' (no 'assets/'). Filtering for the assets/ prefix alone
     * hides every mod-only character, so accept both. Loading by id is fine either way because
     * PolymodAssets.getText(Paths.character(id)) strips the prefix itself.
     */
    public static function listIds():Array<String>
    {
        var ids:Array<String> = [];
        var withPrefix:String = Paths.characterDir();
        var noPrefix:String = withPrefix.substr("assets/".length);

        for (path in PolymodAssets.list())
        {
            var dir:String = null;

            if (StringTools.startsWith(path, withPrefix))
                dir = withPrefix;
            else if (StringTools.startsWith(path, noPrefix))
                dir = noPrefix;

            if (dir == null || !StringTools.endsWith(path, ".json"))
                continue;

            var id:String = path.substr(dir.length, path.length - dir.length - 5);

            // An id can show up twice (assets copy + a mod's overlay of it), list it once.
            if (id != "" && ids.indexOf(id) == -1)
                ids.push(id);
        }

        return ids;
    }

    /**
     * Registers (or re-registers) one animation entry from the character JSON on `character`.
     * Used by load() and by the character editor so both go through the exact same code.
     * Returns false if the prefix/indices matched no frames in the atlas (the old animation
     * with this name, if any, is left untouched in that case).
     */
    public static function addAnimation(character:Character, anim:Dynamic):Bool
    {
        var before = character.animation.getByName(anim.name);

        if (anim.type == "indices")
        {
            var frames:Array<Int> = cast anim.frames;

            character.animation.addByIndices(anim.name, anim.prefix, frames, "", anim.fps, anim.loop);
        }
        else
        {
            character.animation.addByPrefix(anim.name, anim.prefix, anim.fps, anim.loop);
        }

        character.addOffset(anim.name, anim.offset[0], anim.offset[1]);

        // Flixel builds a brand new FlxAnimation on success and does nothing on failure
        var after = character.animation.getByName(anim.name);
        return after != null && after != before;
    }
}