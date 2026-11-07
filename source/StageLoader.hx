package;

import flixel.FlxSprite;
import lime.utils.Assets;
import haxe.Json;
import flixel.graphics.frames.FlxAtlasFrames;

class StageLoader
{
    public static function load(stageName:String):Stage
    {
        if (stageName == null || stageName.length == 0)
            stageName = 'stage';

        var jsonPath = 'assets/data/stages/$stageName/stage.json';

        if (!Assets.exists(jsonPath))
        {
            stageName = 'stage';
            jsonPath = 'assets/data/stages/stage/stage.json';
        }

        var data:Dynamic = Json.parse(Assets.getText(jsonPath));
        var stage = new Stage(stageName);

        // Stage settings
        stage.defaultCamZoom = data.defaultCamZoom;

        // Character positions
        stage.boyfriendPosition = [
            data.characters.boyfriend.x,
            data.characters.boyfriend.y
        ];
        
        stage.dadPosition = [
            data.characters.dad.x,
            data.characters.dad.y
        ];
        
        stage.gfPosition = [
            data.characters.gf.x,
            data.characters.gf.y
        ];

        // Stage sprites
        var sprites:Array<Dynamic> = cast data.sprites;

        for (spriteData in sprites)
        {
            var sprite = new FlxSprite(
                spriteData.position[0],
                spriteData.position[1]
            );
            
            var imagePath = 'assets/images/stages/$stageName/${spriteData.image}';
            
            if (spriteData.type == "sparrow")
            {
                var xmlPath = 'assets/images/stages/$stageName/${spriteData.xml}';
            
                sprite.frames = FlxAtlasFrames.fromSparrow(imagePath, xmlPath);
            
                var animations:Array<Dynamic> = cast spriteData.animations;
                            
                for (anim in animations)
                {
                    var fps:Int = anim.fps == null ? 24 : anim.fps;
                    var loop:Bool = anim.loop == null ? true : anim.loop;
                
                    sprite.animation.addByPrefix(
                        anim.name,
                        anim.prefix,
                        fps,
                        loop
                    );
                }
            
                if (spriteData.initialAnimation != null)
                    sprite.animation.play(spriteData.initialAnimation);
            }
            else
            {
                sprite.loadGraphic(imagePath);
            }
        
            if (spriteData.scale != null)
            {
                sprite.setGraphicSize(
                    Std.int(sprite.width * spriteData.scale[0]),
                    Std.int(sprite.height * spriteData.scale[1])
                );
                
                sprite.updateHitbox();
            }
        
            sprite.antialiasing = spriteData.antialiasing;
        
            sprite.scrollFactor.set(
                spriteData.scrollFactor[0],
                spriteData.scrollFactor[1]
            );
            
            sprite.active = spriteData.active;
            
            stage.add(sprite, spriteData.name);
        }


        return stage;
    }
}