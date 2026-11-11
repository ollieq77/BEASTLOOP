package;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import haxe.ui.Toolkit;
import haxe.ui.components.Button;
import haxe.ui.components.DropDown;
import haxe.ui.components.Label;
import haxe.ui.containers.TabView;
import haxe.ui.containers.VBox;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.focus.FocusManager;
import polymod.backends.PolymodAssets;
import sys.FileSystem;
import sys.io.File;

/**
 * Where "Save" writes the character json.
 *
 * Assets -> Paths.character(id)                       (assets/data/characters/<id>.json, relative to the exe)
 * Mods   -> mods/<modId>/data/characters/<id>.json    (Polymod overlays this on top of assets/)
 *
 * TODO: add a FileReference "Save As..." option next to these two if we want a picker too.
 */
enum SaveTarget
{
	Assets;
	Mods;
}

/**
 * CHARACTER EDITOR (skeleton)
 *
 * The parsed json (`data`) is the source of truth. The preview Character is built through
 * CharacterLoader, so what you see is what the game will load.
 *
 * Controls (when no text field is focused):
 *   W / S         previous / next animation
 *   SPACE         replay current animation
 *   ARROWS        nudge the current animation's offset (hold SHIFT for x10)
 *   I J K L       move the camera
 *   Q / E         zoom out / in
 *   ESCAPE        back to the main menu
 */
class CharacterEditorState extends MusicBeatState
{
	// ---- what we're editing ----
	var charId:String;
	var data:Dynamic;
	var char:Character;

	var animList:Array<String> = [];
	var curAnim:Int = 0;

	// ---- save settings ----
	var saveTarget:SaveTarget = SaveTarget.Mods;
	var modList:Array<String> = [];
	var modId:String = "";

	// ---- scene ----
	var camFollow:FlxObject;
	var animText:FlxText;
	var statusText:FlxText;

	// ---- ui ----
	var panel:VBox;
	var tabs:TabView;
	var charDropdown:DropDown;
	var animDropdown:DropDown;
	var offsetLabel:Label;

	// HaxeUI fires onChange when we set a dropdown from code, this stops that feeding back into itself.
	var settingUI:Bool = false;

	public function new(charId:String = 'bf')
	{
		super();
		this.charId = charId;
	}

	override function create()
	{
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		FlxG.mouse.visible = true;

		var gridBG:FlxSprite = FlxGridOverlay.create(10, 10);
		gridBG.scrollFactor.set(0.5, 0.5);
		add(gridBG);

		camFollow = new FlxObject(0, 0, 2, 2);
		camFollow.screenCenter();
		add(camFollow);
		FlxG.camera.follow(camFollow);

		animText = new FlxText(10, 10, 0, "", 26);
		animText.scrollFactor.set();
		add(animText);

		statusText = new FlxText(10, FlxG.height - 30, 0, "", 16);
		statusText.scrollFactor.set();
		add(statusText);

		modList = getModList();
		if (modList.length > 0)
			modId = modList[0];

		Toolkit.init({container: this});
		Toolkit.theme = 'dark';

		loadCharacter(charId);
		createEditorUI();

		super.create();
	}

	// =========================================================
	// LOADING
	// =========================================================

	function loadCharacter(id:String):Void
	{
		var raw:String = null;

		try
		{
			raw = PolymodAssets.getText(Paths.character(id));
			data = Json.parse(raw);
		}
		catch (e:Dynamic)
		{
			setStatus('Failed to load character "$id": $e', FlxColor.RED);
			return;
		}

		charId = id;

		if (char != null)
		{
			remove(char, true);
			char.destroy();
		}

		// Same isPlayer as the json's isPlayerCharacter, so Character doesn't swap the left/right anims on us.
		var isPlayerChar:Bool = data.behaviour != null && data.behaviour.isPlayerCharacter == true;

		char = new Character(0, 0, id, isPlayerChar, false);
		char.debugMode = true;
		char.screenCenter();
		char.flipX = false; // same as AnimationDebug. TODO: show json flipX once the properties tab exists
		add(char);

		animList = [];
		var anims:Array<Dynamic> = data.animations;
		if (anims != null)
			for (anim in anims)
				animList.push(anim.name);

		curAnim = 0;
		playCurAnim();
		setStatus('Loaded "$id"', FlxColor.WHITE);
	}

