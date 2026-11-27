package funkin.game;

import funkin.chart.Section.SwagSection;
import funkin.chart.Song.SwagSong;
import funkin.shaders.WiggleEffect.WiggleEffectType;
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

import funkin.stage.Stage;
import funkin.stage.StageLoader;
import funkin.shaders.WiggleEffect;
import funkin.chart.Conductor;
import funkin.chart.Song;
import funkin.backend.CoolUtil;
import funkin.backend.Highscore;
import funkin.backend.MusicBeatState;
import funkin.backend.NGio;
import funkin.backend.Paths;
import funkin.menus.FreeplayState;
import funkin.menus.StoryMenuState;
import funkin.menus.WeekData;

import funkin.backend.ClientPrefs;
import funkin.editors.AnimationDebug;
import funkin.editors.CharacterEditorState;
import funkin.editors.ChartingState;
import funkin.stage.StageScript;

using StringTools;

typedef QueuedNote = {
	var strumTime:Float;
	var noteData:Int;
	var sustainLength:Float;
	var mustPress:Bool;
}

class PlayState extends MusicBeatState
{
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

	private var vocals:FlxSound;
	private var inst:FlxSound;

	private var dad:Character;
	private var gf:Character;
	private var boyfriend:Boyfriend;

	static inline var MAX_SONG_NOTES:Int = 1099325;

	private var notes:FlxTypedGroup<Note>;
	private var unspawnNotes:Array<QueuedNote> = [];
	// next note in unspawnNotes to spawn. a cursor is O(1); splice(0, 1) shifts the whole array AND allocates, every spawn
	private var unspawnIdx:Int = 0;
	// px of headroom past the screen edge before a note spawns, so it can't pop in after a hitch or a zoomed-out hud cam
	static inline var NOTE_SPAWN_MARGIN:Float = 200;

	private var notePool:Array<Note> = [];
	// notes recycled this frame. they stay in notes.members (dead) until the next note pass compacts them out,
	// and only go back into notePool after that, so a pooled note is never also still sitting in members
	private var deadNotes:Array<Note> = [];

	// timing probes: prints + shows spawn / note pass / input / draw cost once a second. flip to false to compile them out
	static inline var NOTE_PROFILE:Bool = true;
	private var profTxt:FlxText;
	private var profClock:Float = 0;
	private var profFrames:Int = 0;
	private var profSpawned:Int = 0;
	private var profSpawn:Float = 0;
	private var profPass:Float = 0;
	private var profKeys:Float = 0;
	private var profDraw:Float = 0;

	private var dueOpponentNotes:Array<Note> = [];
	private var dueBotNotes:Array<Note> = [];
	private var bestTapNotes:Array<Note> = [null, null, null, null];
	private static final NOTE_DIRECTIONS:Array<String> = ["LEFT", "DOWN", "UP", "RIGHT"];

	var previousStrumAnimations:haxe.ds.ObjectMap<FlxSprite, String> = new haxe.ds.ObjectMap();

	private var strumLine:FlxSprite;
	private var curSection:Int = 0;

	private var camFollow:FlxObject;

	private static var prevCamFollow:FlxObject;

	var strumLineNotes:FlxTypedGroup<FlxSprite>;
	var playerStrums:FlxTypedGroup<FlxSprite>;
	var opponentStrums:FlxTypedGroup<FlxSprite>;

	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

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

	public var upY:Float = 50;
	public var downY:Float = FlxG.height - 150;

	var inCutscene:Bool = false;

	var startTimer:FlxTimer;
	var perfectMode:Bool = false;

	var previousFrameTime:Int = 0;
	var lastReportedPlayheadPosition:Int = 0;
	var songTime:Float = 0;

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

	var debugNum:Int = 0;

	private var paused:Bool = false;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;

	var endingSong:Bool = false;

	var curLight:Int = 0;

