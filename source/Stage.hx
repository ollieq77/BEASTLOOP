package;

import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.group.FlxGroup;

class Stage
{
    public var name:String;
    public var defaultCamZoom:Float = 0.9;

    public var spritesByName:Map<String, FlxSprite> = new Map();
    public var objectsByName:Map<String, FlxBasic> = new Map();

    public var boyfriendPosition:Array<Float> = [770, 450];
    public var dadPosition:Array<Float> = [100, 100];
    public var gfPosition:Array<Float> = [400, 130];

    // Holds every stage object, not just sprites.
    public var members:FlxGroup;

    public function new(name:String)
    {
        this.name = name;
        members = new FlxGroup();
    }

    public function add(sprite:FlxSprite, ?spriteName:String):Void
    {
        members.add(sprite);

        if (spriteName != null)
        {
            spritesByName.set(spriteName, sprite);
            objectsByName.set(spriteName, sprite);
        }
    }

    public function addObject(object:FlxBasic, ?objectName:String):Void
    {
        members.add(object);

        if (objectName != null)
            objectsByName.set(objectName, object);
    }

    public function getSprite(spriteName:String):FlxSprite
    {
        return spritesByName.get(spriteName);
    }

    public function getObject(objectName:String):FlxBasic
    {
        return objectsByName.get(objectName);
    }

    public function destroy():Void
    {
        members.destroy();

        spritesByName.clear();
        objectsByName.clear();
    }
}