	// =========================================================
	// UI
	// =========================================================

	function createEditorUI():Void
	{
		panel = new VBox();
		panel.x = FlxG.width - 320;
		panel.y = 40;
		panel.width = 300;
		panel.height = 640;

		tabs = new TabView();
		tabs.width = 300;
		tabs.height = 640;
		tabs.onChange = function(_)
		{
			clearUIFocus();
		};

		tabs.addComponent(createCharacterTab());
		tabs.addComponent(createAnimationsTab());
		tabs.addComponent(createPropertiesTab());

		panel.addComponent(tabs);
		add(panel);

		refreshAnimUI();
	}

	function createCharacterTab():VBox
	{
		var tab = new VBox();
		tab.text = "Character";
		tab.percentWidth = 100;
		tab.percentHeight = 100;

		var title = new Label();
		title.text = "Character";
		tab.addComponent(title);

		charDropdown = new DropDown();
		charDropdown.width = 250;
		setupDropdownDataSource(charDropdown, getCharacterList(), charId);
		charDropdown.onChange = function(_)
		{
			if (settingUI || charDropdown.selectedItem == null)
				return;

			loadCharacter(Reflect.field(charDropdown.selectedItem, "id"));
			refreshAnimUI();
			clearUIFocus();
		};
		tab.addComponent(charDropdown);

		var reloadButton = new Button();
		reloadButton.text = "Reload from disk";
		reloadButton.onClick = function(_)
		{
			loadCharacter(charId);
			refreshAnimUI();
			clearUIFocus();
		};
		tab.addComponent(reloadButton);

		// ---- save ----

		var saveTitle = new Label();
		saveTitle.text = "Save to";
		tab.addComponent(saveTitle);

		var targetDropdown = new DropDown();
		targetDropdown.width = 250;
		setupDropdownDataSource(targetDropdown, [
			{text: "Mods data folder", id: "mods"},
			{text: "Assets data folder", id: "assets"}
		], "mods");
		targetDropdown.onChange = function(_)
		{
			if (settingUI || targetDropdown.selectedItem == null)
				return;

			saveTarget = (Reflect.field(targetDropdown.selectedItem, "id") == "assets") ? SaveTarget.Assets : SaveTarget.Mods;
			clearUIFocus();
		};
		tab.addComponent(targetDropdown);

		var modTitle = new Label();
		modTitle.text = "Mod (for mods target)";
		tab.addComponent(modTitle);

		var modDropdown = new DropDown();
		modDropdown.width = 250;
		var modItems:Array<Dynamic> = [for (m in modList) {text: m, id: m}];
		setupDropdownDataSource(modDropdown, modItems, modId);
		modDropdown.onChange = function(_)
		{
			if (settingUI || modDropdown.selectedItem == null)
				return;

			modId = Reflect.field(modDropdown.selectedItem, "id");
			clearUIFocus();
		};
		tab.addComponent(modDropdown);

		var saveButton = new Button();
		saveButton.text = "Save";
		saveButton.onClick = function(_)
		{
			saveCharacter();
			clearUIFocus();
		};
		tab.addComponent(saveButton);

		return tab;
	}

	function createAnimationsTab():VBox
	{
		var tab = new VBox();
		tab.text = "Animations";
		tab.percentWidth = 100;
		tab.percentHeight = 100;

		var title = new Label();
		title.text = "Animation";
		tab.addComponent(title);

		animDropdown = new DropDown();
		animDropdown.width = 250;
		animDropdown.onChange = function(_)
		{
			if (settingUI || animDropdown.selectedItem == null)
				return;

			var idx = animList.indexOf(Reflect.field(animDropdown.selectedItem, "id"));
			if (idx != -1)
			{
				curAnim = idx;
				playCurAnim();
			}
			clearUIFocus();
		};
		tab.addComponent(animDropdown);

		offsetLabel = new Label();
		offsetLabel.text = "Offset: -";
		tab.addComponent(offsetLabel);

		var hint = new Label();
		hint.text = "Arrows nudge the offset (SHIFT = x10)";
		tab.addComponent(hint);

		// TODO: prefix / fps / loop fields, indices frames, add + remove + rename animation

		return tab;
	}

