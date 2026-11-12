package;

import flixel.FlxSprite;
import flixel.animation.FlxBaseAnimation;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.Assets;

using StringTools;

class Character extends FlxSprite
{
	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var isPlayerCharacter:Bool = false;
	public var curCharacter:String = 'bf';
	public var isDad:Bool = false;

	public var holdTimer:Float = 0;

	// Set from the character JSON ("position" / "cameraPosition").
	// positionOffset is added to the stage slot, cameraOffset to the camera target.
	public var positionOffset:Array<Float> = [0, 0];
	public var cameraOffset:Array<Float> = [0, 0];

	public function new(
    x:Float,
    y:Float,
    ?character:String = "bf",
    ?isPlayer:Bool = false,
    ?isDad:Bool = false,
    ?data:Dynamic
	)
	{
		animOffsets = new Map<String, Array<Dynamic>>();
		super(x, y);

		curCharacter = character;
		this.isPlayer = isPlayer;
		this.isDad = isDad;
		var tex:FlxAtlasFrames;
		antialiasing = true;

		CharacterLoader.load(this, curCharacter, data);
		
		if (isPlayer)
		    flipX = !flipX;

		dance();

		var reverseDirection = (isPlayer != isPlayerCharacter);
		
		if (reverseDirection)
		{

		    swapAnimations('singLEFT', 'singRIGHT');
		    swapAnimations('singLEFTmiss', 'singRIGHTmiss');
		
		    swapAnimations('danceLeft', 'danceRight');
		}
	}

	override function update(elapsed:Float)
	{
		if (!curCharacter.startsWith('bf'))
		{
			if (animation.curAnim.name.startsWith('sing'))
			{
				holdTimer += elapsed;
			}

			var dadVar:Float = 4;

			if (curCharacter == 'dad')
				dadVar = 6.1;
			
			if (holdTimer >= Conductor.stepCrochet * dadVar * 0.001)
			{
				dance();
				holdTimer = 0;
			}
		}

		switch (curCharacter)
		{
			case 'gf':
				if (animation.curAnim.name == 'hairFall' && animation.curAnim.finished)
					playAnim('danceRight');
		}

		super.update(elapsed);
	}

	private function swapAnimations(first:String, second:String):Void
	{
    	var firstAnim = animation.getByName(first);
    	var secondAnim = animation.getByName(second);

    	if (firstAnim == null || secondAnim == null) return;

    	var oldFrames = firstAnim.frames;
    	firstAnim.frames = secondAnim.frames;
    	secondAnim.frames = oldFrames;
	}

	private var danced:Bool = false;
	public function dance():Void
	{
	    if (debugMode) return;

	    var hasDanceLeft = animation.getByName('danceLeft') != null;
	    var hasDanceRight = animation.getByName('danceRight') != null;

	    if (hasDanceLeft && hasDanceRight)
	    {
	        danced = !danced;
	        playAnim(danced ? 'danceRight' : 'danceLeft');

	        return;
	    }

	    playAnim('idle');
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		animation.play(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(animation.curAnim.name);
		if (animOffsets.exists(animation.curAnim.name))
		{
			offset.set(daOffset[0], daOffset[1]);
		}
		else
			offset.set(0, 0);

		if (curCharacter == 'gf')
		{
			if (AnimName == 'singLEFT')
			{
				danced = true;
			}
			else if (AnimName == 'singRIGHT')
			{
				danced = false;
			}

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
			{
				danced = !danced;
			}
		}
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}
}
