package funkin.game;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import polymod.format.ParseRules.TargetSignatureElement;
import funkin.chart.Conductor;
import funkin.backend.Paths;

using StringTools;

class Note extends FlxSprite
{
	public var strumTime:Float = 0;

	public var mustPress:Bool = false;
	public var noteData:Int = 0;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var prevNote:Note;

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;

	public var noteScore:Float = 1;

	public static var swagWidth:Float = 160 * 0.7;
	public static var PURP_NOTE:Int = 0;
	public static var GREEN_NOTE:Int = 2;
	public static var BLUE_NOTE:Int = 1;
	public static var RED_NOTE:Int = 3;

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false)
		{
			super();
		
			if (prevNote == null)
				prevNote = this;
		
			this.prevNote = prevNote;
			isSustainNote = sustainNote;
	
			// MAKE SURE ITS DEFINITELY OFF SCREEN?
			y -= 2000;
			this.strumTime = strumTime;
			this.noteData = noteData;
	
			applyNoteVisuals();
		}

	private function applyNoteVisuals():Void
	{
		if (PlayState.isPixelStage)
		{
			loadGraphic(Paths.graphic(Paths.image('weeb/pixelUI/arrows-pixels')), true, 17, 17);

			animation.add('greenScroll', [6]);
			animation.add('redScroll', [7]);
			animation.add('blueScroll', [5]);
			animation.add('purpleScroll', [4]);

			if (isSustainNote)
			{
				loadGraphic(Paths.graphic(Paths.image('weeb/pixelUI/arrowEnds')), true, 7, 6);

				animation.add('purpleholdend', [4]);
				animation.add('greenholdend', [6]);
				animation.add('redholdend', [7]);
				animation.add('blueholdend', [5]);

				animation.add('purplehold', [0]);
				animation.add('greenhold', [2]);
				animation.add('redhold', [3]);
				animation.add('bluehold', [1]);
			}

			setGraphicSize(Std.int(width * PlayState.daPixelZoom));
			updateHitbox();
		}
		else
		{
			frames = Paths.sparrow('gameplay/NOTE_assets');

			if (isSustainNote)
			{
				switch (noteData)
				{
					case 0:
						animation.addByPrefix('purpleholdend', 'pruple end hold');
						animation.addByPrefix('purplehold', 'purple hold piece');
					case 1:
						animation.addByPrefix('blueholdend', 'blue hold end');
						animation.addByPrefix('bluehold', 'blue hold piece');
					case 2:
						animation.addByPrefix('greenholdend', 'green hold end');
						animation.addByPrefix('greenhold', 'green hold piece');
					case 3:
						animation.addByPrefix('redholdend', 'red hold end');
						animation.addByPrefix('redhold', 'red hold piece');
				}
			}
			else
			{
				switch (noteData)
				{
					case 0: animation.addByPrefix('purpleScroll', 'purple0');
					case 1: animation.addByPrefix('blueScroll', 'blue0');
					case 2: animation.addByPrefix('greenScroll', 'green0');
					case 3: animation.addByPrefix('redScroll', 'red0');
				}
			}

			setGraphicSize(Std.int(width * 0.7));
			updateHitbox();
			antialiasing = true;
		}

		if (!isSustainNote)
		{
			switch (noteData)
			{
				case 0: animation.play('purpleScroll');
				case 1: animation.play('blueScroll');
				case 2: animation.play('greenScroll');
				case 3: animation.play('redScroll');
			}
		}

		if (isSustainNote && prevNote != null)
		{
			alpha = 0.6;

			switch (noteData)
			{
				case 2:
					animation.play('greenholdend');
				case 3:
					animation.play('redholdend');
				case 1:
					animation.play('blueholdend');
				case 0:
					animation.play('purpleholdend');
			}

			updateHitbox();
			if (PlayState.isPixelStage) x += 30;

			if (prevNote.isSustainNote)
			{
				switch (prevNote.noteData)
				{
					case 2:
						prevNote.animation.play('greenhold');
					case 3:
						prevNote.animation.play('redhold');
					case 1:
						prevNote.animation.play('bluehold');
					case 0:
						prevNote.animation.play('purplehold');
				}

				prevNote.offset.y = -19;
				prevNote.scale.y *= ((strumTime - prevNote.strumTime) / 100 * 0.75) * FlxMath.roundDecimal(PlayState.SONG.speed, 2);
				prevNote.updateHitbox();
			}
		}
	}

		public function resetNote(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false):Void
	{
		if (clipRect != null)
		{
			clipRect.put();
			clipRect = null;
		}

		flipY = false;
		alpha = 1;
		canBeHit = false;
		tooLate = false;
		wasGoodHit = false;
		sustainLength = 0;
		noteScore = 1;

		scale.set(1, 1);
		offset.set(0, 0);

		if (prevNote == null)
			prevNote = this;

		this.prevNote = prevNote;
		isSustainNote = sustainNote;
		this.strumTime = strumTime;
		this.noteData = noteData;

		// Re-apply graphics/animations/sustain sizing cleanly
		applyNoteVisuals();
	}

	public function updateSustainFlip(strumLineY:Float, upY:Float = 50, downY:Float = -1):Void
	{
		if (!isSustainNote)
			return;

		var scrollFactor:Float = getScrollFactor(strumLineY, upY, downY);

		if (animation.curAnim != null && animation.curAnim.name.endsWith('holdend'))
		{
			flipY = scrollFactor >= 0.5;
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		updateTiming();
	}

	// the hit-window / late logic. PlayState calls this from its single note pass and keeps notes inactive, so
	// the group never runs the full FlxSprite.update on thousands of single-frame notes every frame.
	// (the opponent branch no longer sets wasGoodHit here: PlayState's due list is what hits those notes)
	public function updateTiming():Void
	{
		if (mustPress)
		{
			// The * 0.5 us so that its easier to hit them too late, instead of too early
			if (strumTime > Conductor.songPosition - Conductor.safeZoneOffset
				&& strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * 0.5))
			{
				canBeHit = true;
			}
			else
				canBeHit = false;

			if (strumTime < Conductor.songPosition - Conductor.safeZoneOffset)
				tooLate = true;
		}
		else
		{
			canBeHit = false;
		}

		if (tooLate)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}
	}

	@:noCompletion
	override function set_clipRect(rect:FlxRect):FlxRect
	{
	    clipRect = rect;

	    if (frames != null)
	        frame = frames.frames[animation.frameIndex];

	    return rect;
	}

	public function getScrollFactor(strumLineY:Float, upY:Float = 50, downY:Float = -1):Float
	{
		var resolvedDownY:Float = (downY < 0) ? (FlxG.height - 150) : downY;
		return FlxMath.bound((strumLineY - upY) / (resolvedDownY - upY), 0, 1);
	}

	public function clipToStrumLine(strumLineY:Float, upY:Float = 50, downY:Float = -1)
	{
		if (!isSustainNote || frame == null)
			return;
	
		var scrollFactor:Float = getScrollFactor(strumLineY, upY, downY);
		updateSustainFlip(strumLineY, upY, downY);
		var center:Float = strumLineY + Note.swagWidth / 2;
	
		if (wasGoodHit || (prevNote.wasGoodHit && !canBeHit))
		{
			var upPassed:Bool = y + offset.y * scale.y <= center;
			var downPassed:Bool = y - offset.y * scale.y + height >= center;
		
			if (FlxMath.lerp(upPassed ? 1 : 0, downPassed ? 1 : 0, scrollFactor) > 0)
			{
				var swagRect:FlxRect = clipRect;
			
				if (swagRect == null)
					swagRect = new FlxRect(0, 0, frameWidth, frameHeight);
			
				var upClipY:Float = (center - y) / scale.y;
				var upClipHeight:Float = (height / scale.y) - upClipY;
	
				var downClipHeight:Float = (center - y) / scale.y;
				var downClipY:Float = frameHeight - downClipHeight;
	
				swagRect.width = FlxMath.lerp(width / scale.x, frameWidth, scrollFactor);
				swagRect.y = FlxMath.lerp(upClipY, downClipY, scrollFactor);
				swagRect.height = FlxMath.lerp(upClipHeight, downClipHeight, scrollFactor);
	
				clipRect = swagRect;
			}
		}
	}
}