	function createPropertiesTab():VBox
	{
		var tab = new VBox();
		tab.text = "Properties";
		tab.percentWidth = 100;
		tab.percentHeight = 100;

		var todo = new Label();
		todo.text = "TODO: name, position, cameraPosition, atlas image + xml, scale, flipX, antialiasing, isPlayerCharacter";
		tab.addComponent(todo);

		return tab;
	}

	function setupDropdownDataSource(dropdown:DropDown, items:Array<Dynamic>, currentVal:String):Void
	{
		settingUI = true;

		var ds = new ArrayDataSource<Dynamic>();
		var selectedIndex:Int = 0;

		for (i in 0...items.length)
		{
			ds.add({text: items[i].text, id: items[i].id});

			if (items[i].id == currentVal)
				selectedIndex = i;
		}

		dropdown.dataSource = ds;

		if (items.length > 0)
			dropdown.selectedIndex = selectedIndex;

		settingUI = false;
	}

	function refreshAnimUI():Void
	{
		if (animDropdown == null)
			return;

		var items:Array<Dynamic> = [for (a in animList) {text: a, id: a}];
		setupDropdownDataSource(animDropdown, items, animList.length > 0 ? animList[curAnim] : "");
		updateOffsetLabel();
	}

	function updateOffsetLabel():Void
	{
		if (offsetLabel == null)
			return;

		var anim = getAnimData(currentAnimName());
		offsetLabel.text = (anim != null) ? 'Offset: ${anim.offset[0]}, ${anim.offset[1]}' : "Offset: -";
	}

	function clearUIFocus():Void
	{
		FocusManager.instance.focus = null;
	}

	// True while a text field has focus, so typing doesn't trigger the hotkeys.
	function isTyping():Bool
	{
		return Std.isOfType(FocusManager.instance.focus, haxe.ui.components.TextField);
	}

	// =========================================================
	// ANIMATIONS
	// =========================================================

	function currentAnimName():String
	{
		return (animList.length > 0) ? animList[curAnim] : "";
	}

	// The json entry for an animation (the thing that actually gets saved).
	function getAnimData(name:String):Dynamic
	{
		var anims:Array<Dynamic> = (data != null) ? data.animations : null;
		if (anims == null)
			return null;

		for (anim in anims)
			if (anim.name == name)
				return anim;

		return null;
	}

	function playCurAnim():Void
	{
		if (char == null || animList.length == 0)
			return;

		char.playAnim(currentAnimName(), true);
		updateOffsetLabel();
	}

	function nudgeOffset(dx:Int, dy:Int):Void
	{
		var name = currentAnimName();
		var anim = getAnimData(name);

		if (anim == null)
			return;

		// Keep the json entry and the live Character in step.
		anim.offset[0] += dx;
		anim.offset[1] += dy;
		char.addOffset(name, anim.offset[0], anim.offset[1]);

		playCurAnim();
	}

	// =========================================================
	// SAVING
	// =========================================================

	function saveCharacter():Void
	{
		if (data == null)
			return;

		var path:String;

		switch (saveTarget)
		{
			case Assets:
				path = Paths.character(charId);

			case Mods:
				if (modId == "")
				{
					setStatus('No mod selected (mods/modList.txt is empty or missing)', FlxColor.RED);
					return;
				}
				path = 'mods/$modId/data/characters/$charId.json';
		}

		try
		{
			ensureDir(path.substr(0, path.lastIndexOf("/")));
			File.saveContent(path, Json.stringify(data, null, "    "));
			setStatus('Saved $path', FlxColor.LIME);
		}
		catch (e:Dynamic)
		{
			setStatus('Save failed: $e', FlxColor.RED);
		}
	}

