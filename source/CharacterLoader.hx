package;

import flixel.graphics.frames.FlxAtlasFrames;

class CharacterLoader
{
    public static function load(character:Character, id:String):Void
    {
        var path = Paths.character(id);
        var rawData:String = openfl.utils.Assets.getText(path);
        var data:Dynamic = haxe.Json.parse(rawData);

        if (data.atlas.xml != null)
        {
            character.frames = FlxAtlasFrames.fromSparrow(
                data.atlas.image,
                data.atlas.xml
            );
        }
        else if (data.atlas.txt != null)
        {
            character.frames = FlxAtlasFrames.fromSpriteSheetPacker(
                data.atlas.image,
                data.atlas.txt
            );
        }

        // Load animations
        
        var animations:Array<Dynamic> = cast data.animations;

        for (anim in animations)
        {
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
}