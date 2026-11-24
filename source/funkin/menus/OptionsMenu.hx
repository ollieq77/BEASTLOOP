package funkin.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;

import funkin.ui.Alphabet;
import funkin.backend.MusicBeatState;
import funkin.backend.Paths;
import funkin.backend.ClientPrefs;
import funkin.options.Option;
import funkin.options.CheckboxIcon;

class OptionsMenu extends MusicBeatState
{
    static inline var EXTRA_GAP:Float = 15; // space between label and checkbox / value
    static inline var CHECK_Y:Float = -15;   // nudge checkbox vertically against the label
    static inline var HOLD_DELAY:Float = 0.4;
    static inline var HOLD_RATE:Float = 0.05;

    var grpOptions:FlxTypedGroup<Alphabet>; // the labels (these scroll)
    var grpExtras:FlxGroup;                 // checkboxes + value labels, follow their label

    var checks:Array<CheckboxIcon> = [];    // index-aligned with grpOptions, null if not a bool
    var values:Array<Alphabet> = [];        // index-aligned with grpOptions, null if bool / category

    var descBG:FlxSprite;
    var descText:FlxText;

    var curSelected:Int = 0;
    var categorySelection:Int = 0;

    var currentCategory:String = "";
    var curOptions:Array<Option> = [];
    var isInCategory:Bool = false;

    var holdTime:Float = 0;
    var holdTick:Float = 0;

    var categories:Array<String> = [
        "GAMEPLAY",
        "VISUALS"
    ];

    var allOptions:Array<Option> = [];
    var optionCategory:Map<Option, String> = new Map();

    function register(category:String, option:Option):Void
    {
        allOptions.push(option);
        optionCategory.set(option, category);
    }

    function registerOptions():Void
    {
        register("GAMEPLAY", new Option("Botplay", "botPlay"));
        register("GAMEPLAY", new Option("Ghost Tapping", "ghostTapping"));
        register("GAMEPLAY", new Option("Downscroll", "downscroll"));

        register("VISUALS", new Option("Opponent Note Flashes", "opponentNoteFlashes"));
        register("VISUALS", new Option("Vanilla Strum Offset", "vanillaStrumOffset"));
        register("VISUALS", new Option("Sustain Clipping", "sustainClipping"));
        register("VISUALS", new Option("Classic Score Text", "classicScoreTxt"));
        register("VISUALS", new Option("Note Splashes", "noteSplashes"));
        register("VISUALS", new Option("Sustain Animations", "sustainAnimations"));

        // Other types (each variable needs a static field in ClientPrefs + load/save lines):
        //
        // var fps = new Option("Framerate", "framerate", INT, null, "Higher = smoother");
        // fps.minValue = 60; fps.maxValue = 240; fps.changeValue = 1;
        // register("VISUALS", fps);
        //
        // var vol = new Option("Hitsound Volume", "hitsoundVolume", PERCENT);
        // register("GAMEPLAY", vol);
        //
        // register("VISUALS", new Option("Note Skin", "noteSkin", STRING, ["Default", "Circles"]));
    }

    override function create()
    {
        super.create();

        registerOptions();

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

        grpExtras = new FlxGroup();
        add(grpExtras);

        descBG = new FlxSprite(0, FlxG.height - 70).makeGraphic(FlxG.width, 70, 0xFF000000);
        descBG.alpha = 0.6;
        descBG.visible = false;
        add(descBG);

        descText = new FlxText(20, FlxG.height - 55, FlxG.width - 40, "", 28);
        descText.alignment = CENTER;
        add(descText);

        buildRows();
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
                buildRows();
            }
            else
            {
                ClientPrefs.saveSettings();
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

        if (isInCategory)
            handleValueInput(elapsed);

        placeAllExtras();
    }

