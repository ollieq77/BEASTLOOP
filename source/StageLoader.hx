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
        stage.defaultCamZoom = data.defaultCamZoom == null ? 1.0 : data.defaultCamZoom;

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

        // Camera offsets (optional)
        if (data.camera != null)
        {
            if (data.camera.boyfriend != null)
                stage.cameraBoyfriend = [data.camera.boyfriend[0], data.camera.boyfriend[1]];

            if (data.camera.opponent != null)
                stage.cameraOpponent = [data.camera.opponent[0], data.camera.opponent[1]];
        }

        // Stage sprites
        var sprites:Array<Dynamic> = cast data.sprites;

        for (spriteData in sprites)
        {
            try {
            var sprite = new FlxSprite(
                spriteData.position[0],
                spriteData.position[1]
            );
            
            var imagePath = 'assets/images/stages/$stageName/${spriteData.image}';

            if (spriteData.type == "sparrow")
            {
                var xmlPath = 'assets/images/stages/$stageName/${spriteData.xml}';
                sprite.frames = FlxAtlasFrames.fromSparrow(imagePath, xmlPath);
            
                if (spriteData.animations != null)
                {
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
                }
            }
            else if (spriteData.type == "packer")
            {
                var txtPath = 'assets/images/stages/$stageName/${spriteData.xml}';
                sprite.frames = FlxAtlasFrames.fromSpriteSheetPacker(imagePath, txtPath);
            
                if (spriteData.animations != null)
                {
                    var animations:Array<Dynamic> = cast spriteData.animations;
                
                    for (anim in animations)
                    {
                        var fps:Int = anim.fps == null ? 24 : anim.fps;
                        var loop:Bool = anim.loop == null ? true : anim.loop;
                    
                        var frames:Array<Int> = cast anim.frames;
                    
                        sprite.animation.add(
                            anim.name,
                            frames,
                            fps,
                            loop
                        );
                    }
                }
            }
            else
            {
                sprite.loadGraphic(imagePath);
            }

            if (spriteData.initialAnimation != null)
                sprite.animation.play(spriteData.initialAnimation);

            // Scaling
            if (spriteData.scale != null)
            {
                sprite.setGraphicSize(
                    Std.int(sprite.width * spriteData.scale[0]),
                    Std.int(sprite.height * spriteData.scale[1])
                );
                
                sprite.updateHitbox();
            }

            if (spriteData.matchWidth != null)
            {
                var target = stage.getSprite(spriteData.matchWidth);
            
                if (target != null)
                {
                    var multiplier:Float = spriteData.matchWidthScale == null
                        ? 1
                        : spriteData.matchWidthScale;
                
                    sprite.setGraphicSize(
                        Std.int(target.width * multiplier)
                    );
                    
                    sprite.updateHitbox();
                }
            }
        
            // Optional sprite properties
            var antialiasing:Bool = spriteData.antialiasing == null
                ? false
                : spriteData.antialiasing;

            sprite.antialiasing = antialiasing;

            var scrollX:Float = spriteData.scrollFactor == null ? 1 : spriteData.scrollFactor[0];
            var scrollY:Float = spriteData.scrollFactor == null ? 1 : spriteData.scrollFactor[1];

            sprite.visible = spriteData.visible == null
                ? true
                : spriteData.visible;

            sprite.scrollFactor.set(scrollX, scrollY);

            sprite.active = spriteData.active == null ? true : spriteData.active;
            
            stage.add(sprite, spriteData.name);
        }
        catch (e:Dynamic) {
            trace('[StageLoader] Failed sprite "${spriteData.name}" in $stageName: $e');
        }
    }


        return stage;
    }
}