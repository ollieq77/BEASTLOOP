
package funkin.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;

import funkin.ui.Alphabet;
import funkin.backend.MusicBeatState;
import funkin.backend.Paths;
import funkin.backend.ClientPrefs;

class OptionsMenu extends MusicBeatState
{
    var grpOptions:FlxTypedGroup<Alphabet>;

    var curSelected:Int = 0;
    var categorySelection:Int = 0;

    var currentCategory:String = "";
    var currentOptions:Array<String> = [];
    var currentSettingPrefs:Array<String> = [];

    var isInCategory:Bool = false;

	var categories:Array<String> = [
	    "GAMEPLAY",
	    "VISUALS"
	];

    // Settings registry
	var settings:Array<{name:String, category:String, pref:String}> = [
	    {name: "Botplay", category: "GAMEPLAY", pref: "botPlay"},
	    {name: "Ghost Tapping", category: "GAMEPLAY", pref: "ghostTapping"},
	    {name: "Downscroll", category: "GAMEPLAY", pref: "downscroll"},

	    {name: "Opponent Note Flashes", category: "VISUALS", pref: "opponentNoteFlashes"},
	    {name: "Vanilla Strum Offset", category: "VISUALS", pref: "vanillaStrumOffset"},
	    {name: "Sustain Clipping", category: "VISUALS", pref: "sustainClipping"},
	    {name: "Classic Score Text", category: "VISUALS", pref: "classicScoreTxt"},
	    {name: "Note Splashes", category: "VISUALS", pref: "noteSplashes"},
		{name: "Sustain Animations", category: "VISUALS", pref: "sustainAnimations"},
	];

    override function create()
    {
        super.create();

        var menuBG:FlxSprite = new FlxSprite().loadGraphic(
            Paths.graphic(Paths.image('menus/menuDesat'))
        );

        menuBG.color = 0xFFea71fd;
        menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
        menuBG.updateHitbox();
        menuBG.screenCenter();
        menuBG.antialiasing = true;
        add(menuBG);

        grpOptions = new FlxTypedGroup<Alphabet>();
        add(grpOptions);

        refreshOptions();
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (FlxG.keys.justPressed.BACKSPACE)
        {
            if (isInCategory)
            {
                isInCategory = false;
                currentCategory = "";

                curSelected = categorySelection;

                refreshOptions();
            }
            else
            {
                FlxG.switchState(new MainMenuState());
            }

            return;
        }

        if (controls.UP_P)
            changeSelection(-1);

        if (controls.DOWN_P)
            changeSelection(1);

        if (controls.ACCEPT)
            selectOption();
    }

    function refreshOptions():Void
    {
        var previousSelection:Int = curSelected;

        grpOptions.clear();
        currentOptions = [];
        currentSettingPrefs = [];

        if (!isInCategory)
        {
            currentOptions = categories.copy();
        }
        else
        {
            // Get settings belonging to this category
            for (setting in settings)
            {
                if (setting.category == currentCategory)
                {
                    currentOptions.push(setting.name);
                    currentSettingPrefs.push(setting.pref);
                }
            }

            if (currentOptions.length == 0)
            {
                currentOptions.push("Coming Soon");
                currentSettingPrefs.push("");
            }
        }

        // Restore previous selection
        if (currentOptions.length > 0)
        {
            curSelected = Std.int(Math.max(
                0,
                Math.min(previousSelection, currentOptions.length - 1)
            ));
        }
        else
        {
            curSelected = 0;
        }

        // Create menu items
        for (i in 0...currentOptions.length)
        {
            var label:String = currentOptions[i];

            if (isInCategory && currentSettingPrefs[i] != "")
            {
                label += ": " + (getSettingValue(currentSettingPrefs[i]) ? "ON" : "OFF");
            }

            var option:Alphabet = new Alphabet(
                0,
                (70 * i) + 30,
                label,
                true,
                false
            );

            option.isMenuItem = true;
            option.targetY = i;

            grpOptions.add(option);
        }

        updateSelection();
    }

    function selectOption():Void
    {
        if (currentOptions.length == 0)
            return;

        var selected:String = currentOptions[curSelected];

        if (!isInCategory)
        {
            categorySelection = curSelected;

            currentCategory = selected;
            isInCategory = true;

            refreshOptions();
            return;
        }

        var pref:String = currentSettingPrefs[curSelected];

        if (pref == "")
            return;

        toggleSetting(pref);
        refreshOptions();
    }

    function changeSelection(change:Int = 0):Void
    {
        if (grpOptions.length <= 0)
            return;

        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

        curSelected += change;

        if (curSelected < 0)
            curSelected = grpOptions.length - 1;

        if (curSelected >= grpOptions.length)
            curSelected = 0;

        updateSelection();
    }

    function updateSelection():Void
    {
        var index:Int = 0;

        for (item in grpOptions.members)
        {
            item.targetY = index - curSelected;
            item.alpha = (index == curSelected) ? 1 : 0.6;

            index++;
        }
    }

    // Read a preference dynamically
    function getSettingValue(pref:String):Bool
    {
        return Reflect.field(ClientPrefs, pref);
    }

    // Toggle a preference dynamically
    function toggleSetting(pref:String):Void
    {
        var currentValue:Bool = getSettingValue(pref);

        Reflect.setField(ClientPrefs, pref, !currentValue);

        ClientPrefs.saveSettings();
    }
}