	override public function create()
	{
		// var gameCam:FlxCamera = FlxG.camera;
		camGame = new FlxCamera();
		camHUD = new HudCamera();

		scoreSystem = new ScoreSystem();

		camHUD.downscroll = ClientPrefs.downscroll;
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

		var strumLineY:Float = ClientPrefs.downscroll ? downY : upY;

		strumLine = new FlxSprite(0, strumLineY).makeGraphic(FlxG.width, 10);
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

		healthBarBG = new FlxSprite(0, FlxG.height * (!ClientPrefs.downscroll ? 0.9 : 0.1)).loadGraphic(Paths.graphic(Paths.image('gameplay/healthBar')));
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

		if (ClientPrefs.classicScoreTxt) {
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

		if (stageScript != null)
    		stageScript.api.setHealthIcons(iconP1, iconP2);

		if (songScript != null)
		    songScript.api.setHealthIcons(iconP1, iconP2);

		if (stageScript.loaded)
		    stageScript.call("onCreate");
			
		if (songScript != null && songScript.loaded)
		    songScript.call("onCreate");

		strumLineNotes.cameras = [camHUD];
		notes.cameras = [camHUD];
		healthBar.cameras = [camHUD];
		healthBarBG.cameras = [camHUD];
		iconP1.cameras = [camHUD];
		iconP2.cameras = [camHUD];
		scoreTxt.cameras = [camHUD];
		doof.cameras = [camHUD];

		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		grpNoteSplashes.cameras = [camHUD];
    	add(grpNoteSplashes);

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

		if (health > 2)
		    health = 2;

		iconP1.updateIcon(elapsed, healthBar.percent, healthBar.x, healthBar.width);
		iconP2.updateIcon(elapsed, healthBar.percent, healthBar.x, healthBar.width);

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

		if (ClientPrefs.botPlay)
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

		// scroll in px/ms. same formula the note y uses below, so spawn distance and movement can't drift apart
		var scrollSpeed:Float = 0.45 * FlxMath.roundDecimal(PlayState.SONG.speed, 2);

		// how long a note takes to travel from the strumline to just past the screen edge. spawning exactly then means
		// notes enter from off screen at ANY scroll speed (a fixed window pops them in mid-screen when the speed is low).
		// never later than the hit window though, or very fast scroll speeds would spawn notes too late to hit early
		var spawnTime:Float = Math.max((FlxG.height - 50 + NOTE_SPAWN_MARGIN) / scrollSpeed, Conductor.safeZoneOffset * 2);

		var tSpawn:Float = NOTE_PROFILE ? haxe.Timer.stamp() : 0;

		while (unspawnIdx < unspawnNotes.length)
		{
			var targetNote:QueuedNote = unspawnNotes[unspawnIdx];
		
			if (targetNote.strumTime - Conductor.songPosition >= spawnTime)
				break;
		
			spawnQueuedNote(targetNote);
			unspawnNotes[unspawnIdx] = null;
			unspawnIdx++;
			if (NOTE_PROFILE) profSpawned++;
		}

		var tPass:Float = 0;
		var tAfter:Float = 0;
		if (NOTE_PROFILE)
		{
			tPass = haxe.Timer.stamp();
			profSpawn += tPass - tSpawn;
		}

		if (generatedMusic)
		{
			dueOpponentNotes.resize(0);
			dueBotNotes.resize(0);
			var songPos:Float = Conductor.songPosition;
			var baseStrumY:Float = strumLine.y;
			var botOn:Bool = ClientPrefs.botPlay;

			// one walk over the live notes does everything: timing flags, due lists (opponent + botplay), movement,
			// clipping, off-screen exit AND compaction of the dead ones (so nothing ever has to splice the group)
			var members = notes.members;
			var w:Int = 0;
			for (i in 0...members.length)
			{
				var daNote:Note = members[i];
				if (daNote == null || !daNote.exists || !daNote.alive)
					continue;

				if (!daNote.wasGoodHit && (daNote.strumTime <= songPos || daNote.tooLate))
				{
					if (!daNote.mustPress)
						dueOpponentNotes.push(daNote);
					else if (botOn)
						dueBotNotes.push(daNote);
				}

				daNote.updateTiming();

				var scrollFactor:Float = daNote.getScrollFactor(baseStrumY, upY, downY);
				var offset:Float = (songPos - daNote.strumTime) * scrollSpeed;
				daNote.y = baseStrumY + FlxMath.lerp(-offset, offset, scrollFactor);

				if (ClientPrefs.sustainClipping && daNote.isSustainNote)
					daNote.clipToStrumLine(baseStrumY, upY, downY);

				// Off-screen check flips with scroll direction:
				// upscroll exits past top (y < -height); downscroll exits past bottom (y > FlxG.height)
				var passedTop:Bool = daNote.y < -daNote.height;
				var passedBottom:Bool = daNote.y > FlxG.height;
				var offScreenExit:Bool = scrollFactor < 0.5 ? passedTop : passedBottom;

				if (offScreenExit)
				{
					if (daNote.mustPress && !daNote.isSustainNote && (daNote.tooLate || !daNote.wasGoodHit))
					{
						noteMiss(Std.int(Math.abs(daNote.noteData)));
						vocals.volume = 0;
					}

					recycleNote(daNote);
					continue;
				}

				members[w++] = daNote;
			}

			if (w != members.length)
			{
				members.resize(w);
				notes.length = w;
			}

			// compacted: the dead ones are no longer in members, so they can go back in the pool
			for (i in 0...deadNotes.length)
				notePool.push(deadNotes[i]);
			deadNotes.resize(0);

			if (NOTE_PROFILE)
			{
				tAfter = haxe.Timer.stamp();
				profPass += tAfter - tPass;
			}

			if (dueOpponentNotes.length > 1)
			{
				dueOpponentNotes.sort(function(a:Note, b:Note):Int
				{
					if (a.strumTime < b.strumTime) return -1;
					if (a.strumTime > b.strumTime) return 1;
					return 0;
				});
			}

			for (i in 0...dueOpponentNotes.length)
			{
				var oppNote:Note = dueOpponentNotes[i];
				if (oppNote != null && oppNote.alive && !oppNote.wasGoodHit)
					opponentNoteHit(oppNote);
			}
		}

		if (!inCutscene)
			keyShit();

		if (NOTE_PROFILE)
		{
			// opponent hits + bot/player input, everything after the note pass
			if (tAfter > 0) profKeys += haxe.Timer.stamp() - tAfter;
			updateNoteProfile(elapsed);
		}

		#if debug
		if (FlxG.keys.justPressed.ONE)
			endSong();
		#end
	}

	override function draw():Void
	{
		if (NOTE_PROFILE)
		{
			var t:Float = haxe.Timer.stamp();
			super.draw();
			profDraw += haxe.Timer.stamp() - t;
		}
		else
			super.draw();
	}

	private function updateNoteProfile(elapsed:Float):Void
	{
		if (profTxt == null)
		{
			profTxt = new FlxText(10, 120, 0, '', 14);
			profTxt.color = 0xFF00FF00;
			profTxt.scrollFactor.set();
			profTxt.cameras = [camHUD];
			add(profTxt);
		}

		profFrames++;
		profClock += elapsed;
		if (profClock < 1)
			return;

		var f:Float = profFrames;
		var live:Int = notes.members.length;
		var report:String = 'live notes: $live | spawned/s: $profSpawned | fps: ${Std.int(f / profClock)}\n'
			+ 'ms/frame  spawn: ${fmtMs(profSpawn / f)}  pass: ${fmtMs(profPass / f)}  hits+input: ${fmtMs(profKeys / f)}  draw: ${fmtMs(profDraw / f)}';
		profTxt.text = report;
		trace(report);

		profClock = 0;
		profFrames = 0;
		profSpawned = 0;
		profSpawn = 0;
		profPass = 0;
		profKeys = 0;
		profDraw = 0;
	}

	private inline function fmtMs(seconds:Float):String
		return Std.string(Math.round(seconds * 100000) / 100);

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

		if (getSectionIndexAtStep(curStep) >= 0)
		    dad.dance();
		// FlxG.log.add('change bpm' + SONG.notes[Std.int(curStep / 16)].changeBPM);


		if (camZooming && FlxG.camera.zoom < 1.35 && totalBeats % 4 == 0)
		{
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;
		}

		iconP1.bop();
		iconP2.bop();

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

	public static function getStrumX(lane:Int, player:Int):Float
	{
	    var halfScreen = FlxG.width / 2;
	    var groupWidth = Note.swagWidth * 4;
	    var startX = (halfScreen - groupWidth) / 2;

		var offset = 0;

		if (ClientPrefs.vanillaStrumOffset) {
			offset = -50;
		}
	
	    return startX + (Note.swagWidth * lane) + (halfScreen * player) + offset;
	}

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

	private function createNoteSplash(note:Note):Void
	{
		if (!ClientPrefs.noteSplashes)
			return;
		
	    var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);

	    splash.setupNoteSplash(
	        note.x,
	        note.y,
	        note.noteData
	    );

	    grpNoteSplashes.add(splash);
	}

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
		unspawnNotes = [];
		unspawnIdx = 0;

