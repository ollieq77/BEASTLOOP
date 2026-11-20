package;

import Section.SwagSection;
import Song.SwagSong;
import WiggleEffect.WiggleEffectType;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.effects.FlxTrail;
import flixel.addons.effects.FlxTrailArea;
import flixel.addons.effects.chainable.FlxEffectSprite;
import flixel.addons.effects.chainable.FlxWaveEffect;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.atlas.FlxAtlas;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxCollision;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import haxe.Json;
import openfl.utils.Assets;
import openfl.display.BlendMode;
import openfl.display.StageQuality;
import openfl.filters.ShaderFilter;
import openfl.media.Sound;
import polymod.backends.PolymodAssets;

import Stage;
import StageLoader;

using StringTools;

class PlayState extends MusicBeatState
{

	// SONG SETTINGS
	public static var botPlay:Bool = false;
	public static var opponentNoteFlashes:Bool = true;
	public static var sustainAnimations:Bool = false;
	public static var downscroll:Bool = false;
	public static var vanillaStrumOffset:Bool = false;
	public static var sustainClipping:Bool = true;
	public static var classicScoreTxt:Bool = false;
	public static var ghostTapping:Bool = false;

	public static var curStage:String = '';
	public static var SONG:SwagSong;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	public var scoreSystem:ScoreSystem;

	var stage:Stage;
	var stageScript:StageScript;

	// Optional per-song script (assets/songs/<song>/song.hxc). Same API as the stage script.
	var songScript:StageScript;

	// Runs a hook on the stage script, then the song script (the song is more specific, so it gets the last word).
	function callScripts(func:String, ?args:Array<Dynamic>):Void
	{
		if (stageScript != null)
			stageScript.call(func, args);

		if (songScript != null)
			songScript.call(func, args);
	}

	function setScriptVariable(name:String, value:Dynamic):Void
	{
		if (stageScript != null)
			stageScript.setVariable(name, value);

		if (songScript != null)
			songScript.setVariable(name, value);
	}

	function configureScript(script:StageScript):Void
	{
	    script.api.state = this;
	    script.api.startCountdownFn = startCountdown;
		script.api.inst = inst;
	    script.api.setCutsceneFn = function(value:Bool)
	    {
	        inCutscene = value;
	    };

	    script.api.setGfSpeedFn = function(value:Int)
	    {
	        gfSpeed = value;
	    };

	    script.api.setVocalsVolumeFn = function(value:Float)
	    {
	        if (vocals != null)
	            vocals.volume = value;
	    };

	    script.api.setMusicVolumeFn = function(value:Float)
	    {
	        if (inst != null)
    			inst.volume = value;
	    };

	    script.api.setCamZoomingFn = function(value:Bool)
	    {
	        camZooming = value;
	    };

		script.api.getCamZoomingFn = function()
		{
		    return camZooming;
		};

	    script.api.addCameraZoomFn = function(game:Float, hud:Float)
	    {
	        camGame.zoom += game;
	        camHUD.zoom += hud;
	    };

		script.api.loadDialogueFn = function(file:String)
		{
		    dialogue = CoolUtil.coolTextFile(Paths.song(SONG.song.toLowerCase()) + file);
		};
	}

	private var vocals:FlxSound;
	private var inst:FlxSound;

	private var dad:Character;
	private var gf:Character;
	private var boyfriend:Boyfriend;

	private var notes:FlxTypedGroup<Note>;
	private var unspawnNotes:Array<Note> = [];

	var previousStrumAnimations:haxe.ds.ObjectMap<FlxSprite, String> = new haxe.ds.ObjectMap();

	private var strumLine:FlxSprite;
	private var curSection:Int = 0;

	private var camFollow:FlxObject;

	private static var prevCamFollow:FlxObject;

	var strumLineNotes:FlxTypedGroup<FlxSprite>;
	var playerStrums:FlxTypedGroup<FlxSprite>;
	var opponentStrums:FlxTypedGroup<FlxSprite>;

	private var camZooming:Bool = true;
	var camTarget:Int = -1; // -1 = unset, 0 = dad, 1 = bf
	private var curSong:String = "";

	private var gfSpeed:Int = 1;
	private var health:Float = 1;
	private var combo:Int = 0;

	private var healthBarBG:FlxSprite;
	private var healthBar:FlxBar;

	private var generatedMusic:Bool = false;
	private var startingSong:Bool = false;

	private var iconP1:HealthIcon;
	private var iconP2:HealthIcon;
	private var camHUD:HudCamera;
	private var camGame:FlxCamera;

	var dialogue:Array<String> = ['blah blah blah', 'coolswag'];


	var wiggleShit:WiggleEffect = new WiggleEffect();

	var talking:Bool = true;
	var scoreTxt:FlxText;
	var scoreTxtScale:Float = 1;

	public static var campaignScore:Int = 0;

	var defaultCamZoom:Float = 1.05;

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;

	// Set from the stage's "pixel" key. Notes, countdown and game over read this.
	public static var isPixelStage:Bool = false;

	var inCutscene:Bool = false;

	function showCountdownSprite(image:String):Void
	{
	    var sprite:FlxSprite = new FlxSprite().loadGraphic(Paths.graphic(Paths.image(image)));
	    sprite.scrollFactor.set();

	    if (isPixelStage)
	        sprite.setGraphicSize(Std.int(sprite.width * daPixelZoom));

	    sprite.updateHitbox();
	    sprite.screenCenter();

	    add(sprite);

	    FlxTween.tween(sprite, {y: sprite.y + 100, alpha: 0}, Conductor.crochet / 1000, {
	        ease: FlxEase.cubeInOut,
	        onComplete: function(twn:FlxTween)
	        {
	            sprite.destroy();
	        }
	    });
	}

	override public function create()
	{
		// var gameCam:FlxCamera = FlxG.camera;
		camGame = new FlxCamera();
		camHUD = new HudCamera();

		scoreSystem = new ScoreSystem();

		camHUD.downscroll = downscroll;
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD);

		FlxCamera.defaultCameras = [camGame];

		persistentUpdate = true;
		persistentDraw = true;

		if (SONG == null)
			SONG = Song.loadFromJson('hard', 'tutorial');

		Conductor.changeBPM(SONG.bpm);

		// store song name temporarily

		var song = SONG.song.toLowerCase();

		if (SONG.stage != null && SONG.stage.length > 0)
		    curStage = SONG.stage;
		else
		    curStage = 'stage';

		stage = StageLoader.load(curStage);
		defaultCamZoom = stage.defaultCamZoom;
		isPixelStage = stage.isPixel;


		add(stage.members);

		stageScript = new StageScript(
		    stage,
		    Paths.stageScript(curStage)
		);
		
		configureScript(stageScript);
		
