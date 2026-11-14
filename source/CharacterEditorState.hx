package;

import flixel.FlxCamera;
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
import haxe.ui.containers.HBox;
import haxe.ui.containers.TabView;
import haxe.ui.containers.VBox;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.focus.FocusManager;
import lime.ui.FileDialog;
import lime.ui.FileDialogType;
import polymod.backends.PolymodAssets;
import sys.FileSystem;
import sys.io.File;

import haxe.ui.components.TextField;
import haxe.ui.components.CheckBox;

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
 * CHARACTER EDITOR
 *
 * The parsed json (`data`) is the source of truth. The preview Character is built through
 * CharacterLoader, so what you see is what the game will load.
 *
 * Tabs:
 *   Character   pick a character, make a new one from a template, pick its PNG (the .xml has to
 *               sit next to it with the same name), reload, choose where to save
 *   Animations  add / remove / rename, prefix (with a picker built from the atlas), type
 *               (prefix or indices), frames, fps, loop
 *   Properties  name, position, scale, antialiasing, flip X, is player character
 *
 * Controls (when no text field is focused):
 *   W / S         previous / next animation
 *   SPACE         replay current animation
 *   ARROWS        nudge the current animation's offset (hold SHIFT for x10)
 *   I J K L       move the camera
 *   Q / E         zoom out / in (the UI lives on its own camera so it doesn't zoom)
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

	// Where the preview sprite's (0, 0) "stage slot" is. data.position is added on top of this,
	// same as the game adds positionOffset on top of the stage position.
	var anchorX:Float = 0;
	var anchorY:Float = 0;

	// Every distinct animation prefix found in the atlas ("BF NOTE UP", "BF idle dance", ...)
	var atlasPrefixes:Array<String> = [];

	// ---- save settings ----
	var saveTarget:SaveTarget = SaveTarget.Mods;
	var modList:Array<String> = [];
	var modId:String = "";

	// ---- scene ----
	var camFollow:FlxObject;
	var animText:FlxText;
	var statusText:FlxText;

	// ---- ui ----
	// The UI is drawn by its own camera so zooming the world (Q / E) doesn't scale the panel.
	var uiCam:FlxCamera;
	var panel:VBox;
	var tabs:TabView;
	var charDropdown:DropDown;
	var animDropdown:DropDown;
	var offsetLabel:Label;

	// character tab
	var newIdField:TextField;
	var atlasLabel:Label;
	var fileDialog:FileDialog;

	// animations tab
	var animNameField:TextField;
	var prefixField:TextField;
	var prefixPicker:DropDown;
	var typeDropdown:DropDown;
	var indicesField:TextField;
	var fpsField:TextField;
	var loopCheck:CheckBox;

	// properties tab
	var nameField:TextField;
	var posXField:TextField;
	var posYField:TextField;
	var scaleField:TextField;
	var aaCheck:CheckBox;
	var flipCheck:CheckBox;
	var playerCheck:CheckBox;

	// HaxeUI fires onChange when we set a widget from code, this stops that feeding back into itself.
	// Every handler ALSO compares against `data` and bails if nothing changed, so even a late
	// event can't write stale values into the json.
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

		// Drawn after (on top of) the default camera, and not a default draw target, so only
		// things we explicitly give it show up there.
		uiCam = new FlxCamera();
		uiCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(uiCam, false);

		var gridBG:FlxSprite = FlxGridOverlay.create(10, 10);
		gridBG.scrollFactor.set(0.5, 0.5);
		add(gridBG);

		camFollow = new FlxObject(0, 0, 2, 2);
		camFollow.screenCenter();
		add(camFollow);
		FlxG.camera.follow(camFollow);

		animText = new FlxText(10, 10, 0, "", 26);
		animText.scrollFactor.set();
		animText.cameras = [uiCam];
		add(animText);

		statusText = new FlxText(10, FlxG.height - 30, 0, "", 16);
		statusText.scrollFactor.set();
		statusText.cameras = [uiCam];
		add(statusText);

		modList = getModList();
		if (modList.length > 0)
			modId = modList[0];

		Toolkit.init({container: this});
		Toolkit.theme = 'dark';

		// Build the (empty) widgets first, loadCharacter then fills them in. That way a failed
		// first load leaves a working editor instead of a null crash.
		createEditorUI();
		loadCharacter(charId);

		super.create();
	}

	// =========================================================
	// LOADING
	// =========================================================

	function loadCharacter(id:String):Void
	{
		var parsed:Dynamic;

		try
		{
			parsed = Json.parse(PolymodAssets.getText(Paths.character(id)));
		}
		catch (e:Dynamic)
		{
			setStatus('Failed to load character "$id": $e', FlxColor.RED);
			return;
		}

		if (parsed == null)
		{
			setStatus('Character "$id" contains invalid JSON data', FlxColor.RED);
			return;
		}

		// Only swap over once we know the new data is usable, so a bad file keeps the old one.
		data = parsed;
		charId = id;

		// Ensure optional properties exist before accessing them.
		applyCharacterDefaults();

		curAnim = 0;
		buildCharacter(true);

		refreshAllUI();
		playCurAnim();

		if (char != null)
			setStatus('Loaded "$id"', FlxColor.WHITE);
	}

	function applyCharacterDefaults():Void
	{
		if (data == null)
			return;

		// General
		if (data.name == null || data.name == "")
			data.name = charId;

		// Position
		if (data.position == null)
			data.position = [0, 0];

		while (data.position.length < 2)
			data.position.push(0);

		// Display
		if (data.display == null)
			data.display = {};

		if (data.display.scale == null)
			data.display.scale = 1;

		if (data.display.antialiasing == null)
			data.display.antialiasing = true;

		if (data.display.flipX == null)
			data.display.flipX = false;

		// Behaviour
		if (data.behaviour == null)
			data.behaviour = {};

		if (data.behaviour.isPlayerCharacter == null)
			data.behaviour.isPlayerCharacter = false;

		// Animations
		if (data.animations == null)
			data.animations = [];

		for (anim in (cast data.animations:Array<Dynamic>))
		{
			if (anim == null)
				continue;

			if (anim.offset == null)
				anim.offset = [0, 0];

			while (anim.offset.length < 2)
				anim.offset.push(0);

			if (anim.fps == null)
				anim.fps = 24;

			if (anim.loop == null)
				anim.loop = true;
		}
	}

	/**
	 * (Re)creates the preview Character from `data`. This is the ONE place that does it.
	 *
	 * resetAnchor = true  -> new character: centre it on screen and remember where its
	 *                        stage slot is (so data.position can move it relative to that).
	 * resetAnchor = false -> same character, rebuilt (scale / flip changed): keep the slot.
	 */
	function buildCharacter(resetAnchor:Bool):Void
	{
		if (data == null)
			return;

		if (char != null)
		{
			remove(char, true);
			char.destroy();
			char = null;
		}

		// A fresh template has no atlas until a PNG is picked. Nothing to build, but the animation
		// list still needs to exist so the Animations tab works.
		if (!hasAtlas())
		{
			animList = [];

			var bareAnims:Array<Dynamic> = data.animations;

			if (bareAnims != null)
			{
				for (anim in bareAnims)
					animList.push(anim.name);
			}

			if (curAnim >= animList.length)
				curAnim = 0;

			atlasPrefixes = [];
			refreshPrefixPicker();
			setStatus('"$charId" has no atlas yet, use Pick PNG... on the Character tab', FlxColor.ORANGE);
			return;
		}

		var isPlayerChar:Bool = data.behaviour != null && data.behaviour.isPlayerCharacter == true;

		try
		{
			// Pass the JSON into CharacterLoader through the constructor.
			char = new Character(0, 0, charId, isPlayerChar, false, data);
		}
		catch (e:Dynamic)
		{
			char = null;
			animList = [];
			atlasPrefixes = [];
			refreshPrefixPicker();
			setStatus('Could not build "$charId" (check its atlas paths): $e', FlxColor.RED);
			return;
		}

		char.debugMode = true;

		if (resetAnchor)
		{
			char.screenCenter();
			anchorX = char.x - data.position[0];
			anchorY = char.y - data.position[1];
		}

		positionChar();
		add(char);

		animList = [];

		var anims:Array<Dynamic> = data.animations;

		if (anims != null)
		{
			for (anim in anims)
				animList.push(anim.name);
		}

		if (curAnim >= animList.length)
			curAnim = 0;

		atlasPrefixes = collectAtlasPrefixes();
		refreshPrefixPicker();
	}

	// Same job as the old loadCharacter/rebuildCharacter duplication, minus the duplication.
	function rebuildCharacter():Void
	{
		if (data == null)
			return;

		buildCharacter(false);
		refreshAnimUI();
		playCurAnim();
	}

	function positionChar():Void
	{
		if (char == null || data == null)
			return;

		char.setPosition(anchorX + data.position[0], anchorY + data.position[1]);
	}

	// All the distinct prefixes in the atlas: frame names minus their trailing frame number.
	function collectAtlasPrefixes():Array<String>
	{
		var out:Array<String> = [];

		if (char == null || char.frames == null)
			return out;

		var seen = new Map<String, Bool>();

		for (frame in char.frames.frames)
		{
			var n:String = frame.name;

			if (n == null)
				continue;

			var end:Int = n.length;

			while (end > 0)
			{
				var c:Int = n.charCodeAt(end - 1);

				if (c < 48 || c > 57)
					break;

				end--;
			}

			var p:String = n.substr(0, end);

			if (p == "" || seen.exists(p))
				continue;

			seen.set(p, true);
			out.push(p);
		}

		out.sort(function(a, b) return Reflect.compare(a.toLowerCase(), b.toLowerCase()));

		return out;
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

		tabs.addComponent(createCharacterTab());
		tabs.addComponent(createAnimationsTab());
		tabs.addComponent(createPropertiesTab());

		panel.addComponent(tabs);
		add(panel);

		// Set AFTER everything is built so every child gets it. haxeui-flixel hands the same
		// cameras to anything that pops up later (dropdown lists) on its own.
		panel.cameras = [uiCam];
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

			var picked:String = Reflect.field(charDropdown.selectedItem, "id");

			// Already showing it (e.g. a late change event from setting the list from code): don't
			// reload from disk and throw away unsaved edits.
			if (picked != charId)
				loadCharacter(picked);

			clearUIFocus();
		};
		tab.addComponent(charDropdown);

		var reloadButton = new Button();
		reloadButton.text = "Reload from disk";
		reloadButton.onClick = function(_)
		{
			loadCharacter(charId);
			clearUIFocus();
		};
		tab.addComponent(reloadButton);

		// ---- new character ----

		addSectionTitle(tab, "New character id");

		newIdField = new TextField();
		newIdField.width = 250;
		tab.addComponent(newIdField);

		var templateButton = new Button();
		templateButton.text = "New from template";
		templateButton.onClick = function(_)
		{
			newFromTemplate();
			clearUIFocus();
		};
		tab.addComponent(templateButton);

		// ---- atlas ----

		addSectionTitle(tab, "Atlas");

		atlasLabel = new Label();
		atlasLabel.text = "-";
		tab.addComponent(atlasLabel);

		var pngButton = new Button();
		pngButton.text = "Pick PNG...";
		pngButton.onClick = function(_)
		{
			pickPng();
			clearUIFocus();
		};
		tab.addComponent(pngButton);

		addSectionTitle(tab, "(the .xml goes next to the .png)");

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

		addSectionTitle(tab, "Animation");

		animDropdown = new DropDown();
		animDropdown.width = 250;
		animDropdown.onChange = function(_)
		{
			if (settingUI || animDropdown.selectedItem == null)
				return;

			var idx = animList.indexOf(Reflect.field(animDropdown.selectedItem, "id"));

			if (idx != -1 && idx != curAnim)
			{
				curAnim = idx;
				refreshAnimFields();
				playCurAnim();
			}
			clearUIFocus();
		};
		tab.addComponent(animDropdown);

		// ---- add / remove ----

		var addRemoveRow = new HBox();

		var addButton = new Button();
		addButton.text = "Add";
		addButton.width = 120;
		addButton.onClick = function(_)
		{
			addNewAnimation();
			clearUIFocus();
		};
		addRemoveRow.addComponent(addButton);

		var removeButton = new Button();
		removeButton.text = "Remove";
		removeButton.width = 120;
		removeButton.onClick = function(_)
		{
			removeCurrentAnimation();
			clearUIFocus();
		};
		addRemoveRow.addComponent(removeButton);

		tab.addComponent(addRemoveRow);

		// ---- name (applied with the button, so half-typed names don't churn) ----

		addSectionTitle(tab, "Name");

		var nameRow = new HBox();

		animNameField = new TextField();
		animNameField.width = 165;
		nameRow.addComponent(animNameField);

		var renameButton = new Button();
		renameButton.text = "Rename";
		renameButton.width = 80;
		renameButton.onClick = function(_)
		{
			renameCurrentAnimation();
			clearUIFocus();
		};
		nameRow.addComponent(renameButton);

		tab.addComponent(nameRow);

		// ---- prefix ----

		addSectionTitle(tab, "Prefix");

		prefixField = new TextField();
		prefixField.width = 250;
		prefixField.onChange = function(_)
		{
			if (settingUI)
				return;

			var anim = curAnimData();

			if (anim == null || anim.prefix == prefixField.text)
				return;

			anim.prefix = prefixField.text;
			reapplyAnim(anim);
		};
		tab.addComponent(prefixField);

		// Acts like a menu: only ever fires with a real pick, then snaps back to "nothing selected".
		prefixPicker = new DropDown();
		prefixPicker.width = 250;
		prefixPicker.text = "Pick prefix from atlas...";
		prefixPicker.onChange = function(_)
		{
			if (settingUI || prefixPicker.selectedItem == null)
				return;

			var anim = curAnimData();
			var picked:String = Reflect.field(prefixPicker.selectedItem, "id");

			if (anim != null && picked != null)
			{
				var prefix = disambiguatePrefix(picked, anim);

				anim.prefix = prefix;

				var prev = settingUI;
				settingUI = true;
				prefixField.text = prefix;
				prefixPicker.selectedIndex = -1;
				settingUI = prev;

				reapplyAnim(anim);
			}

			clearUIFocus();
		};
		tab.addComponent(prefixPicker);

		// ---- type + frames ----

		addSectionTitle(tab, "Type");

		typeDropdown = new DropDown();
		typeDropdown.width = 250;
		setupDropdownDataSource(typeDropdown, [
			{text: "Prefix (every frame with it)", id: "prefix"},
			{text: "Indices (pick frames)", id: "indices"}
		], "prefix");
		typeDropdown.onChange = function(_)
		{
			if (settingUI || typeDropdown.selectedItem == null)
				return;

			var anim = curAnimData();

			if (anim == null)
				return;

			var wantIndices:Bool = Reflect.field(typeDropdown.selectedItem, "id") == "indices";
			var isIndices:Bool = anim.type == "indices";

			if (wantIndices == isIndices)
				return;

			if (wantIndices)
			{
				anim.type = "indices";

				if (anim.frames == null)
					anim.frames = [0];
			}
			else
			{
				// Match how the existing prefix animations look in the json (no type / frames keys).
				Reflect.deleteField(anim, "type");
				Reflect.deleteField(anim, "frames");
			}

			refreshAnimFields();
			reapplyAnim(anim);
			clearUIFocus();
		};
		tab.addComponent(typeDropdown);

		addSectionTitle(tab, "Frames (Indices only), e.g. 0-12, 30");

		indicesField = new TextField();
		indicesField.width = 250;
		indicesField.onChange = function(_)
		{
			if (settingUI)
				return;

			var anim = curAnimData();

			if (anim == null || anim.type != "indices")
				return;

			var parsed = parseIndices(indicesField.text);

			// Half-typed ("0-") or empty: keep the last good frames until it makes sense again.
			if (parsed == null || parsed.length == 0 || sameInts(anim.frames, parsed))
				return;

			anim.frames = parsed;
			reapplyAnim(anim);
		};
		tab.addComponent(indicesField);

		// ---- fps / loop ----

		addSectionTitle(tab, "FPS");

		fpsField = new TextField();
		fpsField.width = 250;
		fpsField.onChange = function(_)
		{
			if (settingUI)
				return;

			var anim = curAnimData();
			var v:Float = Std.parseFloat(fpsField.text);

			if (anim == null || Math.isNaN(v) || v <= 0 || anim.fps == v)
				return;

			anim.fps = v;
			reapplyAnim(anim);
		};
		tab.addComponent(fpsField);

		loopCheck = new CheckBox();
		loopCheck.text = "Loop";
		loopCheck.onChange = function(_)
		{
			if (settingUI)
				return;

			var anim = curAnimData();

			if (anim == null || anim.loop == loopCheck.selected)
				return;

			anim.loop = loopCheck.selected;
			reapplyAnim(anim);
		};
		tab.addComponent(loopCheck);

		// ---- offset ----

		offsetLabel = new Label();
		offsetLabel.text = "Offset: -";
		tab.addComponent(offsetLabel);

		var hint = new Label();
		hint.text = "Arrows nudge the offset (SHIFT = x10)";
		tab.addComponent(hint);

		return tab;
	}

	function createPropertiesTab():VBox
	{
		var tab = new VBox();
		tab.text = "Properties";
		tab.percentWidth = 100;
		tab.percentHeight = 100;

		addSectionTitle(tab, "General");

		nameField = addTextProperty(tab, "Name", function(value)
		{
			if (data == null || data.name == value)
				return;

			data.name = value;
		});

		addSectionTitle(tab, "Position");

		posXField = addNumberProperty(tab, "X", function(value)
		{
			if (data == null || data.position[0] == value)
				return;

			data.position[0] = value;
			positionChar();
		});

		posYField = addNumberProperty(tab, "Y", function(value)
		{
			if (data == null || data.position[1] == value)
				return;

			data.position[1] = value;
			positionChar();
		});

		addSectionTitle(tab, "Display");

		scaleField = addNumberProperty(tab, "Scale", function(value)
		{
			if (data == null || value <= 0 || data.display.scale == value)
				return;

			data.display.scale = value;
			rebuildCharacter();
		});

		aaCheck = addBoolProperty(tab, "Antialiasing", function(value)
		{
			if (data == null || data.display.antialiasing == value)
				return;

			data.display.antialiasing = value;

			if (char != null)
				char.antialiasing = value;
		});

		flipCheck = addBoolProperty(tab, "Flip X", function(value)
		{
			if (data == null || data.display.flipX == value)
				return;

			data.display.flipX = value;
			rebuildCharacter();
		});

		addSectionTitle(tab, "Behaviour");

		playerCheck = addBoolProperty(tab, "Is player character", function(value)
		{
			if (data == null || data.behaviour.isPlayerCharacter == value)
				return;

			data.behaviour.isPlayerCharacter = value;
			rebuildCharacter();
		});

		return tab;
	}

	function addSectionTitle(parent:VBox, title:String):Void
	{
		var label = new Label();
		label.text = title;
		parent.addComponent(label);
	}

	// The add*Property helpers build an empty widget and hand it back, refreshPropertiesUI()
	// fills them from `data` (that's what keeps them correct when you switch characters).

	function addTextProperty(parent:VBox, title:String, onChange:String->Void):TextField
	{
		addSectionTitle(parent, title);

		var field = new TextField();
		field.width = 250;

		field.onChange = function(_)
		{
			if (settingUI)
				return;

			onChange(field.text);
		};

		parent.addComponent(field);

		return field;
	}

	function addNumberProperty(parent:VBox, title:String, onChange:Float->Void):TextField
	{
		addSectionTitle(parent, title);

		var field = new TextField();
		field.width = 250;

		field.onChange = function(_)
		{
			if (settingUI)
				return;

			var parsed = Std.parseFloat(field.text);

			if (Math.isNaN(parsed))
				return;

			onChange(parsed);
		};

		parent.addComponent(field);

		return field;
	}

	function addBoolProperty(parent:VBox, title:String, onChange:Bool->Void):CheckBox
	{
		var checkbox = new CheckBox();
		checkbox.text = title;

		checkbox.onChange = function(_)
		{
			if (settingUI)
				return;

			onChange(checkbox.selected);
		};

		parent.addComponent(checkbox);

		return checkbox;
	}

	function setupDropdownDataSource(dropdown:DropDown, items:Array<Dynamic>, currentVal:String):Void
	{
		var prev = settingUI;
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

		settingUI = prev;
	}

	function refreshAllUI():Void
	{
		refreshPropertiesUI();
		refreshAnimUI();
		refreshAtlasLabel();
	}

	// Properties tab <- data
	function refreshPropertiesUI():Void
	{
		if (nameField == null || data == null)
			return;

		var prev = settingUI;
		settingUI = true;

		nameField.text = (data.name != null) ? Std.string(data.name) : "";
		posXField.text = Std.string(data.position[0]);
		posYField.text = Std.string(data.position[1]);
		scaleField.text = Std.string(data.display.scale);
		aaCheck.selected = data.display.antialiasing == true;
		flipCheck.selected = data.display.flipX == true;
		playerCheck.selected = data.behaviour.isPlayerCharacter == true;

		settingUI = prev;
	}

	// Animation dropdown + the selected animation's fields
	function refreshAnimUI():Void
	{
		if (animDropdown == null)
			return;

		var items:Array<Dynamic> = [for (a in animList) {text: a, id: a}];
		setupDropdownDataSource(animDropdown, items, animList.length > 0 ? animList[curAnim] : "");

		refreshAnimFields();
		updateOffsetLabel();
	}

	// Animations tab fields <- the selected animation's json entry
	function refreshAnimFields():Void
	{
		if (prefixField == null)
			return;

		var anim = curAnimData();
		var has:Bool = anim != null;
		var isIndices:Bool = has && anim.type == "indices";

		var prev = settingUI;
		settingUI = true;

		animNameField.text = has ? Std.string(anim.name) : "";
		prefixField.text = (has && anim.prefix != null) ? Std.string(anim.prefix) : "";
		fpsField.text = has ? Std.string(anim.fps) : "";
		loopCheck.selected = has && anim.loop == true;
		typeDropdown.selectedIndex = isIndices ? 1 : 0;

		if (isIndices && anim.frames != null)
		{
			var fr:Array<Dynamic> = anim.frames;
			indicesField.text = fr.join(", ");
		}
		else
			indicesField.text = "";

		indicesField.disabled = !isIndices;

		settingUI = prev;
	}

	// Fill the "pick from atlas" dropdown (no selection, it's a menu).
	function refreshPrefixPicker():Void
	{
		if (prefixPicker == null)
			return;

		var prev = settingUI;
		settingUI = true;

		var ds = new ArrayDataSource<Dynamic>();

		for (p in atlasPrefixes)
			ds.add({text: p, id: p});

		prefixPicker.dataSource = ds;
		prefixPicker.selectedIndex = -1;

		settingUI = prev;
	}

	function updateOffsetLabel():Void
	{
		if (offsetLabel == null)
			return;

		var anim = curAnimData();
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

	function curAnimData():Dynamic
	{
		return getAnimData(currentAnimName());
	}

	function playCurAnim():Void
	{
		if (char == null || animList.length == 0)
			return;

		char.playAnim(currentAnimName(), true);
		updateOffsetLabel();
	}

	/**
	 * Push one edited json entry onto the live Character (no atlas reload) and replay it.
	 * Goes through CharacterLoader.addAnimation, the same code the game uses.
	 */
	function reapplyAnim(anim:Dynamic):Void
	{
		if (char == null)
			return;

		if (!CharacterLoader.addAnimation(char, anim))
		{
			setStatus('"${anim.name}": no frames match that, the preview still shows the old one. Fix it before saving!', FlxColor.RED);
			return;
		}

		setStatus('Updated "${anim.name}"', FlxColor.WHITE);
		playCurAnim();
	}

	/**
	 * Flixel's addByPrefix matches every frame that STARTS with the prefix, so "BF NOTE UP"
	 * would also swallow "BF NOTE UP MISS". When a picked prefix is the start of another
	 * prefix in the atlas, add a "0" (frames are named prefix + 0000, 0001...) so it only
	 * matches its own frames. That's the trick the stock bf.json uses ("BF NOTE UP0").
	 * Indices animations build exact frame names, so they never need it.
	 */
	function disambiguatePrefix(prefix:String, anim:Dynamic):String
	{
		if (anim.type == "indices")
			return prefix;

		for (other in atlasPrefixes)
		{
			if (other != prefix && StringTools.startsWith(other, prefix))
				return prefix + "0";
		}

		return prefix;
	}

	// "0-12, 30" -> [0..12, 30]. Returns null if any part isn't understandable.
	function parseIndices(text:String):Array<Int>
	{
		var out:Array<Int> = [];

		for (part in text.split(","))
		{
			var p = StringTools.trim(part);

			if (p == "")
				continue;

			var dash = p.indexOf("-", 1);

			if (dash > 0)
			{
				var a = Std.parseInt(StringTools.trim(p.substr(0, dash)));
				var b = Std.parseInt(StringTools.trim(p.substr(dash + 1)));

				if (a == null || b == null)
					return null;

				var from:Int = a;
				var to:Int = b;

				if (from <= to)
				{
					for (i in from...(to + 1))
						out.push(i);
				}
				else
				{
					var i:Int = from;

					while (i >= to)
					{
						out.push(i);
						i--;
					}
				}
			}
			else
			{
				var v = Std.parseInt(p);

				if (v == null)
					return null;

				var vi:Int = v;
				out.push(vi);
			}
		}

		return out;
	}

	function sameInts(a:Dynamic, b:Array<Int>):Bool
	{
		var arr:Array<Dynamic> = a;

		if (arr == null || arr.length != b.length)
			return false;

		for (i in 0...b.length)
		{
			if (arr[i] != b[i])
				return false;
		}

		return true;
	}

	function addNewAnimation():Void
	{
		if (data == null)
			return;

		var anims:Array<Dynamic> = data.animations;

		var base:String = "newAnim";
		var name:String = base;
		var count:Int = 2;

		while (getAnimData(name) != null)
		{
			name = base + count;
			count++;
		}

		var entry:Dynamic = {
			name: name,
			prefix: (atlasPrefixes.length > 0) ? atlasPrefixes[0] : "",
			fps: 24,
			loop: false,
			offset: [0, 0]
		};

		anims.push(entry);
		animList.push(name);
		curAnim = animList.length - 1;

		if (char != null)
			CharacterLoader.addAnimation(char, entry);

		refreshAnimUI();
		playCurAnim();
		setStatus('Added "$name", pick a prefix for it', FlxColor.WHITE);
	}

	function removeCurrentAnimation():Void
	{
		var name = currentAnimName();
		var anim = getAnimData(name);

		if (anim == null)
			return;

		var anims:Array<Dynamic> = data.animations;
		anims.remove(anim);

		if (curAnim >= anims.length)
			curAnim = anims.length - 1;

		if (curAnim < 0)
			curAnim = 0;

		// Flixel has no clean "forget this animation" for the live sprite, so just rebuild.
		rebuildCharacter();
		setStatus('Removed "$name"', FlxColor.ORANGE);
	}

	function renameCurrentAnimation():Void
	{
		var anim = curAnimData();

		if (anim == null)
			return;

		var newName = StringTools.trim(animNameField.text);

		if (newName == "")
		{
			setStatus("Animation name can't be empty", FlxColor.RED);
			return;
		}

		if (newName == anim.name)
			return;

		if (getAnimData(newName) != null)
		{
			setStatus('There is already an animation called "$newName"', FlxColor.RED);
			return;
		}

		var oldName:String = anim.name;
		anim.name = newName;

		// Same index, new name, so curAnim stays valid after the rebuild.
		rebuildCharacter();
		setStatus('Renamed "$oldName" to "$newName" (the game looks animations up by name!)', FlxColor.WHITE);
	}

	function nudgeOffset(dx:Int, dy:Int):Void
	{
		var name = currentAnimName();
		var anim = getAnimData(name);

		if (anim == null || char == null)
			return;

		// Keep the json entry and the live Character in step.
		anim.offset[0] += dx;
		anim.offset[1] += dy;
		char.addOffset(name, anim.offset[0], anim.offset[1]);

		playCurAnim();
	}

	// =========================================================
	// NEW CHARACTER + ATLAS
	// =========================================================

	function hasAtlas():Bool
	{
		return data != null && data.atlas != null && data.atlas.image != null && data.atlas.image != "";
	}

	function fileNameOf(path:String):String
	{
		return path.substr(path.lastIndexOf("/") + 1);
	}

	function refreshAtlasLabel():Void
	{
		if (atlasLabel == null)
			return;

		atlasLabel.text = hasAtlas() ? fileNameOf(data.atlas.image) : "(none yet, pick a PNG)";
	}

	// Rebuild the character list, making sure the character we're editing is in it even if it
	// hasn't been saved yet (or was just saved and Polymod's file list hasn't noticed).
	function syncCharDropdown():Void
	{
		if (charDropdown == null)
			return;

		var items:Array<Dynamic> = getCharacterList();
		var found:Bool = false;

		for (item in items)
		{
			if (item.id == charId)
				found = true;
		}

		if (!found && data != null)
			items.push({text: data.name, id: charId});

		setupDropdownDataSource(charDropdown, items, charId);
	}

	/**
	 * Starts a brand new character from a blank template: idle + the four sings, no atlas yet.
	 * Nothing is written to disk until Save. Next step is "Pick PNG...".
	 */
	function newFromTemplate():Void
	{
		var id:String = StringTools.trim(newIdField.text);

		if (id == "")
		{
			setStatus("Type an id for the new character first (it's the json's file name)", FlxColor.RED);
			return;
		}

		var validId = ~/^[A-Za-z0-9_-]+$/;

		if (!validId.match(id))
		{
			setStatus("The id can only use letters, numbers, - and _", FlxColor.RED);
			return;
		}

		var taken:Bool = modId != "" && FileSystem.exists('mods/$modId/data/characters/$id.json');

		for (item in getCharacterList())
		{
			if (item.id == id)
				taken = true;
		}

		if (taken)
		{
			setStatus('"$id" already exists, pick a different id (or load it from the list)', FlxColor.RED);
			return;
		}

		var anims:Array<Dynamic> = [];

		for (animName in ["idle", "singLEFT", "singDOWN", "singUP", "singRIGHT"])
			anims.push({name: animName, prefix: "", fps: 24, loop: false, offset: [0, 0]});

		data = {
			name: id,
			position: [0, 0],
			atlas: {image: "", xml: ""},
			display: {antialiasing: true, flipX: false, scale: 1},
			behaviour: {isPlayerCharacter: false},
			animations: anims
		};

		charId = id;
		curAnim = 0;

		buildCharacter(true); // no atlas yet, so this just sets up the animation list
		refreshAllUI();
		syncCharDropdown();

		setStatus('Created "$id" from the template. Next: Pick PNG...', FlxColor.LIME);
	}

	function pickPng():Void
	{
		if (data == null)
		{
			setStatus("Load or create a character first", FlxColor.RED);
			return;
		}

		// Kept in a field so it can't be garbage collected before the user answers.
		fileDialog = new FileDialog();
		fileDialog.onSelect.add(onPngPicked);
		fileDialog.browse(FileDialogType.OPEN, "png", null, "Pick the character's spritesheet (its .xml must be next to it)");
	}

	function onPngPicked(rawPath:String):Void
	{
		if (data == null || rawPath == null)
			return;

		var src:String = StringTools.replace(rawPath, "\\", "/");

		if (!StringTools.endsWith(src.toLowerCase(), ".png"))
		{
			setStatus("That isn't a .png", FlxColor.RED);
			return;
		}

		var noExt:String = src.substr(0, src.length - 4);
		var baseName:String = fileNameOf(noExt);
		var atlasExt:String = "";

		if (FileSystem.exists(noExt + ".xml"))
			atlasExt = "xml";
		else if (FileSystem.exists(noExt + ".txt"))
			atlasExt = "txt";

		if (atlasExt == "")
		{
			setStatus('No $baseName.xml next to the png. Put the xml in the same folder with the same name, then pick again.', FlxColor.RED);
			return;
		}

		var pngKey:String = keyInsideGame(src);
		var how:String = "already in the game folder";

		if (pngKey == null)
		{
			var dir:String = imageDestDir();

			if (dir == null)
			{
				setStatus('No mod selected, so there is nowhere to copy the png to (mods/modList.txt is empty or missing)', FlxColor.RED);
				return;
			}

			try
			{
				var name:String = freeImageName(dir, baseName, atlasExt, src, noExt);
				var pngDest:String = '$dir/$name.png';
				var atlasDest:String = '$dir/$name.$atlasExt';

				ensureDir(dir);

				// freeImageName only returns a name where neither file exists yet, or where both
				// are already byte-for-byte the same as the ones we picked.
				if (!FileSystem.exists(pngDest))
				{
					File.copy(src, pngDest);
					File.copy(noExt + "." + atlasExt, atlasDest);
				}

				pngKey = 'assets/images/characters/$name.png';
				how = 'copied to $dir' + ((name != baseName) ? ' as $name, since a different $baseName was already there' : "");
			}
			catch (e:Dynamic)
			{
				setStatus('Could not copy the atlas: $e', FlxColor.RED);
				return;
			}
		}

		var atlasKey:String = pngKey.substr(0, pngKey.length - 4) + "." + atlasExt;

		// Drop the old preview first so Flixel's image cache can let go of the file, otherwise
		// re-picking a re-exported png under the same name would keep showing the old art.
		if (char != null)
		{
			remove(char, true);
			char.destroy();
			char = null;
		}

		FlxG.bitmap.removeByKey(pngKey);

		var atlas:Dynamic = {image: pngKey};

		if (atlasExt == "xml")
			atlas.xml = atlasKey;
		else
			atlas.txt = atlasKey;

		data.atlas = atlas;

		buildCharacter(true);
		refreshAllUI();

		if (char == null)
		{
			if (saveTarget == SaveTarget.Assets)
				setStatus('Copied into assets/, but the game\'s asset list is made at compile time: rebuild to see it (the Mods target shows up straight away)', FlxColor.ORANGE);

			return;
		}

		var filled:Int = autoFillPrefixes();

		refreshAnimFields();
		playCurAnim();

		var msg:String = 'Using $pngKey ($how)';

		if (filled > 0)
			msg += ", auto-matched " + filled + " prefix(es), check them in the Animations tab";

		setStatus(msg, FlxColor.LIME);
	}

	// If the png is already somewhere the game loads from, work out its asset key instead of copying it.
	function keyInsideGame(path:String):String
	{
		var cwd:String = StringTools.replace(Sys.getCwd(), "\\", "/");

		if (!StringTools.endsWith(cwd, "/"))
			cwd += "/";

		if (!StringTools.startsWith(path.toLowerCase(), cwd.toLowerCase()))
			return null;

		var rel:String = path.substr(cwd.length);
		var lower:String = rel.toLowerCase();

		if (StringTools.startsWith(lower, "assets/images/"))
			return rel;

		// mods/<mod>/images/x.png overlays assets/images/x.png
		if (StringTools.startsWith(lower, "mods/"))
		{
			var parts = rel.split("/");

			if (parts.length > 3 && parts[2].toLowerCase() == "images")
				return "assets/images/" + parts.slice(3).join("/");
		}

		return null;
	}

	// Same overlay rule the json uses: assets/... or mods/<mod>/... (null = no mod to put it in).
	function imageDestDir():String
	{
		if (saveTarget == SaveTarget.Assets)
			return "assets/images/characters";

		if (modId == "")
			return null;

		return 'mods/$modId/images/characters';
	}

	// Never overwrite a DIFFERENT file that happens to share the name: try name-2, name-3, ...
	function freeImageName(dir:String, baseName:String, ext:String, srcPng:String, srcNoExt:String):String
	{
		var name:String = baseName;

		for (n in 2...1000)
		{
			var pngDest:String = '$dir/$name.png';
			var atlasDest:String = '$dir/$name.$ext';

			if (!FileSystem.exists(pngDest) && !FileSystem.exists(atlasDest))
				return name;

			if (FileSystem.exists(pngDest) && FileSystem.exists(atlasDest) && sameFile(srcPng, pngDest) && sameFile(srcNoExt + "." + ext, atlasDest))
				return name;

			name = baseName + "-" + n;
		}

		return name;
	}

	function sameFile(a:String, b:String):Bool
	{
		var x = File.getBytes(a);
		var y = File.getBytes(b);

		return x.length == y.length && x.compare(y) == 0;
	}

	/**
	 * For animations that still have no prefix, look through the atlas for ONE obvious match:
	 * idle -> "...idle...", singLEFT -> "...left...", and so on (whole words only, never anything
	 * with "miss" in it). Anything ambiguous is left alone for you to pick. Returns how many it filled.
	 */
	function autoFillPrefixes():Int
	{
		if (char == null)
			return 0;

		var splitter = ~/[^a-z0-9]+/g;
		var filled:Int = 0;
		var anims:Array<Dynamic> = data.animations;

		for (anim in anims)
		{
			if (anim.prefix != null && anim.prefix != "")
				continue;

			var keyword:String = switch (Std.string(anim.name).toLowerCase())
			{
				case "idle": "idle";
				case "singleft": "left";
				case "singdown": "down";
				case "singup": "up";
				case "singright": "right";
				default: null;
			};

			if (keyword == null)
				continue;

			var found:String = null;
			var count:Int = 0;

			for (p in atlasPrefixes)
			{
				var words = splitter.split(p.toLowerCase());

				if (words.indexOf(keyword) == -1 || words.indexOf("miss") != -1)
					continue;

				found = p;
				count++;
			}

			if (count != 1)
				continue;

			anim.prefix = disambiguatePrefix(found, anim);
			CharacterLoader.addAnimation(char, anim);
			filled++;
		}

		return filled;
	}

	// =========================================================
	// SAVING
	// =========================================================

	function saveCharacter():Void
	{
		if (data == null)
			return;

		if (!hasAtlas())
		{
			setStatus("Pick a PNG first, a character with no atlas would crash the game when it loads", FlxColor.RED);
			return;
		}

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
			var noPrefix:Int = 0;
			var savedAnims:Array<Dynamic> = data.animations;

			for (anim in savedAnims)
			{
				if (anim.prefix == null || anim.prefix == "")
					noPrefix++;
			}

			if (noPrefix > 0)
				setStatus('Saved $path ($noPrefix animation(s) still have no prefix!)', FlxColor.ORANGE);
			else
				setStatus('Saved $path', FlxColor.LIME);

			syncCharDropdown();
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
				FlxG.camera.zoom = Math.max(0.25, FlxG.camera.zoom - 0.25);

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
				var changed:Bool = false;

				if (FlxG.keys.justPressed.W)
				{
					curAnim--;
					changed = true;
				}
				if (FlxG.keys.justPressed.S)
				{
					curAnim++;
					changed = true;
				}

				if (curAnim < 0)
					curAnim = animList.length - 1;
				if (curAnim >= animList.length)
					curAnim = 0;

				if (changed)
				{
					playCurAnim();
					refreshAnimUI();
				}
				else if (FlxG.keys.justPressed.SPACE)
					playCurAnim();

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