		for (section in songData.notes)
		{
			for (songNotes in section.sectionNotes)
			{
				if (unspawnNotes.length >= MAX_SONG_NOTES)
				{
					throw 'Chart note count exceeded maximum limit of ' + MAX_SONG_NOTES + ' notes. Just stop. Please.';
				}

				var daStrumTime:Float = songNotes[0];
				var daNoteData:Int = Std.int(songNotes[1] % 4);
				var sustainLength:Float = songNotes[2];

				var gottaHitNote:Bool = section.mustHitSection;
				if (songNotes[1] > 3)
				{
					gottaHitNote = !section.mustHitSection;
				}

				unspawnNotes.push({
					strumTime: daStrumTime,
					noteData: daNoteData,
					sustainLength: sustainLength,
					mustPress: gottaHitNote
				});
			}
		}

		unspawnNotes.sort(function(a:QueuedNote, b:QueuedNote):Int {
			return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
		});

		// trace(unspawnNotes.length);
		// playerCounter += 1;

		generatedMusic = true;
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

	function endSong():Void
	{
		clearNotePool();
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
		if (!ClientPrefs.classicScoreTxt) {
	    scoreTxt.text =
	        'Score: ${CoolUtil.formatNumber(scoreSystem.songScore)}'
			+ ' / Misses: ${scoreSystem.misses}'
	        + ' / Accuracy: ${FlxMath.roundDecimal(scoreSystem.ratingPercent * 100, 2)}%';
		} else {
			scoreTxt.text = 'Score:${scoreSystem.songScore}';
		}
	}

private function popUpScore(strumtime:Float, note:Note):Void
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
	