		if (stageScript.load())
		{
		    stageScript.api.setCameras(camGame, camHUD);
		    stageScript.call("onCreate");
		}

		// Most songs won't have one, so only create it when the file exists.
		if (Paths.exists(Paths.songScript(SONG.song)))
		{
		    songScript = new StageScript(
		        stage,
		        Paths.songScript(SONG.song),
		        "SongScript"
		    );
			
		    configureScript(songScript);
			
		    if (songScript.load())
		    {
		        songScript.api.setCameras(camGame, camHUD);
		        songScript.call("onCreate");
		    }
		}

		var gfVersion = SONG.gfVersion != null && SONG.gfVersion.length > 0 ? SONG.gfVersion : stage.gfVersion;

		gf = new Character(400, 130, gfVersion);
		placeCharacter(gf, stage.gfPosition);
		gf.scrollFactor.set(0.95, 0.95);

		dad = new Character(100, 100, SONG.player2, false, true);
		placeCharacter(dad, stage.dadPosition);

		// Story-mode tutorial opens the camera shifted toward the middle.
		var introCamX:Float = 0;

		switch (SONG.player2)
		{
			case 'gf':
				dad.setPosition(gf.x, gf.y);
				gf.visible = false;
				if (isStoryMode)
				{
					introCamX = 600;
					tweenCamIn();
				}
		}
		boyfriend = new Boyfriend(770, 450, SONG.player1);
		placeCharacter(boyfriend, stage.boyfriendPosition);

		stageScript.api.setCharacters(boyfriend, dad, gf);

		if (songScript != null)
			songScript.api.setCharacters(boyfriend, dad, gf);

		add(gf);
		add(dad);
		add(boyfriend);

		callScripts("onCreatePost");

		var doof:DialogueBox = new DialogueBox(false, dialogue);
		// doof.x += 70;
		// doof.y = FlxG.height * 0.5;
		doof.scrollFactor.set();
		doof.finishThing = startCountdown;
		callScripts("onDialogueCreate", [doof]);

		Conductor.songPosition = -5000;

		strumLine = new FlxSprite(0, 50).makeGraphic(FlxG.width, 10);
		strumLine.scrollFactor.set();

		strumLineNotes = new FlxTypedGroup<FlxSprite>();
		add(strumLineNotes);

		playerStrums = new FlxTypedGroup<FlxSprite>();
		opponentStrums = new FlxTypedGroup<FlxSprite>();

		// startCountdown();

		generateSong(SONG.song);

		// add(strumLine);

		camFollow = new FlxObject(0, 0, 1, 1);