	// FileSystem.createDirectory isn't recursive, so make each level.
	function ensureDir(dir:String):Void
	{
		var built = "";

		for (part in dir.split("/"))
		{
			built += (built == "" ? "" : "/") + part;

			if (part != "" && !FileSystem.exists(built))
				FileSystem.createDirectory(built);
		}
	}

	// =========================================================
	// LISTS
	// =========================================================

	// Same format Polymod.init reads in TitleState.
	function getModList():Array<String>
	{
		var mods:Array<String> = [];

		if (!FileSystem.exists("mods/modList.txt"))
			return mods;

		for (line in File.getContent("mods/modList.txt").split("\n"))
		{
			var mod = StringTools.trim(line);

			if (mod.length == 0 || StringTools.startsWith(mod, "#"))
				continue;

			mods.push(mod);
		}

		return mods;
	}

	// TODO: ChartingState has its own copy of this, move it somewhere shared.
	function getCharacterList():Array<Dynamic>
	{
		var characters:Array<Dynamic> = [];
		var charDir:String = Paths.characterDir();

		for (path in PolymodAssets.list())
		{
			if (!StringTools.startsWith(path, charDir) || !StringTools.endsWith(path, ".json"))
				continue;

			var id:String = path.substr(charDir.length, path.length - charDir.length - 5);

			try
			{
				var json:Dynamic = Json.parse(PolymodAssets.getText(path));
				characters.push({text: json.name, id: id});
			}
			catch (e:Dynamic)
			{
				trace('Failed to read character $id: $e');
			}
		}

		characters.sort(function(a, b)
		{
			return Reflect.compare(a.text.toLowerCase(), b.text.toLowerCase());
		});

		return characters;
	}

	// =========================================================
	// UPDATE
	// =========================================================

	function setStatus(msg:String, color:FlxColor):Void
	{
		trace(msg);

		if (statusText != null)
		{
			statusText.text = msg;
			statusText.color = color;
		}
	}

	override function update(elapsed:Float)
	{
		if (char != null && char.animation.curAnim != null)
			animText.text = char.animation.curAnim.name;

		if (!isTyping())
		{
			if (FlxG.keys.justPressed.ESCAPE)
			{
				FlxG.switchState(new MainMenuState());
				return;
			}

			if (FlxG.keys.justPressed.E)
				FlxG.camera.zoom += 0.25;
			if (FlxG.keys.justPressed.Q)
				FlxG.camera.zoom -= 0.25;

			camFollow.velocity.set(0, 0);
			if (FlxG.keys.pressed.I)
				camFollow.velocity.y = -90;
			else if (FlxG.keys.pressed.K)
				camFollow.velocity.y = 90;
			if (FlxG.keys.pressed.J)
				camFollow.velocity.x = -90;
			else if (FlxG.keys.pressed.L)
				camFollow.velocity.x = 90;

			if (animList.length > 0)
			{
				if (FlxG.keys.justPressed.W)
					curAnim--;
				if (FlxG.keys.justPressed.S)
					curAnim++;

				if (curAnim < 0)
					curAnim = animList.length - 1;
				if (curAnim >= animList.length)
					curAnim = 0;

				if (FlxG.keys.justPressed.W || FlxG.keys.justPressed.S || FlxG.keys.justPressed.SPACE)
				{
					playCurAnim();
					refreshAnimUI();
				}

				var mult:Int = FlxG.keys.pressed.SHIFT ? 10 : 1;

				// Same directions as AnimationDebug.
				if (FlxG.keys.justPressed.UP)
					nudgeOffset(0, mult);
				if (FlxG.keys.justPressed.DOWN)
					nudgeOffset(0, -mult);
				if (FlxG.keys.justPressed.LEFT)
					nudgeOffset(mult, 0);
				if (FlxG.keys.justPressed.RIGHT)
					nudgeOffset(-mult, 0);
			}
		}

		super.update(elapsed);
	}
}
