package;

import flixel.FlxGame;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.system.System;
import openfl.text.TextField;
import openfl.text.TextFormat;
import haxe.Timer;

class Main extends Sprite
{
	var memoryText:TextField;

	public function new()
	{
		super();

		addChild(new FlxGame(0, 0, TitleState));

		#if !mobile
		addChild(new FPS(10, 3, 0xFFFFFF));

		memoryText = new TextField();
		memoryText.defaultTextFormat = new TextFormat("_sans", 12, 0xFFFFFF);
		memoryText.selectable = false;
		memoryText.x = 10;
		memoryText.y = 18;
		memoryText.width = 200;
		memoryText.height = 20;

		addChild(memoryText);

		Timer.delay(updateMemory, 1000);
		#end
	}

	function updateMemory():Void
	{
		memoryText.text = 'Memory: ${Math.round(System.totalMemory / 1024 / 1024)} MB';

		Timer.delay(updateMemory, 1000);
	}
}