		var startCam = getCamTarget(false);
		camFollow.setPosition(startCam.x + introCamX, startCam.y);
		startCam.put();

		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}

		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0.04);
		// FlxG.camera.setScrollBounds(0, FlxG.width, 0, FlxG.height);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.focusOn(camFollow.getPosition());

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		FlxG.fixedTimestep = false;

		healthBarBG = new FlxSprite(0, FlxG.height * 0.9).loadGraphic(Paths.graphic(Paths.image('gameplay/healthBar')));
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		add(healthBarBG);

		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), this,
			'health', 0, 2);
		healthBar.scrollFactor.set();
		healthBar.createFilledBar(0xFFFF0000, 0xFF66FF33);
		// healthBar
		add(healthBar);

		// Original scoreTxt positioning (vanilla FNF)

		if (classicScoreTxt) {
			scoreTxt = new FlxText(healthBarBG.x + healthBarBG.width - 190, healthBarBG.y + 30, 0, "", 20);
			scoreTxt.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, RIGHT);
		} else {
			scoreTxt = new FlxText(0, healthBarBG.y + 30, FlxG.width, "", 24);
			scoreTxt.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		}

		scoreTxt.scrollFactor.set();
		add(scoreTxt);

		iconP1 = new HealthIcon(SONG.player1, true);
		iconP1.y = healthBar.y - (iconP1.height / 2);
		add(iconP1);

		iconP2 = new HealthIcon(SONG.player2, false);
		iconP2.y = healthBar.y - (iconP2.height / 2);
		add(iconP2);

		strumLineNotes.cameras = [camHUD];
		notes.cameras = [camHUD];
		healthBar.cameras = [camHUD];
		healthBarBG.cameras = [camHUD];
		iconP1.cameras = [camHUD];
		iconP2.cameras = [camHUD];
		scoreTxt.cameras = [camHUD];
		doof.cameras = [camHUD];

		// if (SONG.song == 'South')
		// FlxG.camera.alpha = 0.7;
		// UI_camera.zoom = 1;

		// cameras = [FlxG.cameras.list[1]];
		startingSong = true;

		// The song or stage script can take over the intro (cutscenes, dialogue...) by returning true.
		// If it does, it is responsible for calling api.startCountdown() when it's done.
		// The song script gets first dibs, and if it takes over, the stage's onIntro doesn't run.
		stageScript.api.camFollow = camFollow;

		if (songScript != null)
			songScript.api.camFollow = camFollow;

		var introHandled:Bool = (songScript != null && songScript.call("onIntro", [doof]) == true)
			|| stageScript.call("onIntro", [doof]) == true;

		if (!introHandled)
			startCountdown();

		super.create();
	}

	var startTimer:FlxTimer;
	var perfectMode:Bool = false;

	function startCountdown():Void
	{
		inCutscene = false;

		generateStaticArrows(0);
		generateStaticArrows(1);

		talking = false;
		startedCountdown = true;
		Conductor.songPosition = 0;
		Conductor.songPosition -= Conductor.crochet * 5;

		var swagCounter:Int = 0;

		startTimer = new FlxTimer().start(Conductor.crochet / 1000, function(tmr:FlxTimer)
		{
			dad.dance();
			gf.dance();
			boyfriend.playAnim('idle');

			var introAlts:Array<String> = ['gameplay/ready', 'gameplay/set', 'gameplay/go'];
			var altSuffix:String = "";

			if (isPixelStage)
			{
				introAlts = [
					'weeb/pixelUI/ready-pixel',
					'weeb/pixelUI/set-pixel',
					'weeb/pixelUI/date-pixel'
				];
				altSuffix = '-pixel';
			}

			switch (swagCounter)
			{
			    case 0:
			        FlxG.sound.play(Paths.sound('intro3' + altSuffix), 0.6);
			
			    case 1:
			        showCountdownSprite(introAlts[0]);
			        FlxG.sound.play(Paths.sound('intro2' + altSuffix), 0.6);
			
			    case 2:
			        showCountdownSprite(introAlts[1]);
			        FlxG.sound.play(Paths.sound('intro1' + altSuffix), 0.6);
			
			    case 3:
					if (boyfriend != null && boyfriend.animation.getByName('hey') != null)
					    boyfriend.playAnim('hey', true);
					
					if (gf != null && gf.animation.getByName('cheer') != null)
					    gf.playAnim('cheer', true);
				
			        showCountdownSprite(introAlts[2]);
			        FlxG.sound.play(Paths.sound('introGo' + altSuffix), 0.6);

			    case 4:
			}

			swagCounter += 1;
			// generateSong('fresh');
		}, 5);
	}

	var previousFrameTime:Int = 0;
	var lastReportedPlayheadPosition:Int = 0;
	var songTime:Float = 0;

	function startSong():Void
	{
		startingSong = false;

		previousFrameTime = FlxG.game.ticks;
		lastReportedPlayheadPosition = 0;

		if (inst != null)
		{
		    inst.onComplete = endSong;
		    inst.play();
		
		    vocals.play();
		    resetSongClock(inst.time - Conductor.offset);
		}

		callScripts("onSongStart");
	}

	// ---- SONG CLOCK ----
	// songPosition = clockRaw + clockOffset
	//   clockRaw    only ever advances by elapsed time (smooth, never jumps)
	//   clockOffset a smoothed correction that locks the clock to the audio
	// The audio clock is not trusted reading by reading: it can update in chunks, so a reading is
	// always a little late and averaging them would leave the song clock permanently behind.
	// A reading can never be *ahead* of the truth, so the offset follows the best (largest)
	// recent reading instead, which cancels that lag out.
	var clockRaw:Float = 0;
	var clockOffset:Float = 0;
	var lastAudioTime:Float = -1;
	var clockSampleT:Array<Float> = [];
	var clockSampleD:Array<Float> = [];

	// somehow the original code made the song time DRIFT, this should fix it (its so fucking annoying)

	static inline var CLOCK_WINDOW:Float = 400; // ms of readings that get compared
	static inline var CLOCK_SNAP:Float = 30; // ms off before we jump instead of easing (seek, lag spike)
	static inline var CLOCK_EASE:Float = 12; // per second, ~83ms to settle, framerate independent

	function resetSongClock(pos:Float):Void
	{
		clockRaw = pos;
		clockOffset = 0;
		lastAudioTime = -1;
		clockSampleT = [];
		clockSampleD = [];
		Conductor.songPosition = pos;
	}

	function updateSongClock(elapsed:Float):Void
	{
		clockRaw += elapsed * 1000;

		var music = inst;
		if (music != null && music.playing)
		{
			var audioTime:Float = music.time - Conductor.offset;

			// only readings that actually changed are new information
			if (audioTime != lastAudioTime)
			{
				lastAudioTime = audioTime;
				clockSampleT.push(clockRaw);
				clockSampleD.push(audioTime - clockRaw);

				while (clockSampleT.length > 0 && clockRaw - clockSampleT[0] > CLOCK_WINDOW)
				{
					clockSampleT.shift();
					clockSampleD.shift();
				}
			}
		}

		if (clockSampleD.length > 0)
		{
			var best:Float = clockSampleD[0];
			for (d in clockSampleD)
				if (d > best)
					best = d;

			var gap:Float = best - clockOffset;
			if (Math.abs(gap) > CLOCK_SNAP)
				clockOffset = best;
			else
				clockOffset += gap * (1 - Math.exp(-elapsed * CLOCK_EASE));
		}

		Conductor.songPosition = clockRaw + clockOffset;
	}

	var debugNum:Int = 0;

	private function generateSong(dataPath:String):Void
	{
		// FlxG.log.add(ChartParser.parse());

		var songData = SONG;
		Conductor.changeBPM(songData.bpm);

		curSong = songData.song;

		if (SONG.needsVoices)
		    vocals = new FlxSound().loadEmbedded(
		        Sound.fromFile(Paths.resolve(Paths.voices(curSong)))
		    );
		else
		    vocals = new FlxSound();

		FlxG.sound.list.add(vocals);

		inst = new FlxSound().loadEmbedded(
		    Sound.fromFile(Paths.resolve(Paths.inst(SONG.song))),
		    false,
		    false
		);
				
		FlxG.sound.list.add(inst);
		if (stageScript != null)
		    stageScript.api.inst = inst;

		if (songScript != null)
		    songScript.api.inst = inst;

		notes = new FlxTypedGroup<Note>();
		add(notes);

		var noteData:Array<SwagSection>;

		// NEW SHIT
		noteData = songData.notes;

		var playerCounter:Int = 0;

		var daBeats:Int = 0; // Not exactly representative of 'daBeats' lol, just how much it has looped
		for (section in noteData)
		{
			var coolSection:Int = Std.int(section.lengthInSteps / 4);

			for (songNotes in section.sectionNotes)
			{
				var daStrumTime:Float = songNotes[0];
				var daNoteData:Int = Std.int(songNotes[1] % 4);

				var gottaHitNote:Bool = section.mustHitSection;

				if (songNotes[1] > 3)
				{
					gottaHitNote = !section.mustHitSection;
				}

				var oldNote:Note;
				if (unspawnNotes.length > 0)
					oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];
				else
					oldNote = null;

				var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote);
				swagNote.sustainLength = songNotes[2];
				swagNote.scrollFactor.set(0, 0);

				swagNote.mustPress = gottaHitNote;
				swagNote.x = getStrumX(daNoteData, swagNote.mustPress ? 1 : 0);
				unspawnNotes.push(swagNote);

				var remainingSustain:Float = swagNote.sustainLength;
				var sustainTime:Float = daStrumTime;

				while (remainingSustain > 0)
				{
				    var stepDuration:Float = getStepDurationAtTime(sustainTime);
				
				    if (remainingSustain + 0.001 < stepDuration)
				        break;
				
				    sustainTime += stepDuration;
				    remainingSustain -= stepDuration;

				    // Chain to the note spawned just before this one (the head for the first piece, the previous
				    // piece after that). Note's constructor uses prevNote to turn the previous piece into a
				    // stretched hold piece, so pointing every piece at swagNote leaves them all as unscaled end caps.
				    oldNote = unspawnNotes[unspawnNotes.length - 1];

				    var sustainNote:Note = new Note(sustainTime, daNoteData, oldNote, true);
				    sustainNote.scrollFactor.set();
				    unspawnNotes.push(sustainNote);

				    sustainNote.mustPress = gottaHitNote;
				    sustainNote.x = getStrumX(daNoteData, sustainNote.mustPress ? 1 : 0)
						+ sustainNote.width
				        + sustainNote.offset.x / 4;
				}
			}
			daBeats += 1;
		}

		// trace(unspawnNotes.length);
		// playerCounter += 1;

		unspawnNotes.sort(sortByShit);

		generatedMusic = true;
	}

	function sortByShit(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}


	// TODO: probably make this modular so we dont hardcode everything
	private function setupNormalArrow(arrow:FlxSprite, direction:Int):Void
	{
	    arrow.frames = Paths.sparrow('gameplay/NOTE_assets');

	    arrow.animation.addByPrefix('green', 'arrowUP');
	    arrow.animation.addByPrefix('blue', 'arrowDOWN');
	    arrow.animation.addByPrefix('purple', 'arrowLEFT');
	    arrow.animation.addByPrefix('red', 'arrowRIGHT');

	    arrow.antialiasing = true;
	    arrow.setGraphicSize(Std.int(arrow.width * 0.7));

	    switch (direction)
	    {
	        case 0:
	            arrow.animation.addByPrefix('static', 'arrowLEFT');
	            arrow.animation.addByPrefix('pressed', 'left press', 24, false);
	            arrow.animation.addByPrefix('confirm', 'left confirm', 24, false);

	        case 1:
	            arrow.animation.addByPrefix('static', 'arrowDOWN');
	            arrow.animation.addByPrefix('pressed', 'down press', 24, false);
	            arrow.animation.addByPrefix('confirm', 'down confirm', 24, false);

	        case 2:
	            arrow.animation.addByPrefix('static', 'arrowUP');
	            arrow.animation.addByPrefix('pressed', 'up press', 24, false);
	            arrow.animation.addByPrefix('confirm', 'up confirm', 24, false);

	        case 3:
	            arrow.animation.addByPrefix('static', 'arrowRIGHT');
	            arrow.animation.addByPrefix('pressed', 'right press', 24, false);
	            arrow.animation.addByPrefix('confirm', 'right confirm', 24, false);
	    }
	}

	private function setupPixelArrow(arrow:FlxSprite, direction:Int):Void
	{
	    arrow.loadGraphic(Paths.graphic(Paths.image('weeb/pixelUI/arrows-pixels')), true, 17, 17);

	    arrow.animation.add('green', [6]);
	    arrow.animation.add('red', [7]);
	    arrow.animation.add('blue', [5]);
	    arrow.animation.add('purplel', [4]);

	    arrow.setGraphicSize(Std.int(arrow.width * daPixelZoom));
	    arrow.antialiasing = false;

	    switch (direction)
	    {
	        case 0:
	            arrow.animation.add('static', [0]);
	            arrow.animation.add('pressed', [4, 8], 12, false);
	            arrow.animation.add('confirm', [12, 16], 24, false);

	        case 1:
	            arrow.animation.add('static', [1]);
	            arrow.animation.add('pressed', [5, 9], 12, false);
	            arrow.animation.add('confirm', [13, 17], 24, false);

	        case 2:
	            arrow.animation.add('static', [2]);
	            arrow.animation.add('pressed', [6, 10], 12, false);
	            arrow.animation.add('confirm', [14, 18], 12, false);

	        case 3:
	            arrow.animation.add('static', [3]);
	            arrow.animation.add('pressed', [7, 11], 12, false);
	            arrow.animation.add('confirm', [15, 19], 24, false);
	    }
	}

	private function generateStaticArrows(player:Int):Void
	{
	    for (i in 0...4)
	    {
	        var babyArrow:FlxSprite = new FlxSprite(0, strumLine.y);
		
	        if (isPixelStage)
	            setupPixelArrow(babyArrow, i);
	        else
	            setupNormalArrow(babyArrow, i);
		
	        babyArrow.updateHitbox();
	        babyArrow.scrollFactor.set();
		
	        babyArrow.y -= 10;
	        babyArrow.alpha = 0;
		
	        FlxTween.tween(babyArrow, {
	            y: babyArrow.y + 10,
	            alpha: 1
	        }, 1, {
	            ease: FlxEase.circOut,
	            startDelay: 0.5 + (0.2 * i)
	        });
		
	        babyArrow.ID = i;
		
			if (player == 0)
			    opponentStrums.add(babyArrow);
			else
			    playerStrums.add(babyArrow);

			strumLineNotes.add(babyArrow);
		
	        babyArrow.animation.play('static');

			babyArrow.x = getStrumX(i, player);

	    }
	}

	function tweenCamIn():Void
	{
		FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut});
	}

	// Stage slot position + the character's own offset from its JSON.
	function placeCharacter(char:Character, slot:Array<Float>):Void
	{
		char.setPosition(slot[0] + char.positionOffset[0], slot[1] + char.positionOffset[1]);
	}

	// Default target + stage camera offset + character camera offset.
	function getCamTarget(onBf:Bool):FlxPoint
	{
		var who:Character = onBf ? boyfriend : dad;
		var stageOff = onBf ? stage.cameraBoyfriend : stage.cameraOpponent;
		var mid = who.getMidpoint();

		var p = FlxPoint.get(
			mid.x + (onBf ? -100 : 150) + stageOff[0] + who.cameraOffset[0],
			mid.y - 100 + stageOff[1] + who.cameraOffset[1]
		);
		mid.put();
		return p;
	}

	override function openSubState(SubState:FlxSubState)
	{
		if (paused)
		{
		    if (inst != null)
		    {
		        inst.pause();
		        vocals.pause();
		    }
		
		    if (!startTimer.finished)
		        startTimer.active = false;
		}

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		if (paused)
		{
			if (inst != null && !startingSong)
			{
				resyncVocals();
			}

			if (!startTimer.finished)
				startTimer.active = true;
			paused = false;
		}

		super.closeSubState();
	}

	function resyncVocals():Void
	{
	    if (inst == null || vocals == null)
	        return;

	    inst.play();

	    var musicTime:Float = inst.time;

	    vocals.pause();
	    vocals.time = musicTime;
	    vocals.play();

	    resetSongClock(musicTime - Conductor.offset);
	}
	override public function usesTempoMap():Bool
	{
	    return true;
	}
	
	override public function getStepAtTime(time:Float):Int
	{
	    var bpm:Float = SONG.bpm;
	    var elapsed:Float = time;
	    var totalSteps:Int = 0;
	
	    // Countdown time uses the base song BPM.
	    if (elapsed < 0)
	    {
	        var stepDuration:Float = 60000 / (bpm * 4);
	        return Std.int(Math.floor(elapsed / stepDuration));
	    }
	
	    for (section in SONG.notes)
	    {
	        if (section.changeBPM && section.bpm > 0)
	            bpm = section.bpm;
		
	        if (section.lengthInSteps <= 0)
	            continue;
		
	        var stepDuration:Float = 60000 / (bpm * 4);
	        var sectionDuration:Float = stepDuration * section.lengthInSteps;
	
	        if (elapsed < sectionDuration)
	        {
	            return totalSteps + Std.int(Math.floor(elapsed / stepDuration));
	        }
		
	        elapsed -= sectionDuration;
	        totalSteps += section.lengthInSteps;
	    }
	
	    // Continue using the last effective BPM beyond the final section.
	    var finalStepDuration:Float = 60000 / (bpm * 4);
	
	    return totalSteps + Std.int(Math.floor(elapsed / finalStepDuration));
	}
	
	override public function getBPMAtStep(step:Int):Int
	{
	    var bpm:Float = SONG.bpm;
	    var totalSteps:Int = 0;

		if (step < 0)
    		return SONG.bpm;
	
	    for (section in SONG.notes)
	    {
	        if (section.changeBPM && section.bpm > 0)
	            bpm = section.bpm;
		
	        if (section.lengthInSteps <= 0)
	            continue;
		
	        if (step < totalSteps + section.lengthInSteps)
	            return Std.int(bpm);
		
	        totalSteps += section.lengthInSteps;
	    }
	
	    return Std.int(bpm);
	}

	function getSectionIndexAtStep(step:Int):Int
	{
	    var totalSteps:Int = 0;

	    for (i in 0...SONG.notes.length)
	    {
	        var sectionLength:Int = SONG.notes[i].lengthInSteps;

	        if (step < totalSteps + sectionLength)
	            return i;

	        totalSteps += sectionLength;
	    }

	    return -1;
	}

	function getStepDurationAtTime(time:Float):Float
	{
	    var bpm:Int = getBPMAtStep(getStepAtTime(time));
	
	    return 60000 / (bpm * 4);
	}

	private var paused:Bool = false;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;

	override public function update(elapsed:Float)
	{
		#if !debug
		perfectMode = false;
		#end

		setScriptVariable("elapsed", elapsed);
		callScripts("onUpdate", [elapsed]);

		// config camera follow lerp to be framerate independent
		// "honestly to god why is follow not framerate independant in flixel" - me, 2026
		FlxG.camera.followLerp = 1 - Math.exp(-elapsed * 2.45);

		super.update(elapsed);

		updateScoreText();

		if (FlxG.keys.justPressed.ENTER && startedCountdown && canPause)
		{
			persistentUpdate = false;
			persistentDraw = true;
			paused = true;

			openSubState(new PauseSubState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
		}

		if (FlxG.keys.justPressed.SEVEN)
		{
			FlxG.switchState(new ChartingState());
		}

		strumLineNotes.forEachAlive(function(spr:FlxSprite)
		{
		    if (spr.animation.curAnim == null) return;

		    var currentAnim = spr.animation.curAnim.name;
		    var previousAnim = previousStrumAnimations.get(spr);

		    if (currentAnim == 'static' && previousAnim == 'confirm')
		        spr.centerOffsets();

		    previousStrumAnimations.set(spr, currentAnim);
		});

		// FlxG.watch.addQuick('VOL', vocals.amplitudeLeft);
		// FlxG.watch.addQuick('VOLRight', vocals.amplitudeRight);

		iconP1.setGraphicSize(Std.int(FlxMath.lerp(150, iconP1.width, Math.exp(-elapsed * 15))));
		iconP2.setGraphicSize(Std.int(FlxMath.lerp(150, iconP2.width, Math.exp(-elapsed * 15))));

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		var iconOffset:Int = 26;

		iconP1.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01) - iconOffset);
		iconP2.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01)) - (iconP2.width - iconOffset);

		if (health > 2)
			health = 2;

		if (healthBar.percent < 20)
			iconP1.animation.curAnim.curFrame = 1;
		else
			iconP1.animation.curAnim.curFrame = 0;

		if (healthBar.percent > 80)
			iconP2.animation.curAnim.curFrame = 1;
		else
			iconP2.animation.curAnim.curFrame = 0;

		opponentStrums.forEachAlive(function(spr:FlxSprite)
		{
		    if (spr.animation.curAnim != null
		        && spr.animation.curAnim.name == 'confirm'
		        && spr.animation.curAnim.finished)
		    {
		        spr.animation.play('static', true);
		        spr.centerOffsets();
		    }
		});

		if (botPlay)
		{
		    playerStrums.forEachAlive(function(spr:FlxSprite)
		    {
		        if (spr.animation.curAnim != null
		            && spr.animation.curAnim.name == 'confirm'
		            && spr.animation.curAnim.finished)
		        {
		            spr.animation.play('static', true);
		            spr.centerOffsets();
		        }
		    });
		}

		/* if (FlxG.keys.justPressed.NINE)
			FlxG.switchState(new Charting()); */
			
		if (FlxG.keys.justPressed.EIGHT)
			FlxG.switchState(new AnimationDebug(SONG.player2));

		if (FlxG.keys.justPressed.NINE)
			FlxG.switchState(new CharacterEditorState(SONG.player2));

		if (startingSong)
		{
			if (startedCountdown)
			{
				Conductor.songPosition += FlxG.elapsed * 1000;
				if (Conductor.songPosition >= 0)
					startSong();
			}
		}
		else
		{
			updateSongClock(FlxG.elapsed);
			FlxG.watch.addQuick("clockOffset", clockOffset);

			if (!paused)
			{
				songTime += FlxG.game.ticks - previousFrameTime;
				previousFrameTime = FlxG.game.ticks;

				// Interpolation type beat
				if (Conductor.lastSongPos != Conductor.songPosition)
				{
					songTime = (songTime + Conductor.songPosition) / 2;
					Conductor.lastSongPos = Conductor.songPosition;
					// Conductor.songPosition += FlxG.elapsed * 1000;
					// trace('MISSED FRAME');
				}
			}

			// Conductor.lastSongPos = FlxG.sound.music.time;
		}

		var sectionIndex:Int = getSectionIndexAtStep(curStep);

		if (generatedMusic && sectionIndex >= 0)
		{
		    var mustHit:Bool = SONG.notes[sectionIndex].mustHitSection;
		    var wanted:Int = mustHit ? 1 : 0;
		
		    if (wanted != camTarget)
		    {
		        camTarget = wanted;
			
		        var camP = getCamTarget(mustHit);
		        camFollow.setPosition(camP.x, camP.y);
		        camP.put();
		    }
		}

		if (camZooming)
		{
			var zoomRatio = Math.pow(0.95, elapsed * 60);
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, zoomRatio);
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, zoomRatio);
		}

		FlxG.watch.addQuick("beatShit", totalBeats);

		// better streaming of shit

		// RESET = Quick Game Over Screen
		if (controls.RESET)
		{
			health = 0;
			trace("RESET = True");
		}

		// CHEAT = brandon's a pussy
		if (controls.CHEAT)
		{
			health += 1;
			trace("User is cheating!");
		}

		if (health <= 0)
		{
			boyfriend.stunned = true;

			persistentUpdate = false;
			persistentDraw = false;
			paused = true;

			vocals.stop();

			if (inst != null)
			    inst.stop();

			openSubState(new GameOverSubstate(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

			// FlxG.switchState(new GameOverState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
		}

		var NOTE_SPAWN_TIME:Float = 1500 / PlayState.SONG.speed;

		while (unspawnNotes.length > 0)
		{
		    var targetNote:Note = unspawnNotes[0];
		
		    if (targetNote.strumTime - Conductor.songPosition >= NOTE_SPAWN_TIME)
		        break;
		
		    notes.add(targetNote);
		    unspawnNotes.splice(0, 1);
		}

		if (generatedMusic)
		{
			notes.forEachAlive(function(daNote:Note)
			{
				if (daNote.y > FlxG.height)
				{
					daNote.active = false;
					daNote.visible = false;
				}
				else
				{
					daNote.visible = true;
					daNote.active = true;
				}

				if (!daNote.mustPress && daNote.wasGoodHit)
				{
					camZooming = true;

					var altAnim:String = "";

					var sectionIndex:Int = getSectionIndexAtStep(curStep);

					if (sectionIndex >= 0 && SONG.notes[sectionIndex].altAnim)
					    altAnim = '-alt';

					dad.lastNoteHitTime = Conductor.songPosition;

					var directions:Array<String> = ["LEFT", "DOWN", "UP", "RIGHT"];
					var direction:Int = Std.int(Math.abs(daNote.noteData));

					if (!daNote.isSustainNote || sustainAnimations)
					{
					    if (direction >= 0 && direction < directions.length)
					    {
					        dad.playAnim('sing${directions[direction]}$altAnim', true);
					    }
					    else if (dad.animation.getByName('hey') != null)
					    {
					        dad.playAnim('hey', true);
					    }
					}

					opponentStrums.forEach(function(spr:FlxSprite)
					{
					    if (daNote.noteData == spr.ID && opponentNoteFlashes)
					    {
					        spr.animation.play('confirm', true);
						
					        if (!isPixelStage)
					        {
					            spr.centerOffsets();
					            spr.offset.x -= 13;
					            spr.offset.y -= 13;
					        }
					    }
					});
					dad.holdTimer = 0;

					if (SONG.needsVoices)
						vocals.volume = 1;

					daNote.kill();
					notes.remove(daNote, true);
					daNote.destroy();
				}

				daNote.y = (strumLine.y - (Conductor.songPosition - daNote.strumTime) * (0.45 * FlxMath.roundDecimal(PlayState.SONG.speed, 2)));
				if (sustainClipping)
					daNote.clipToStrumLine(strumLine.y, downscroll);
				// WIP interpolation shit? Need to fix the pause issue
				// daNote.y = (strumLine.y - (songTime - daNote.strumTime) * (0.45 * PlayState.SONG.speed));

				if (daNote.y < -daNote.height)
				{
				    if (daNote.mustPress && (daNote.tooLate || !daNote.wasGoodHit))
				    {
				        noteMiss(Std.int(Math.abs(daNote.noteData)));
				        vocals.volume = 0;
				    }
				
				    daNote.active = false;
				    daNote.visible = false;
				
				    daNote.kill();
				    notes.remove(daNote, true);
				    daNote.destroy();
				}
			});
		}

		if (!inCutscene)
			keyShit();

		#if debug
		if (FlxG.keys.justPressed.ONE)
			endSong();
		#end
	}

	function endSong():Void
	{
		canPause = false;
		if (inst != null)
		    inst.volume = 0;

		vocals.volume = 0;

		// nextSong is the next story-mode song, or null if this is the last one (or freeplay).
		var nextSong:String = (isStoryMode && storyPlaylist.length > 1) ? storyPlaylist[1] : null;

		callScripts("onSongEnd", [nextSong]);

		if (SONG.validScore)
		{
			#if !switch
			Highscore.saveScore(SONG.song, scoreSystem.songScore, storyDifficulty);
			#end
		}

		if (isStoryMode)
		{
		    campaignScore += scoreSystem.songScore;
		
		    storyPlaylist.remove(storyPlaylist[0]);
		
		    if (storyPlaylist.length <= 0)
		    {
		        FlxG.sound.playMusic(Paths.music('freakyMenu'));
			
		        FlxG.switchState(new StoryMenuState());
			
		        var nextWeekIndex:Int = storyWeek + 1;
			
		        if (nextWeekIndex < StoryMenuState.weeks.length)
		        {
		            var nextWeek:WeekData = StoryMenuState.weeks[nextWeekIndex];
				
		            nextWeek.unlocked = true;
				
		            if (FlxG.save.data.weekUnlocks == null)
		                FlxG.save.data.weekUnlocks = {};
				
		            Reflect.setField(FlxG.save.data.weekUnlocks, nextWeek.id, true);
		        }
			
		        if (SONG.validScore)
		        {
		            NGio.unlockMedal(60961);
		            Highscore.saveWeekScore(storyWeek, campaignScore, storyDifficulty);
		        }
			
		        FlxG.save.flush();
		    }
		    else
		    {
		        var difficulty:String = "normal";
			
		        if (storyDifficulty == 0)
		            difficulty = 'easy';
			
		        if (storyDifficulty == 2)
		            difficulty = 'hard';
			
		        trace('LOADING NEXT SONG');
		        trace(PlayState.storyPlaylist[0].toLowerCase() + difficulty);

		        // onSongEnd can ask to skip the transition and keep the camera for the next song.
		        if ((stageScript != null && stageScript.api.skipNextTransition) || (songScript != null && songScript.api.skipNextTransition))
		        {
		            transIn = null;
		            transOut = null;
		        }
			
		        if ((stageScript != null && stageScript.api.carryCamera) || (songScript != null && songScript.api.carryCamera))
		            prevCamFollow = camFollow;
			
		        PlayState.SONG = Song.loadFromJson(difficulty, PlayState.storyPlaylist[0]);
		        if (inst != null)
    				inst.stop();

		        FlxG.switchState(new PlayState());

		        transIn = FlxTransitionableState.defaultTransIn;
		        transOut = FlxTransitionableState.defaultTransOut;
		    }
		}
		else
		{
		    trace('WENT BACK TO FREEPLAY??');
		    FlxG.switchState(new FreeplayState());
		}
	}

	function updateScoreText():Void
	{
		if (!classicScoreTxt) {
	    scoreTxt.text =
	        'Score: ${CoolUtil.formatNumber(scoreSystem.songScore)}'
			+ ' / Misses: ${scoreSystem.misses}'
	        + ' / Accuracy: ${FlxMath.roundDecimal(scoreSystem.ratingPercent * 100, 2)}%';
		} else {
			scoreTxt.text = 'Score:${scoreSystem.songScore}';
		}
	}

	var endingSong:Bool = false;

	private function popUpScore(strumtime:Float):Void
	{
		var noteDiff:Float = Math.abs(strumtime - Conductor.songPosition);
		// boyfriend.playAnim('hey');
		vocals.volume = 1;

		var placement:String = Std.string(combo);

		var coolText:FlxText = new FlxText(0, 0, 0, placement, 32);
		coolText.screenCenter();
		coolText.x = FlxG.width * 0.55;
		//

		var rating:FlxSprite = new FlxSprite();
		var daRating:String = "sick";
			
		if (noteDiff > Conductor.safeZoneOffset * 0.9)
		    daRating = "shit";
		else if (noteDiff > Conductor.safeZoneOffset * 0.75)
		    daRating = "bad";
		else if (noteDiff > Conductor.safeZoneOffset * 0.2)
		    daRating = "good";
		
		scoreSystem.addRating(daRating);
		updateScoreText();

		/* if (combo > 60)
				daRating = 'sick';
			else if (combo > 12)
				daRating = 'good'
			else if (combo > 4)
				daRating = 'bad';
		 */

		var pixelShitPart1:String = "gameplay/";
		var pixelShitPart2:String = '';

		if (isPixelStage)
		{
			pixelShitPart1 = 'weeb/pixelUI/';
			pixelShitPart2 = '-pixel';
		}

		rating.loadGraphic(Paths.graphic(Paths.image(pixelShitPart1 + daRating + pixelShitPart2)));
		rating.screenCenter();
		rating.x = coolText.x - 40;
		rating.y -= 60;
		rating.acceleration.y = 550;
		rating.velocity.y -= FlxG.random.int(140, 175);
		rating.velocity.x -= FlxG.random.int(0, 10);

		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.graphic(Paths.image(pixelShitPart1 + 'combo' + pixelShitPart2)));
		comboSpr.screenCenter();
		comboSpr.x = coolText.x;
		comboSpr.acceleration.y = 600;
		comboSpr.velocity.y -= 150;

		comboSpr.velocity.x += FlxG.random.int(1, 10);
		add(rating);

		if (!isPixelStage)
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
			rating.antialiasing = true;
			comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
			comboSpr.antialiasing = true;
		}
		else
		{
			rating.setGraphicSize(Std.int(rating.width * daPixelZoom * 0.7));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * daPixelZoom * 0.7));
		}

		comboSpr.updateHitbox();
		rating.updateHitbox();

		var seperatedScore:Array<Int> = [];

		seperatedScore.push(Math.floor(combo / 100));
		seperatedScore.push(Math.floor((combo - (seperatedScore[0] * 100)) / 10));
		seperatedScore.push(combo % 10);

		var daLoop:Int = 0;
		for (i in seperatedScore)
		{
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.graphic(Paths.image(pixelShitPart1 + 'num' + Std.int(i) + pixelShitPart2)));
			numScore.screenCenter();
			numScore.x = coolText.x + (43 * daLoop) - 90;
			numScore.y += 80;

			if (!isPixelStage)
			{
				numScore.antialiasing = true;
				numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			}
			else
			{
				numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
			}
			numScore.updateHitbox();

			numScore.acceleration.y = FlxG.random.int(200, 300);
			numScore.velocity.y -= FlxG.random.int(140, 160);
			numScore.velocity.x = FlxG.random.float(-5, 5);

			if (combo >= 10 || combo == 0)
				add(numScore);

			FlxTween.tween(numScore, {alpha: 0}, 0.2, {
				onComplete: function(tween:FlxTween)
				{
					numScore.destroy();
				},
				startDelay: Conductor.crochet * 0.002
			});

			daLoop++;
		}
		/* 
			trace(combo);
			trace(seperatedScore);
		 */

		coolText.text = Std.string(seperatedScore);
		// add(coolText);

		FlxTween.tween(rating, {alpha: 0}, 0.2, {
			startDelay: Conductor.crochet * 0.001
		});

		FlxTween.tween(comboSpr, {alpha: 0}, 0.2, {
			onComplete: function(tween:FlxTween)
			{
				coolText.destroy();
				comboSpr.destroy();

				rating.destroy();
			},
			startDelay: Conductor.crochet * 0.001
		});
	}

	public static function getStrumX(lane:Int, player:Int):Float
	{
	    var halfScreen = FlxG.width / 2;
	    var groupWidth = Note.swagWidth * 4;
	    var startX = (halfScreen - groupWidth) / 2;

		var offset = 0;

		if (vanillaStrumOffset) {
			offset = -50;
		}
	
	    return startX + (Note.swagWidth * lane) + (halfScreen * player) + offset;
	}

	private function keyShit():Void
	{
		// HOLDING
		var up = controls.UP;
		var right = controls.RIGHT;
		var down = controls.DOWN;
		var left = controls.LEFT;

		var upP = controls.UP_P;
		var rightP = controls.RIGHT_P;
		var downP = controls.DOWN_P;
		var leftP = controls.LEFT_P;

		var upR = controls.UP_R;
		var rightR = controls.RIGHT_R;
		var downR = controls.DOWN_R;
		var leftR = controls.LEFT_R;

		var controlArray:Array<Bool> = [leftP, downP, upP, rightP];

		// FlxG.watch.addQuick('asdfa', upP);
		// PRESSES
		// Every lane is judged on its own: a press can only ever hit or miss a note in
		// the lane that was pressed, so notes in other lanes can never cause a miss.
		// A miss never blocks input either (the old stun check used to swallow the next
		// ~83ms of presses, which wipes out whole streams on dense charts).

		if (botPlay && generatedMusic && !boyfriend.stunned)
		{
		    notes.forEachAlive(function(daNote:Note)
		    {
		        if (!daNote.mustPress || daNote.wasGoodHit)
		            return;
			
		        if (daNote.strumTime <= Conductor.songPosition)
		            goodNoteHit(daNote);
		    });
		}

		// be glad i rewrote this JANKY ASS SHIT, it was a mess before and i hate it
		if (!botPlay && (upP || rightP || downP || leftP) && generatedMusic)
		{
			boyfriend.holdTimer = 0;

			for (lane in 0...4)
			{
				if (!controlArray[lane])
					continue;

				var target:Note = null;

				notes.forEachAlive(function(daNote:Note)
				{
					if (daNote.noteData != lane || !daNote.mustPress || daNote.isSustainNote || daNote.wasGoodHit)
						return;

					// judged against the song position right now, not the canBeHit flag
					// (that flag is computed before songPosition moves, so it is a frame stale)
					var diff:Float = daNote.strumTime - Conductor.songPosition;

					if (diff > -Conductor.safeZoneOffset && diff < Conductor.safeZoneOffset * 0.5)
					{
						// earliest note in the lane wins
						if (target == null || daNote.strumTime < target.strumTime)
							target = daNote;
					}
				});

				if (target != null)
					goodNoteHit(target);
				else if (!ghostTapping)
					noteMiss(lane);
			}
		}

		if (!botPlay && (up || right || down || left) && !boyfriend.stunned && generatedMusic)
		{
			notes.forEachAlive(function(daNote:Note)
			{
				if (daNote.canBeHit && daNote.mustPress && daNote.isSustainNote)
				{
					switch (daNote.noteData)
					{
						// NOTES YOU ARE HOLDING
						case 2:
							if (up)
								goodNoteHit(daNote);
						case 3:
							if (right)
								goodNoteHit(daNote);
						case 1:
							if (down)
								goodNoteHit(daNote);
						case 0:
							if (left)
								goodNoteHit(daNote);
					}
				}
			});
		}

		if (boyfriend.holdTimer > Conductor.stepCrochet * 8 * 0.001
		    && boyfriend.canDance()
		    && !up && !down && !right && !left)
		{
		    if (boyfriend.animation.curAnim.name.startsWith('sing')
		        && !boyfriend.animation.curAnim.name.endsWith('miss'))
		    {
		        boyfriend.playAnim('idle');
		    }
		}

		playerStrums.forEach(function(spr:FlxSprite)
		{
		    switch (spr.ID)
		    {
		        case 2:
		            if (upP && spr.animation.curAnim.name != 'confirm')
		                spr.animation.play('pressed');
				
		            if (upR)
		            {
		                spr.animation.play('static');
					
		                if (!isPixelStage)
		                    spr.centerOffsets();
		            }
				
		        case 3:
		            if (rightP && spr.animation.curAnim.name != 'confirm')
		                spr.animation.play('pressed');
				
		            if (rightR)
		            {
		                spr.animation.play('static');
					
		                if (!isPixelStage)
		                    spr.centerOffsets();
		            }
				
		        case 1:
		            if (downP && spr.animation.curAnim.name != 'confirm')
		                spr.animation.play('pressed');
				
		            if (downR)
		            {
		                spr.animation.play('static');
					
		                if (!isPixelStage)
		                    spr.centerOffsets();
		            }
				
		        case 0:
		            if (leftP && spr.animation.curAnim.name != 'confirm')
		                spr.animation.play('pressed');
				
		            if (leftR)
		            {
		                spr.animation.play('static');
					
		                if (!isPixelStage)
		                    spr.centerOffsets();
		            }
		    }
		});
		}

	function noteMiss(direction:Int = 1):Void
	{
		if (!boyfriend.stunned)
		{
			health -= 0.04;
			if (combo > 5)
			{
				gf.playAnim('sad');
			}
			combo = 0;

			scoreSystem.songScore -= 10;
			scoreSystem.addMiss();

			FlxG.sound.play(Paths.sound('missnote' + FlxG.random.int(1, 3)), FlxG.random.float(0.1, 0.2));
			// FlxG.sound.play(Paths.sound('missnote1'), 1, false);
			// FlxG.log.add('played imss note');

			boyfriend.lastNoteHitTime = Conductor.songPosition;

			switch (direction)
			{
				case 2:
					boyfriend.playAnim('singUPmiss', true);
				case 3:
					boyfriend.playAnim('singRIGHTmiss', true);
				case 1:
					boyfriend.playAnim('singDOWNmiss', true);
				case 0:
					boyfriend.playAnim('singLEFTmiss', true);
			}
		}
	}

	function badNoteCheck()
	{
		// just double pasting this shit cuz fuk u
		// REDO THIS SYSTEM!
		var upP = controls.UP_P;
		var rightP = controls.RIGHT_P;
		var downP = controls.DOWN_P;
		var leftP = controls.LEFT_P;

		if (leftP)
			noteMiss(0);
		if (upP)
			noteMiss(2);
		if (rightP)
			noteMiss(3);
		if (downP)
			noteMiss(1);
	}

	function noteCheck(keyP:Bool, note:Note):Void
	{
		if (keyP)
			goodNoteHit(note);
		else
		{
			badNoteCheck();
		}
	}

	function goodNoteHit(note:Note):Void
	{
		if (!note.wasGoodHit)
		{
			if (!note.isSustainNote)
			{
				popUpScore(note.strumTime);
				combo += 1;
			}

			if (note.noteData >= 0)
				health += 0.023;
			else
				health += 0.004;

			boyfriend.lastNoteHitTime = Conductor.songPosition;

			
			if (!note.isSustainNote || sustainAnimations)
			{
			    var directions:Array<String> = ["LEFT", "DOWN", "UP", "RIGHT"];
			
			    if (note.noteData >= 0 && note.noteData < directions.length)
			        boyfriend.playAnim('sing${directions[note.noteData]}', true);
			    else if (boyfriend.animation.getByName('hey') != null)
			        boyfriend.playAnim('hey', true);
			}

			playerStrums.forEach(function(spr:FlxSprite)
			{
			    if (Math.abs(note.noteData) == spr.ID)
			    {
			        spr.animation.play('confirm', true);
				
			        if (!isPixelStage)
			        {
			            spr.centerOffsets();
			            spr.offset.x -= 13;
			            spr.offset.y -= 13;
			        }
			    }
			});

			note.wasGoodHit = true;
			vocals.volume = 1;

			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	override function stepHit()
	{
		if (SONG.needsVoices)
		{
			// the song clock follows the music, so vocals just have to stay glued to the music
			if (Math.abs(vocals.time - inst.time) > 30)
			{
				vocals.time = inst.time;
			}
		}

		if (dad.curCharacter == 'spooky' && totalSteps % 4 == 2)
		{
			// dad.dance();
		}

		super.stepHit();
	}

	override function beatHit()
	{
		wiggleShit.update(Conductor.crochet);
		super.beatHit();

		setScriptVariable("curBeat", curBeat);
		callScripts("onBeatHit");

		if (generatedMusic)
		{
			notes.sort(FlxSort.byY, FlxSort.DESCENDING);
		}

		if (getSectionIndexAtStep(curStep) >= 0)
		    dad.dance();
		// FlxG.log.add('change bpm' + SONG.notes[Std.int(curStep / 16)].changeBPM);


		if (camZooming && FlxG.camera.zoom < 1.35 && totalBeats % 4 == 0)
		{
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;
		}

		iconP1.setGraphicSize(Std.int(iconP1.width + 30));
		iconP2.setGraphicSize(Std.int(iconP2.width + 30));

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		if (totalBeats % gfSpeed == 0)
		{
			gf.dance();
		}

		if (!boyfriend.animation.curAnim.name.startsWith("sing"))
		{
		    boyfriend.dance();
		}

		callScripts("onBeatHitPost");
	}

	var curLight:Int = 0;
}