		if (noteDiff > Conductor.badWindow)
			daRating = "shit";
		else if (noteDiff > Conductor.goodWindow)
			daRating = "bad";
		else if (noteDiff > Conductor.sickWindow)
			daRating = "good";

		scoreSystem.addRating(daRating);
		updateScoreText();

		if (daRating == 'sick')
			createNoteSplash(note);

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

		// Uncapped single-digit extraction for any combo length
		var seperatedScore:Array<Int> = [];
		var comboStr:String = Std.string(Std.int(Math.max(0, combo)));
		for (idx in 0...comboStr.length)
		{
			var digit:Null<Int> = Std.parseInt(comboStr.charAt(idx));
			seperatedScore.push(digit != null ? digit : 0);
		}

		// Optional: shift left slightly as digit count grows so 4+ digit combos don't crowd comboSpr
		var digitSpacing:Float = 43;
		var baseX:Float = coolText.x - 90 - Math.max(0, seperatedScore.length - 3) * (digitSpacing * 0.5);

		var daLoop:Int = 0;
		for (i in seperatedScore)
		{
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.graphic(Paths.image(pixelShitPart1 + 'num' + i + pixelShitPart2)));
			numScore.screenCenter();
			numScore.x = baseX + (digitSpacing * daLoop);
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
	
