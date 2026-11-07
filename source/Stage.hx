package;

import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.group.FlxGroup;

class Stage
{
    public var name:String;
    public var defaultCamZoom:Float = 0.9;
    public var spritesByName:Map<String, FlxSprite> = new Map();

    public var boyfriendPosition:Array<Float> = [770, 450];
    public var dadPosition:Array<Float> = [100, 100];
    public var gfPosition:Array<Float> = [400, 130];

    public var sprites:FlxTypedGroup<FlxSprite>;

    public function new(name:String)
    {
        this.name = name;
        sprites = new FlxTypedGroup<FlxSprite>();
    }

    public function add(sprite:FlxSprite, ?spriteName:String):Void
    {
        sprites.add(sprite);

        if (spriteName != null)
            spritesByName.set(spriteName, sprite);
    }

    public function getSprite(spriteName:String):FlxSprite
    {
        return spritesByName.get(spriteName);
    }

    public function destroy():Void
    {
        sprites.destroy();
    }
}