    // Left / right on non-bool options. Press = one step, hold = repeats after a short delay.
    function handleValueInput(elapsed:Float):Void
    {
        if (curOptions.length == 0)
            return;

        var option:Option = curOptions[curSelected];
        if (option.type == BOOL)
            return;

        var dir:Int = 0;

        if (controls.LEFT_P)
            dir = -1;
        else if (controls.RIGHT_P)
            dir = 1;

        if (dir != 0)
        {
            holdTime = 0;
            holdTick = 0;
            changeValue(dir);
        }
        else if (controls.LEFT || controls.RIGHT)
        {
            holdTime += elapsed;

            if (holdTime > HOLD_DELAY)
            {
                holdTick += elapsed;

                if (holdTick >= HOLD_RATE)
                {
                    holdTick = 0;
                    changeValue(controls.LEFT ? -1 : 1);
                }
            }
        }
        else
        {
            holdTime = 0;
            holdTick = 0;
        }
    }

    // Only called when the category changes. Toggling an option never comes through here,
    // so the list doesn't get torn down and rebuilt (that was the jitter).
    function buildRows():Void
    {
        grpOptions.clear();
        grpExtras.clear();
        checks = [];
        values = [];
        curOptions = [];

        var labels:Array<String> = [];

        if (!isInCategory)
        {
            labels = categories.copy();
        }
        else
        {
            for (option in allOptions)
            {
                if (optionCategory.get(option) == currentCategory)
                {
                    curOptions.push(option);
                    labels.push(option.name);
                }
            }

            if (labels.length == 0)
                labels.push("Coming Soon");
        }

        curSelected = Std.int(Math.max(0, Math.min(curSelected, labels.length - 1)));

        for (i in 0...labels.length)
        {
            var label:Alphabet = new Alphabet(0, (70 * i) + 30, labels[i], true, false);
            label.isMenuItem = true;
            label.targetY = i;
            grpOptions.add(label);

            checks.push(null);
            values.push(null);

            if (isInCategory && i < curOptions.length)
            {
                var option:Option = curOptions[i];

                if (option.type == BOOL)
                {
                    var box:CheckboxIcon = new CheckboxIcon(option.getValue() == true);
                    checks[i] = box;
                    grpExtras.add(box);
                }
                else
                {
                    refreshValue(i);
                }

                placeExtras(i);
            }
        }

        updateSelection();
    }

    function selectOption():Void
    {
        if (grpOptions.length == 0)
            return;

        if (!isInCategory)
        {
            categorySelection = curSelected;
            currentCategory = categories[curSelected];
            isInCategory = true;
            curSelected = 0;
            buildRows();
            return;
        }

        if (curOptions.length == 0)
            return;

        // only bools toggle on enter, the rest use left / right
        if (curOptions[curSelected].type == BOOL)
            changeValue(1);
    }

    function changeValue(dir:Int):Void
    {
        var option:Option = curOptions[curSelected];
        option.step(dir);

        if (option.type == BOOL)
            checks[curSelected].setChecked(option.getValue() == true);
        else
            refreshValue(curSelected);

        ClientPrefs.saveSettings();
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    }

    // Replaces just the value label of one row. It's positioned right away and every
    // frame after, so nothing jumps.
    function refreshValue(i:Int):Void
    {
        var old:Alphabet = values[i];
        if (old != null)
        {
            grpExtras.remove(old, true);
            old.destroy();
        }

        var v:Alphabet = new Alphabet(0, 0, curOptions[i].getDisplay(), true, false);
        values[i] = v;
        grpExtras.add(v);
        placeExtras(i);
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

        holdTime = 0;
        holdTick = 0;

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

        var desc:String = "";
        if (isInCategory && curSelected < curOptions.length)
            desc = curOptions[curSelected].description;

        descText.text = desc;
        descBG.visible = desc != "";
    }

    function placeAllExtras():Void
    {
        for (i in 0...grpOptions.length)
            placeExtras(i);
    }

    // Checkbox / value follow their label every frame, so scrolling carries them along.
    function placeExtras(i:Int):Void
    {
        var label:Alphabet = grpOptions.members[i];
        if (label == null)
            return;

        var cx:Float = label.x + label.width + EXTRA_GAP;

        if (checks[i] != null)
        {
            checks[i].setPosition(cx, label.y + CHECK_Y);
            checks[i].alpha = label.alpha;
        }

        if (values[i] != null)
        {
            values[i].setPosition(cx, label.y);
            values[i].alpha = label.alpha;
        }
    }
}
