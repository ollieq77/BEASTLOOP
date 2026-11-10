package;

import Section.SwagSection;
import Song.SwagSong;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.utils.Assets;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.net.FileReference;
import polymod.backends.PolymodAssets;

import haxe.ui.Toolkit;
import haxe.ui.containers.VBox;
import haxe.ui.components.Label;
import haxe.ui.components.Button;
import haxe.ui.containers.TabView;
import haxe.ui.components.CheckBox;
import haxe.ui.components.TextField;
import haxe.ui.focus.FocusManager;

import StringTools;

class ChartingState extends MusicBeatState
{
	var _file:FileReference;

	/**
	 * Array of notes showing when each section STARTS in STEPS
	 * Usually rounded up??
	 */
	var curSection:Int = 0;

	public static var lastSection:Int = 0;

	var bpmTxt:FlxText;

	var strumLine:FlxSprite;

	var GRID_SIZE:Int = 40;
	var gridZoom:Int = 1;
	var maxGridZoom:Int = 8;

	var dummyArrow:FlxSprite;

	var menuBG:FlxSprite;

	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedSustains:FlxTypedGroup<FlxSprite>;

	var gridBG:FlxSprite;

	var _song:SwagSong;
	/*
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	**/
	var curSelectedNote:Array<Dynamic>;

	var tempBpm:Int = 0;

	var vocals:FlxSound;

	var leftIcon:HealthIcon;
	var rightIcon:HealthIcon;

	var editorPanel:VBox;
	var editorTabs:TabView;

	var sectionLengthInput:TextField;
	var sectionBpmInput:TextField;
	var sectionCopyInput:TextField;

	var sectionMustHitCheck:CheckBox;
	var sectionChangeBpmCheck:CheckBox;
	var sectionAltAnimCheck:CheckBox;

	var noteSustainInput:TextField;

	override function create()
	{
		curSection = lastSection;

		menuBG = new FlxSprite().loadGraphic(
    		Paths.image('menus/menuBGblacknwhite')
		);

		menuBG.setGraphicSize(FlxG.width, FlxG.height);
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.scrollFactor.set();
		menuBG.alpha = 0.5;

		add(menuBG);

		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 8, GRID_SIZE * 16);
		gridBG.scrollFactor.set(1, 1);
		gridBG.cameras = [FlxG.camera];
		add(gridBG);

		leftIcon = new HealthIcon('bf');
		rightIcon = new HealthIcon('dad');
		leftIcon.scrollFactor.set(1, 1);
		rightIcon.scrollFactor.set(1, 1);

		leftIcon.setGraphicSize(0, 45);
		rightIcon.setGraphicSize(0, 45);

		add(leftIcon);
		add(rightIcon);

		leftIcon.setPosition(0, -100);
		rightIcon.setPosition(gridBG.width / 2, -100);

		var gridBlackLine:FlxSprite = new FlxSprite(gridBG.x + gridBG.width / 2).makeGraphic(2, Std.int(gridBG.height), FlxColor.BLACK);
		add(gridBlackLine);

		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedSustains = new FlxTypedGroup<FlxSprite>();

		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
		{
			_song = {
				song: 'Test',
				notes: [],
				bpm: 150,
				sections: 0,
				needsVoices: true,
				player1: 'bf',
				player2: 'dad',
				gfVersion: 'gf',
				stage: 'stage',
				sectionLengths: [],
				speed: 1,
				validScore: false
			};
		}

		FlxG.mouse.visible = true;
		FlxG.save.bind('funkin', 'ninjamuffin99');

		tempBpm = _song.bpm;

		if (_song.notes.length == 0)
		    addSection();

		curSection = Std.int(FlxMath.bound(curSection, 0, _song.notes.length - 1));

		// sections = _song.notes;

		updateGrid();

		loadSong(_song.song);
		Conductor.changeBPM(_song.bpm);