		if (generatedMusic)
		{
			var songPos:Float = Conductor.songPosition;
			var minWindow:Float = -Conductor.shitWindow;
			var maxWindow:Float = Conductor.shitWindow;
			var anyTap:Bool = !ClientPrefs.botPlay && (upP || rightP || downP || leftP);
			var anyHold:Bool = !ClientPrefs.botPlay && !boyfriend.stunned && (up || right || down || left);
		
			if (anyTap)
			{
				boyfriend.holdTimer = 0;
			
				if (!ClientPrefs.spammableInputs)
				{
					bestTapNotes[0] = null;
					bestTapNotes[1] = null;
					bestTapNotes[2] = null;
					bestTapNotes[3] = null;
				}
			}

			// the bot's due notes were already collected by the note pass in update(), so only a real player
			// pressing/holding something needs to walk the notes here
			var members = notes.members;
			for (i in 0...((anyTap || anyHold) ? members.length : 0))
			{
				var daNote:Note = members[i];
				if (daNote == null || !daNote.exists || !daNote.alive || !daNote.mustPress || daNote.wasGoodHit)
					continue;

				var lane:Int = daNote.noteData;
				if (lane < 0 || lane > 3)
					continue;
			
				if (anyTap && !daNote.isSustainNote && controlArray[lane])
				{
					var diff:Float = daNote.strumTime - songPos;
				
					if (diff >= minWindow && diff <= maxWindow)
					{
						if (ClientPrefs.spammableInputs)
						{
							goodNoteHit(daNote);
						}
						else
						{
							var curBest:Note = bestTapNotes[lane];
							if (curBest == null || Math.abs(diff) < Math.abs(curBest.strumTime - songPos))
								bestTapNotes[lane] = daNote;
						}
					}
				}
			
				if (anyHold && daNote.canBeHit && daNote.isSustainNote)
				{
					var held:Bool = switch (lane)
					{
						case 0: left;
						case 1: down;
						case 2: up;
						case 3: right;
						default: false;
					};
				
					if (held)
						goodNoteHit(daNote);
				}
			}
		
			if (ClientPrefs.botPlay && !boyfriend.stunned)
			{
				if (dueBotNotes.length > 1)
				{
					dueBotNotes.sort(function(a:Note, b:Note):Int
					{
						if (a.strumTime < b.strumTime) return -1;
						if (a.strumTime > b.strumTime) return 1;
						return 0;
					});
				}
			
				for (i in 0...dueBotNotes.length)
				{
					var botNote:Note = dueBotNotes[i];
					if (botNote != null && botNote.alive && !botNote.wasGoodHit)
						goodNoteHit(botNote);
				}
			}
			else if (anyTap && !ClientPrefs.spammableInputs)
			{
				for (lane in 0...4)
				{
					if (!controlArray[lane])
						continue;
				
					if (bestTapNotes[lane] != null)
						goodNoteHit(bestTapNotes[lane]);
					else if (!ClientPrefs.ghostTapping)
						noteMiss(lane);
				}
			}
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
	
		for (spr in playerStrums.members)
		{
			if (spr == null || !spr.alive || spr.animation.curAnim == null)
				continue;
		
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
		}
	}



	private function spawnQueuedNote(q:QueuedNote):Void
	{
		var swagNote:Note = getPooledNote(q.strumTime, q.noteData, null, false);
		swagNote.sustainLength = q.sustainLength;
		swagNote.scrollFactor.set(0, 0);
		swagNote.mustPress = q.mustPress;
		swagNote.x = getStrumX(q.noteData, swagNote.mustPress ? 1 : 0);
		addLiveNote(swagNote);
	
		var remainingSustain:Float = swagNote.sustainLength;
		var sustainTime:Float = q.strumTime;
		var prevNote:Note = swagNote;
	
		while (remainingSustain > 0)
		{
			var stepDuration:Float = getStepDurationAtTime(sustainTime);
		
			if (remainingSustain + 0.001 < stepDuration || stepDuration <= 0)
				break;
		
			sustainTime += stepDuration;
			remainingSustain -= stepDuration;
	
			var sustainNote:Note = getPooledNote(sustainTime, q.noteData, prevNote, true);
			sustainNote.scrollFactor.set();
			sustainNote.mustPress = q.mustPress;
			sustainNote.x = getStrumX(q.noteData, sustainNote.mustPress ? 1 : 0)
				+ sustainNote.width
				+ sustainNote.offset.x / 4;
	
			addLiveNote(sustainNote);
			prevNote = sustainNote;
		}
	}

