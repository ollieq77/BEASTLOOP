
package;

import flixel.FlxGame;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.UncaughtErrorEvent;
import openfl.system.System;
import openfl.text.TextField;
import openfl.text.TextFormat;
import haxe.Timer;
import funkin.backend.CrashHandler;
import funkin.menus.TitleState;

import flixel.FlxG;
import funkin.backend.ClientPrefs;

class Main extends Sprite
{
    var memoryText:TextField;

    public function new()
    {
        super();

        FlxG.save.bind('beastloop', 'ollz');
        ClientPrefs.loadPrefs();

        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);

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

    function onAddedToStage(event:Event):Void
    {
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);

        loaderInfo.uncaughtErrorEvents.addEventListener(
            UncaughtErrorEvent.UNCAUGHT_ERROR,
            onUncaughtError
        );
    }

	function onUncaughtError(event:UncaughtErrorEvent):Void
	{
	    CrashHandler.handle(event.error);
	    event.preventDefault();
	}
    function updateMemory():Void
    {
        memoryText.text = 'Memory: ${Math.round(System.totalMemory / 1024 / 1024)} MB';

        Timer.delay(updateMemory, 1000);
    }
}