		bpmTxt = new FlxText(1000, 50, 0, "", 16);
		bpmTxt.scrollFactor.set();
		add(bpmTxt);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(gridBG.width), 4);
		add(strumLine);
		
		FlxG.camera.follow(strumLine);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		add(dummyArrow);

		add(curRenderedNotes);
		add(curRenderedSustains);

		Toolkit.init({ container: this });
		Toolkit.theme = 'dark';

		createEditorUI();

		super.create();
	}

	function getSectionTime(sec:Int):Float
	{
	    var time:Float = 0;
	    var bpm:Float = _song.bpm;
	
	    for (i in 0...sec)
	    {
	        var section = _song.notes[i];
		
			if (section.changeBPM && section.bpm > 0)
			    bpm = section.bpm;
		
	        var stepDuration:Float = 60000 / (bpm * 4);
	
	        time += section.lengthInSteps * stepDuration;
	    }
	
	    return time;
	}


	function setupDropdownDataSource(dropdown:haxe.ui.components.DropDown, items:Array<Dynamic>, currentVal:String):Void
	{
	    var ds = new haxe.ui.data.ArrayDataSource<Dynamic>();
	    var selectedIndex:Int = 0;

	    for (i in 0...items.length)
	    {
	        ds.add({
	            text: items[i].text,
	            id: items[i].id
	        });

	        if (items[i].id == currentVal)
	            selectedIndex = i;
	    }

	    dropdown.dataSource = ds;
	    dropdown.selectedIndex = selectedIndex;
	}

	function clearUIFocus():Void
	{
	    FocusManager.instance.focus = null;
	}

	function getCharacterList():Array<Dynamic>
	{
	    var characters:Array<Dynamic> = [];
	    var charDir:String = Paths.characterDir();

	    for (path in PolymodAssets.list())
	    {
	        if (!StringTools.startsWith(path, charDir))
	            continue;

	        if (!StringTools.endsWith(path, ".json"))
	            continue;

	        var id:String = path.substr(
	            charDir.length,
	            path.length - charDir.length - 5
	        );

	        try
	        {
	            var data:Dynamic = Json.parse(PolymodAssets.getText(path));

	            characters.push({
	                text: data.name,
	                id: id
	            });
	        }
	        catch (e:Dynamic)
	        {
	            trace('Failed to load character $id: $e');
	        }
	    }

	    characters.sort(function(a, b)
	    {
	        return Reflect.compare(
	            a.text.toLowerCase(),
	            b.text.toLowerCase()
	        );
	    });

	    return characters;
	}

	function getStageList():Array<Dynamic>
	{
	    var stages:Array<Dynamic> = [];
	    var stageDir:String = "assets/data/stages/";

	    for (path in PolymodAssets.list())
	    {
	        if (!StringTools.startsWith(path, stageDir))
	            continue;

	        if (!StringTools.endsWith(path, "/stage.json"))
	            continue;

	        var id:String = path.substr(
	            stageDir.length,
	            path.length - stageDir.length - "/stage.json".length
	        );

			if (StringTools.contains(id, "/"))
			    continue;

			if (Lambda.exists(stages, function(stage) return stage.id == id))
			    continue;

	        stages.push({
	            text: id,
	            id: id
	        });
	    }

	    stages.sort(function(a, b)
	    {
	        return Reflect.compare(
	            a.text.toLowerCase(),
	            b.text.toLowerCase()
	        );
	    });

	    return stages;
	}

	function changeGridZoom(multiplier:Float):Void
	{
    var newZoom:Int = Std.int(gridZoom * multiplier);

    if (newZoom < 1 || newZoom > maxGridZoom)
        return;

    gridZoom = newZoom;

    updateGridZoom();
	}

	function updateGridZoom():Void
	{
	    var gridHeight:Int = GRID_SIZE * 16 * gridZoom;
	
	    var newGrid = FlxGridOverlay.create(
	        GRID_SIZE,
	        GRID_SIZE,
	        GRID_SIZE * 8,
	        gridHeight
	    );
		
	    gridBG.loadGraphic(newGrid.graphic);
	    gridBG.updateHitbox();
		
	    dummyArrow.setGraphicSize(GRID_SIZE, GRID_SIZE);
	    dummyArrow.updateHitbox();
		
	    updateGrid();
	}

	function createEditorUI():Void
	{
	    editorPanel = new VBox();
	
	    editorPanel.x = 20;
	    editorPanel.y = 40;
	    editorPanel.width = 300;
	    editorPanel.height = 640;
	
	    editorTabs = new TabView();
	    editorTabs.width = 300;
	    editorTabs.height = 640;
		editorTabs.onChange = function(_)
		{
		    clearUIFocus();
		};
	
		var songTab = createSongTab();
	
		var sectionTab = createSectionTab();
	
	    // NOTE TAB
		var noteTab = createNoteTab();
	
	    // ADD TABS
		editorTabs.addComponent(songTab);
	    editorTabs.addComponent(sectionTab);
	    editorTabs.addComponent(noteTab);
	
	    editorPanel.addComponent(editorTabs);
	
	    add(editorPanel);
	}

	function createSongTab():VBox
	{
		var tab = new VBox();
        tab.text = "Song";
        tab.percentWidth = 100;
        tab.percentHeight = 100;
        tab.styleString = "overflow-y: scroll;"; // Enables vertical scrolling

	    // SONG INFORMATION

	    var infoTitle = new Label();
	    infoTitle.text = "Song Information";
	    tab.addComponent(infoTitle);

	    var songName = new TextField();
	    songName.text = _song.song;
	    songName.width = 250;
	    songName.onChange = function(_)
	    {
	        _song.song = songName.text;
	    };
	    tab.addComponent(songName);

	    var bpmLabel = new Label();
	    bpmLabel.text = "BPM";
	    tab.addComponent(bpmLabel);

	    var bpmInput = new TextField();
	    bpmInput.text = Std.string(_song.bpm);
	    bpmInput.width = 100;
	    bpmInput.onChange = function(_)
	    {
	        var value = Std.parseFloat(bpmInput.text);
		
	        if (Math.isNaN(value) || value <= 0)
	            return;
		
			tempBpm = Std.int(value);
			_song.bpm = Std.int(value);

			updateGrid();
	    };
	    tab.addComponent(bpmInput);

	    var speedLabel = new Label();
	    speedLabel.text = "Scroll Speed";
	    tab.addComponent(speedLabel);

	    var speedInput = new TextField();
	    speedInput.text = Std.string(_song.speed);
	    speedInput.width = 100;
	    speedInput.onChange = function(_)
	    {
	        var value = Std.parseFloat(speedInput.text);

	        if (Math.isNaN(value) || value <= 0)
	            return;

	        _song.speed = value;
	    };
	    tab.addComponent(speedInput);

	    // CHARACTER SELECTION (DROPDOWNS)

	    var charTitle = new Label();
	    charTitle.text = "Characters";
	    tab.addComponent(charTitle);

    	var characterList:Array<Dynamic> = getCharacterList();
	    // Player 1 (Boyfriend)
	    var p1Label = new Label();
	    p1Label.text = "Player 1";
	    tab.addComponent(p1Label);

	    var p1Dropdown = new haxe.ui.components.DropDown();
	    setupDropdownDataSource(p1Dropdown, characterList, _song.player1);
	    p1Dropdown.width = 200;
	    p1Dropdown.onChange = function(_)
	    {
	        if (p1Dropdown.selectedItem != null)
	        {
	            _song.player1 = Reflect.field(p1Dropdown.selectedItem, "id");
	            updateHeads();
				clearUIFocus();
	        }
	    };
	    tab.addComponent(p1Dropdown);

	    // Player 2 (Dad / Opponent)
	    var p2Label = new Label();
	    p2Label.text = "Player 2";
	    tab.addComponent(p2Label);

	    var p2Dropdown = new haxe.ui.components.DropDown();
	    setupDropdownDataSource(p2Dropdown, characterList, _song.player2);
	    p2Dropdown.width = 200;
	    p2Dropdown.onChange = function(_)
	    {
	        if (p2Dropdown.selectedItem != null)
	        {
	            _song.player2 = Reflect.field(p2Dropdown.selectedItem, "id");
	            updateHeads();
				clearUIFocus();
	        }
	    };
	    tab.addComponent(p2Dropdown);

	    // Girlfriend
	    var gfLabel = new Label();
	    gfLabel.text = "Girlfriend";
	    tab.addComponent(gfLabel);

	    var gfDropdown = new haxe.ui.components.DropDown();
	    setupDropdownDataSource(gfDropdown, characterList, _song.gfVersion != null ? _song.gfVersion : 'gf');
	    gfDropdown.width = 200;
	    gfDropdown.onChange = function(_)
	    {
	        if (gfDropdown.selectedItem != null)
	        {
	            _song.gfVersion = Reflect.field(gfDropdown.selectedItem, "id");
				clearUIFocus();
	        }
	    };
	    tab.addComponent(gfDropdown);

		// STAGE SELECTION

		var stageTitle = new Label();
		stageTitle.text = "Stage";
		tab.addComponent(stageTitle);

		var stageList:Array<Dynamic> = getStageList();

		var stageDropdown = new haxe.ui.components.DropDown();
		setupDropdownDataSource(stageDropdown, stageList, _song.stage);
		stageDropdown.width = 200;

		stageDropdown.onChange = function(_)
		{
		    if (stageDropdown.selectedItem != null)
		    {
		        _song.stage = Reflect.field(stageDropdown.selectedItem, "id");
		        clearUIFocus();
		    }
		};

		tab.addComponent(stageDropdown);

	    // AUDIO SETTINGS

	    var audioTitle = new Label();
	    audioTitle.text = "Audio Settings";
	    tab.addComponent(audioTitle);

	    var voicesCheck = new CheckBox();
	    voicesCheck.text = "Needs voices";
	    voicesCheck.selected = _song.needsVoices;
	    voicesCheck.onChange = function(_)
	    {
	        _song.needsVoices = voicesCheck.selected;
	        clearUIFocus();
	    };
	    tab.addComponent(voicesCheck);

	    var muteInstCheck = new CheckBox();
	    muteInstCheck.text = "Mute instrumental";
	    muteInstCheck.onChange = function(_)
	    {
	        FlxG.sound.music.volume = muteInstCheck.selected ? 0 : 1;
	        clearUIFocus();
	    };
	    tab.addComponent(muteInstCheck);

	    // ACTIONS

	    var actionsTitle = new Label();
	    actionsTitle.text = "Actions";
	    tab.addComponent(actionsTitle);

	    var saveButton = new Button();
	    saveButton.text = "Save Chart";
	    saveButton.onClick = function(_)
	    {
	        saveLevel();
	        clearUIFocus();
	    };
	    tab.addComponent(saveButton);

	    var reloadAudioButton = new Button();
	    reloadAudioButton.text = "Reload Audio";
	    reloadAudioButton.onClick = function(_)
	    {
	        loadSong(_song.song);
	        clearUIFocus();
	    };
	    tab.addComponent(reloadAudioButton);

	    var reloadJsonButton = new Button();
	    reloadJsonButton.text = "Reload JSON";
	    reloadJsonButton.onClick = function(_)
	    {
	        loadJson(_song.song);
	        clearUIFocus();
	    };
	    tab.addComponent(reloadJsonButton);

	    var autosaveButton = new Button();
	    autosaveButton.text = "Load Autosave";
	    autosaveButton.onClick = function(_)
	    {
	        loadAutosave();
	        clearUIFocus();
	    };
	    tab.addComponent(autosaveButton);

	    return tab;
	}

	function createSectionTab():VBox
	{
		var tab = new VBox();
        tab.text = "Section";
        tab.percentWidth = 100;
        tab.percentHeight = 100;
        tab.styleString = "overflow-y: scroll;"; // Enables vertical scrolling
	
	    // SECTION SETTINGS
	
	    var settingsTitle = new Label();
	    settingsTitle.text = "Section Settings";
	    tab.addComponent(settingsTitle);
	
	    var lengthLabel = new Label();
	    lengthLabel.text = "Length (Steps)";
	    tab.addComponent(lengthLabel);
	
	    sectionLengthInput = new TextField();
	    sectionLengthInput.text = Std.string(_song.notes[curSection].lengthInSteps);
	    sectionLengthInput.width = 100;
	    sectionLengthInput.onChange = function(_)
	    {
	        var value = Std.parseInt(sectionLengthInput.text);
		
	        if (value == null || value <= 0)
	            return;
		
	        _song.notes[curSection].lengthInSteps = value;

			recalculateSteps();
	        updateGrid();
	    };
	    tab.addComponent(sectionLengthInput);
	
	    var mustHitCheck = new CheckBox();
	    mustHitCheck.text = "Must hit section";
	    mustHitCheck.selected = _song.notes[curSection].mustHitSection;
		mustHitCheck.allowFocus = false;
		mustHitCheck.onChange = function(_)
		{
		    trace('Must hit callback: ${mustHitCheck.selected} | Section: $curSection');
		
		    _song.notes[curSection].mustHitSection = mustHitCheck.selected;
		    updateHeads();
			clearUIFocus();
		};
	    sectionMustHitCheck = mustHitCheck;
	    tab.addComponent(mustHitCheck);
	
	    var changeBpmCheck = new CheckBox();
	    changeBpmCheck.text = "Change BPM";
		changeBpmCheck.allowFocus = false;
	    changeBpmCheck.selected = _song.notes[curSection].changeBPM;
	    changeBpmCheck.onChange = function(_)
	    {
	        _song.notes[curSection].changeBPM = changeBpmCheck.selected;
	        updateGrid();
			clearUIFocus();
	    };
	    sectionChangeBpmCheck = changeBpmCheck;
	    tab.addComponent(changeBpmCheck);
	
	    var bpmLabel = new Label();
	    bpmLabel.text = "Section BPM";
	    tab.addComponent(bpmLabel);
	
	    sectionBpmInput = new TextField();
	    sectionBpmInput.text = Std.string(_song.notes[curSection].bpm);
	    sectionBpmInput.width = 100;
	    sectionBpmInput.onChange = function(_)
	    {
	        var value = Std.parseInt(sectionBpmInput.text);
		
	        if (value == null || value <= 0)
	            return;
		
	        _song.notes[curSection].bpm = value;
	        updateGrid();
	    };
	    tab.addComponent(sectionBpmInput);
	
	    var altAnimCheck = new CheckBox();
	    altAnimCheck.text = "Alt Animation";
		altAnimCheck.allowFocus = false;
	    altAnimCheck.selected = _song.notes[curSection].altAnim;
	    altAnimCheck.onChange = function(_)
	    {
	        _song.notes[curSection].altAnim = altAnimCheck.selected;
			clearUIFocus();
	    };
	    sectionAltAnimCheck = altAnimCheck;
	    tab.addComponent(altAnimCheck);
	
	    // SECTION ACTIONS
	
	    var actionsTitle = new Label();
	    actionsTitle.text = "Section Actions";
	    tab.addComponent(actionsTitle);
	
	    var copyLabel = new Label();
	    copyLabel.text = "Sections to copy";
	    tab.addComponent(copyLabel);
	
	    sectionCopyInput = new TextField();
	    sectionCopyInput.text = "1";
	    sectionCopyInput.width = 100;
	    tab.addComponent(sectionCopyInput);
	
	    var copyButton = new Button();
	    copyButton.text = "Copy last section";
	    copyButton.onClick = function(_)
	    {
	        var amount = Std.parseInt(sectionCopyInput.text);
		
	        if (amount == null)
	            return;
		
	        copySection(amount);
			clearUIFocus();
	    };
	    tab.addComponent(copyButton);
	
	    var clearButton = new Button();
	    clearButton.text = "Clear";
	    clearButton.onClick = function(_)
	    {
	        clearSection();
			clearUIFocus();
	    };
	    tab.addComponent(clearButton);
	
	    var swapButton = new Button();
	    swapButton.text = "Swap section";
	    swapButton.onClick = function(_)
	    {
	        for (note in _song.notes[curSection].sectionNotes)
	        {
	            note[1] = (note[1] + 4) % 8;
	        }
		
	        updateGrid();
			clearUIFocus();
	    };
	    tab.addComponent(swapButton);
	
	    return tab;
	}

	function createNoteTab():VBox
	{
		var tab = new VBox();
        tab.text = "Note";
        tab.percentWidth = 100;
        tab.percentHeight = 100;
        tab.styleString = "overflow-y: scroll;"; // Enables vertical scrolling

	    var settingsTitle = new Label();
	    settingsTitle.text = "Note Settings";
	    tab.addComponent(settingsTitle);

	    var sustainLabel = new Label();
	    sustainLabel.text = "Sustain Length";
	    tab.addComponent(sustainLabel);

		noteSustainInput = new TextField();
		noteSustainInput.text = "0";
		noteSustainInput.width = 100;

		noteSustainInput.onChange = function(_)
		{
		    if (curSelectedNote == null)
		        return;
		
		    var value = Std.parseFloat(noteSustainInput.text);

		    if (Math.isNaN(value) || value < 0)
		        return;
		
		    curSelectedNote[2] = value;
		    updateGrid();
		};

		tab.addComponent(noteSustainInput);

	    return tab;
	}

	function loadSong(daSong:String):Void
	{
		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
			// vocals.stop();
		}

		FlxG.sound.playMusic(
		    Sound.fromFile(Paths.resolve(Paths.inst(daSong))),
		    0.6
		);

		vocals = new FlxSound().loadEmbedded(
		    Sound.fromFile(Paths.resolve(Paths.voices(daSong)))
		);
		
		FlxG.sound.list.add(vocals);
		
		FlxG.sound.music.pause();
		vocals.pause();

		FlxG.sound.music.onComplete = function()
		{
			vocals.pause();
			vocals.time = 0;
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		};
	}

	function lengthBpmBullshit():Float
	{
		if (_song.notes[curSection].changeBPM)
			return _song.notes[curSection].lengthInSteps * (_song.notes[curSection].bpm / _song.bpm);
		else
			return _song.notes[curSection].lengthInSteps;
	}

	override function update(elapsed:Float)
	{

		super.update(elapsed);

    	// If the music is playing, advance songPosition smoothly using frame delta (FlxG.elapsed)
    	// to match your high FPS, while keeping a safety sync to prevent audio drift.
    	if (FlxG.sound.music.playing)
    	{
    	    Conductor.songPosition += FlxG.elapsed * 1000; // elapsed is in seconds, convert to ms

    	    // If it drifts too far from the actual audio channel, snap back to avoid desync
    	    if (Math.abs(Conductor.songPosition - FlxG.sound.music.time) > 50)
    	    {
    	        Conductor.songPosition = FlxG.sound.music.time;
    	    }
    	}
    	else
    	{
    	    // When paused or scrubbing, lock directly to the audio time
    	    Conductor.songPosition = FlxG.sound.music.time;
    	}

    	curStep = recalculateSteps();

		var sectionChanged:Bool = false;

		while (curSection > 0 && Conductor.songPosition < getSectionTime(curSection))
		{
		    curSection--;
		    sectionChanged = true;
		}

		while (Conductor.songPosition >= getSectionTime(curSection + 1))
		{
		    if (curSection + 1 >= _song.notes.length)
		        addSection();
		
		    curSection++;
		    sectionChanged = true;
		}

		if (sectionChanged)
		{
		    updateGrid();
		    updateSectionUI();
		}

		strumLine.y = getYfromStrum(
    	Conductor.songPosition - getSectionTime(curSection)
		);

		FlxG.watch.addQuick('daBeat', curBeat);
		FlxG.watch.addQuick('daStep', curStep);

		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(curRenderedNotes))
			{
				curRenderedNotes.forEach(function(note:Note)
				{
					if (FlxG.mouse.overlaps(note))
					{
						if (FlxG.keys.pressed.CONTROL)
						{
							selectNote(note);
						}
						else
						{
							trace('tryin to delete note...');
							deleteNote(note);
						}
					}
				});
			}
			else
			{
				if (FlxG.mouse.x > gridBG.x
					&& FlxG.mouse.x < gridBG.x + gridBG.width
					&& FlxG.mouse.y > gridBG.y
					&& FlxG.mouse.y < gridBG.y + gridBG.height)
				{
					FlxG.log.add('added note');
					addNote();
				}
			}
		}

		if (FlxG.mouse.x > gridBG.x
			&& FlxG.mouse.x < gridBG.x + gridBG.width
			&& FlxG.mouse.y > gridBG.y
			&& FlxG.mouse.y < gridBG.y + gridBG.height)
		{
			dummyArrow.x = gridBG.x + Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE) * GRID_SIZE;

			if (FlxG.keys.pressed.SHIFT)
			    dummyArrow.y = FlxG.mouse.y;
			else
			    dummyArrow.y = gridBG.y + Math.floor((FlxG.mouse.y - gridBG.y) / GRID_SIZE) * GRID_SIZE;
		}

		if (FlxG.keys.justPressed.ENTER)
		{
			lastSection = curSection;

			PlayState.SONG = _song;
			FlxG.sound.music.stop();
			vocals.stop();
			FlxG.switchState(new PlayState());
		}

		if (FlxG.keys.justPressed.E)
		{
			changeNoteSustain(Conductor.stepCrochet);
		}
		if (FlxG.keys.justPressed.Q)
		{
			changeNoteSustain(-Conductor.stepCrochet);
		}

		if (FocusManager.instance.focus == null)
		{
			if (FlxG.keys.justPressed.SPACE)
			{
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					vocals.pause();
				}
				else
				{
					vocals.play();
					FlxG.sound.music.play();
				}
			}

			if (FlxG.keys.justPressed.R)
			{
				if (FlxG.keys.pressed.SHIFT)
					resetSection(true);
				else
					resetSection();
			}

			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.music.pause();
				vocals.pause();

				FlxG.sound.music.time -= (FlxG.mouse.wheel * Conductor.stepCrochet * 0.4);
				vocals.time = FlxG.sound.music.time;
			}

			if (!FlxG.keys.pressed.SHIFT)
			{
				if (FlxG.keys.pressed.W || FlxG.keys.pressed.S)
				{
					FlxG.sound.music.pause();
					vocals.pause();

					var daTime:Float = 700 * FlxG.elapsed;

					if (FlxG.keys.pressed.W)
					{
						FlxG.sound.music.time -= daTime;
					}
					else
						FlxG.sound.music.time += daTime;

					vocals.time = FlxG.sound.music.time;
				}
			}
			else
			{
				if (FlxG.keys.justPressed.W || FlxG.keys.justPressed.S)
				{
					FlxG.sound.music.pause();
					vocals.pause();

					var daTime:Float = Conductor.stepCrochet * 2;

					if (FlxG.keys.justPressed.W)
					{
						FlxG.sound.music.time -= daTime;
					}
					else
						FlxG.sound.music.time += daTime;

					vocals.time = FlxG.sound.music.time;
				}
			}

			if (FlxG.keys.justPressed.X)
			    changeGridZoom(2);
					
			if (FlxG.keys.justPressed.Z)
			    changeGridZoom(0.5);
		}

		_song.bpm = tempBpm;

		/* if (FlxG.keys.justPressed.UP)
				Conductor.changeBPM(Conductor.bpm + 1);
			if (FlxG.keys.justPressed.DOWN)
				Conductor.changeBPM(Conductor.bpm - 1); */

		var shiftThing:Int = 1;
		if (FlxG.keys.pressed.SHIFT)
			shiftThing = 4;
		if (FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D)
			changeSection(curSection + shiftThing);
		if (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A)
			changeSection(curSection - shiftThing);

		bpmTxt.text = Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2))
			+ " / "
			+ Std.string(FlxMath.roundDecimal(FlxG.sound.music.length / 1000, 2))
			+ "\nSection: "
			+ curSection;
	}

	function changeNoteSustain(value:Float):Void
	{
		if (curSelectedNote != null)
		{
			if (curSelectedNote[2] != null)
			{
				curSelectedNote[2] += value;
				curSelectedNote[2] = Math.max(curSelectedNote[2], 0);
			}
		}

		updateNoteUI();
		updateGrid();
	}

	function recalculateSteps():Int
	{
	    var steps:Int = 0;
	    var remainingTime:Float = Conductor.songPosition;
	    var bpm:Float = _song.bpm;

	    for (section in _song.notes)
	    {
			if (section.changeBPM && section.bpm > 0)
			    bpm = section.bpm;

	        var stepDuration:Float = 60000 / (bpm * 4);
	        var sectionDuration:Float = stepDuration * section.lengthInSteps;

	        if (remainingTime >= sectionDuration)
	        {
	            steps += section.lengthInSteps;
	            remainingTime -= sectionDuration;
	        }
	        else
	        {
	            steps += Math.floor(remainingTime / stepDuration);
	            break;
	        }
	    }

	    curStep = steps;
	    updateBeat();

	    return curStep;
	}

	function resetSection(songBeginning:Bool = false):Void
	{
	    FlxG.sound.music.pause();
	    vocals.pause();

	    if (songBeginning)
	        curSection = 0;

	    FlxG.sound.music.time = getSectionTime(curSection);
	    vocals.time = FlxG.sound.music.time;

	    Conductor.songPosition = FlxG.sound.music.time;

	    recalculateSteps();
	    updateGrid();
	    updateSectionUI();
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void
	{
	    if (sec < 0 || sec >= _song.notes.length)
	        return;

	    curSection = sec;

	    if (updateMusic)
	    {
	        FlxG.sound.music.pause();
	        vocals.pause();

	        FlxG.sound.music.time = getSectionTime(sec);
	        vocals.time = FlxG.sound.music.time;
	        Conductor.songPosition = FlxG.sound.music.time;

	        recalculateSteps();
	    }

	    updateGrid();
	    updateSectionUI();
	}
	
	function getSectionBPM(sec:Int):Float
	{
	    var bpm:Float = _song.bpm;

	    for (i in 0...(sec + 1))
	    {
	        var section = _song.notes[i];

	        if (section.changeBPM && section.bpm > 0)
	            bpm = section.bpm;
	    }

	    return bpm;
	}

	function copySection(?sectionNum:Int = 1):Void
	{
	    if (sectionNum <= 0)
	        return;

	    var daSec:Int = FlxMath.maxInt(curSection, sectionNum);
	    var sourceSection:Int = daSec - sectionNum;

	    if (daSec >= _song.notes.length)
	        return;

	    var source = _song.notes[sourceSection];
	    var destination = _song.notes[daSec];

		var sourceBpm:Float = getSectionBPM(sourceSection);
		var destinationBpm:Float = getSectionBPM(daSec);

	    if (sourceBpm <= 0 || destinationBpm <= 0)
	        return;

	    var sourceStepDuration:Float = 60000 / (sourceBpm * 4);
	    var destinationStepDuration:Float = 60000 / (destinationBpm * 4);

	    var sourceStart:Float = getSectionTime(sourceSection);
	    var destinationStart:Float = getSectionTime(daSec);

	    var bpmRatio:Float = sourceStepDuration / destinationStepDuration;

	    for (note in source.sectionNotes)
	    {
	        var copiedNote:Array<Dynamic> = note.copy();

	        var relativeTime:Float = note[0] - sourceStart;
	        var relativeSteps:Float = relativeTime / sourceStepDuration;

	        copiedNote[0] = destinationStart
	            + (relativeSteps * destinationStepDuration);

	        copiedNote[2] *= bpmRatio;

	        destination.sectionNotes.push(copiedNote);
	    }

	    updateGrid();
	}

	function updateSectionUI():Void
	{
	    var sec = _song.notes[curSection];

	    sectionLengthInput.text = Std.string(sec.lengthInSteps);
	    sectionBpmInput.text = Std.string(sec.bpm);

	    sectionMustHitCheck.selected = sec.mustHitSection;
	    sectionChangeBpmCheck.selected = sec.changeBPM;
	    sectionAltAnimCheck.selected = sec.altAnim;
	    updateHeads();
	}

	function updateHeads():Void
	{
	    if (_song.notes[curSection].mustHitSection)
	    {
	        leftIcon.animation.play(_song.player1);
	        rightIcon.animation.play(_song.player2);
	    }
	    else
	    {
	        leftIcon.animation.play(_song.player2);
	        rightIcon.animation.play(_song.player1);
	    }
	}

	function updateNoteUI():Void
	{
	    if (curSelectedNote == null)
	    {
	        noteSustainInput.text = "0";
	        return;
	    }

	    noteSustainInput.text = Std.string(curSelectedNote[2]);
	}

	function updateGrid():Void
	{
		while (curRenderedNotes.members.length > 0)
		{
			curRenderedNotes.remove(curRenderedNotes.members[0], true);
		}

		while (curRenderedSustains.members.length > 0)
		{
			curRenderedSustains.remove(curRenderedSustains.members[0], true);
		}

		var sectionInfo:Array<Dynamic> = _song.notes[curSection].sectionNotes;

		Conductor.changeBPM(Std.int(getSectionBPM(curSection)));

		for (i in sectionInfo)
		    {
		        var daNoteInfo = i[1];
		        var daStrumTime = i[0];
		        var daSus = i[2];
			
		        var note:Note = new Note(daStrumTime, daNoteInfo % 4);
		        note.sustainLength = daSus;
		        note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		        note.updateHitbox();
		        note.x = gridBG.x + Math.floor(daNoteInfo * GRID_SIZE);
			
		        // Fix: Use direct remapping relative to the section start instead of wrapping with % gridBG.height
		        var sectionStartTime:Float = getSectionTime(curSection);
		        var songCalc:Float = (daStrumTime - sectionStartTime);
		        note.y = Math.floor(FlxMath.remapToRange(
				    songCalc,
				    0,
				    _song.notes[curSection].lengthInSteps * Conductor.stepCrochet,
				    gridBG.y,
				    gridBG.y + gridBG.height
				));
			
		        curRenderedNotes.add(note);
			
				if (daSus > 0)
				{
					var sustainHeight = Math.floor(FlxMath.remapToRange(
					    daSus,
					    0,
					    Conductor.stepCrochet * _song.notes[curSection].lengthInSteps,
					    0,
					    gridBG.height
					));
					
				    var sustainVis:FlxSprite = new FlxSprite(
				        note.x + (GRID_SIZE / 2),
				        note.y + GRID_SIZE
				    ).makeGraphic(8, sustainHeight);
					
				    curRenderedSustains.add(sustainVis);
				}
		    }
	}

	private function addSection(lengthInSteps:Int = 16):Void
	{
		var sec:SwagSection = {
			lengthInSteps: lengthInSteps,
			bpm: _song.bpm,
			changeBPM: false,
			mustHitSection: true,
			sectionNotes: [],
			typeOfSection: 0,
			altAnim: false
		};

		_song.notes.push(sec);
	}

	function selectNote(note:Note):Void
	{
		var swagNum:Int = 0;

		for (i in _song.notes[curSection].sectionNotes)
		{
			if (i.strumTime == note.strumTime && i.noteData % 4 == note.noteData)
			{
				curSelectedNote = _song.notes[curSection].sectionNotes[swagNum];
			}

			swagNum += 1;
		}

		updateGrid();
		updateNoteUI();
	}

	function deleteNote(note:Note):Void
	{
	    for (i in _song.notes[curSection].sectionNotes.copy())
	    {
	        if (i[0] == note.strumTime && i[1] % 4 == note.noteData)
	        {
	            if (curSelectedNote == i)
	                curSelectedNote = null;

	            _song.notes[curSection].sectionNotes.remove(i);
	        }
	    }

	    updateGrid();
	    updateNoteUI();
	}

	function clearSection():Void
	{
	    _song.notes[curSection].sectionNotes = [];
	    curSelectedNote = null;

	    updateGrid();
	    updateNoteUI();
	}

	function clearSong():Void
	{
		for (daSection in 0..._song.notes.length)
		{
			_song.notes[daSection].sectionNotes = [];
		}

		updateGrid();
	}

	private function addNote():Void
	{
	    var noteY:Float = FlxG.keys.pressed.SHIFT
	        ? FlxG.mouse.y
	        : gridBG.y + Math.floor((FlxG.mouse.y - gridBG.y) / GRID_SIZE) * GRID_SIZE;
	
	    var noteStrum:Float = getSectionTime(curSection) + getStrumTime(noteY);
	    var noteData:Int = Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE);
	    var noteSus:Int = 0;
	
	    _song.notes[curSection].sectionNotes.push([noteStrum, noteData, noteSus]);
	
	    curSelectedNote = _song.notes[curSection].sectionNotes[
	        _song.notes[curSection].sectionNotes.length - 1
	    ];
	
	    if (FlxG.keys.pressed.CONTROL)
	    {
	        _song.notes[curSection].sectionNotes.push([
	            noteStrum,
	            (noteData + 4) % 8,
	            noteSus
	        ]);
	    }
	
	    trace(noteStrum);
	    trace(curSection);
	
	    updateGrid();
	    updateNoteUI();
	
	    autosaveSong();
	}

	function getStrumTime(yPos:Float):Float
	{
	    return FlxMath.remapToRange(
	        yPos,
	        gridBG.y,
	        gridBG.y + gridBG.height,
	        0,
	        _song.notes[curSection].lengthInSteps * Conductor.stepCrochet
	    );
	}

	function getYfromStrum(strumTime:Float):Float
	{
	    return FlxMath.remapToRange(
	        strumTime,
	        0,
	        _song.notes[curSection].lengthInSteps * Conductor.stepCrochet,
	        gridBG.y,
	        gridBG.y + gridBG.height
	    );
	}

	function calculateSectionLengths(?sec:SwagSection):Int
	{
		var daLength:Int = 0;

		for (i in _song.notes)
		{
			var swagLength = i.lengthInSteps;

			if (i.typeOfSection == Section.COPYCAT)
				swagLength * 2;

			daLength += swagLength;

			if (sec != null && sec == i)
			{
				trace('swag loop??');
				break;
			}
		}

		return daLength;
	}

	function loadLevel():Void
	{
		trace(_song.notes);
	}

	function getNotes():Array<Dynamic>
	{
		var noteData:Array<Dynamic> = [];

		for (i in _song.notes)
		{
			noteData.push(i.sectionNotes);
		}

		return noteData;
	}

	function loadJson(song:String):Void
	{
	    var difficulty:String = "hard";
	
	    if (!PolymodAssets.exists(Paths.songChart(song, difficulty)))
	    {
	        difficulty = "normal";
		
	        if (!PolymodAssets.exists(Paths.songChart(song, difficulty)))
	        {
	            difficulty = "easy";
	        }
	    }
	
	    PlayState.SONG = Song.loadFromJson(difficulty, song.toLowerCase());
	    FlxG.resetState();
	}

	function loadAutosave():Void
	{
		PlayState.SONG = Song.parseJSONshit(FlxG.save.data.autosave);
		FlxG.resetState();
	}

	function autosaveSong():Void
	{
		FlxG.save.data.autosave = Json.stringify({
			"song": _song,
			"bpm": _song.bpm,
			"sections": _song.notes.length,
			'notes': _song.notes
		});
		FlxG.save.flush();
	}

	private function saveLevel()
	{
		var json = {
			"song": _song,
			"bpm": _song.bpm,
			"sections": _song.notes.length,
			'notes': _song.notes
		};

		var data:String = Json.stringify(json);

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(StringTools.trim(data), _song.song.toLowerCase() + ".json");
		}
	}

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving Level data");
	}
}