	private function getPooledNote(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false):Note
	{
		var n:Note = notePool.pop();
		if (n == null)
		{
			n = new Note(strumTime, noteData, prevNote, sustainNote);
		}
		else
		{
			n.resetNote(strumTime, noteData, prevNote, sustainNote);
		}

		// inactive on purpose: the group's update() skips inactive members, and update() runs the single note pass
		n.active = false;
		n.visible = true;
		n.alive = true;
		n.exists = true;
		return n;
	}

	private function recycleNote(note:Note):Void
	{
			if (note == null || !note.alive)
				return;

			note.wasGoodHit = true;
			note.active = false;
			note.visible = false;
			note.prevNote = null;
			note.kill();
			// no notes.remove(): that's an indexOf + splice over every live note. the note pass compacts the dead out
			deadNotes.push(note);
	}

	// FlxGroup.add does an indexOf AND an indexOf(null) over every member. notes are never added twice and
	// members never holds a null hole (the pass compacts), so a push is all that's needed
	private inline function addLiveNote(n:Note):Void
	{
		notes.members.push(n);
		notes.length++;
	}

	private function clearNotePool():Void
	{
		if (notePool != null)
		{
			for (i in 0...notePool.length)
			{
				var n:Note = notePool[i];
				if (n != null)
				{
					if (n.clipRect != null)
					{
						n.clipRect.put();
						n.clipRect = null;
					}
					n.prevNote = null;
					n.destroy();
				}
			}
			notePool.resize(0);
		}

		// deadNotes are still in notes.members, so the group's own destroy() handles them. just drop the refs
		deadNotes.resize(0);

		unspawnNotes.resize(0);
		unspawnIdx = 0;
		dueOpponentNotes.resize(0);
		dueBotNotes.resize(0);
	}

	override public function destroy():Void
	{
		clearNotePool();
		super.destroy();
	}
	
	function noteMiss(direction:Int = 1):Void
	{
		if (ClientPrefs.botPlay)
			return;
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
				if(!ClientPrefs.botPlay) {
				popUpScore(note.strumTime, note);
				}
				combo += 1;
			}

			if (note.noteData >= 0)
				health += 0.023;
			else
				health += 0.004;

			boyfriend.lastNoteHitTime = Conductor.songPosition;

			
			if (!note.isSustainNote || ClientPrefs.sustainAnimations)
			{
			
			    if (note.noteData >= 0 && note.noteData < NOTE_DIRECTIONS.length)
			        boyfriend.playAnim('sing${NOTE_DIRECTIONS[note.noteData]}', true);
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

			recycleNote(note);
		}
	}

	function opponentNoteHit(note:Note):Void
	{
		if (!note.wasGoodHit)
		{
			camZooming = true;

			var altAnim:String = "";
			var sectionIndex:Int = getSectionIndexAtStep(curStep);
			if (sectionIndex >= 0 && SONG.notes[sectionIndex].altAnim)
				altAnim = '-alt';

			dad.lastNoteHitTime = Conductor.songPosition;

			if (!note.isSustainNote || ClientPrefs.sustainAnimations)
			{
				var direction:Int = Std.int(Math.abs(note.noteData));

				if (direction >= 0 && direction < NOTE_DIRECTIONS.length)
					dad.playAnim('sing${NOTE_DIRECTIONS[direction]}$altAnim', true);
				else if (dad.animation.getByName('hey') != null)
					dad.playAnim('hey', true);
			}

			if (ClientPrefs.opponentNoteFlashes)
			{
				for (spr in opponentStrums.members)
				{
					if (spr != null && spr.alive && Math.abs(note.noteData) == spr.ID)
					{
						spr.animation.play('confirm', true);

						if (!isPixelStage)
						{
							spr.centerOffsets();
							spr.offset.x -= 13;
							spr.offset.y -= 13;
						}
					}
				}
			}

			dad.holdTimer = 0;
			note.wasGoodHit = true;

			if (SONG.needsVoices)
				vocals.volume = 1;

			recycleNote(note);
		}
	}
}

