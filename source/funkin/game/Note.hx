package funkin.game;

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

			// only register the animations THIS note can ever play. every addByPrefix scans the whole atlas, and
			// a tap note never plays a hold anim (a hold piece never plays a scroll one), so registering all 12
			// per note was ~10 wasted scans on every one of the thousands of notes in a chart.
			// (a hold piece needs BOTH hold + holdend: it starts as the end cap and becomes a body piece when the next piece is built)
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

		// sustain pieces don't have a scroll anim (they get holdend below)
		if (!isSustainNote)
		{
			switch(noteData) {
			    case 0: animation.play('purpleScroll');
			    case 1: animation.play('blueScroll');
			    case 2: animation.play('greenScroll');
			    case 3: animation.play('redScroll');
			}
		}

		// trace(prevNote);

		if (isSustainNote && prevNote != null)
		{
			noteScore * 0.2;
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
				// prevNote has to cover the gap down to this piece, and that gap is one step, which is a
				// different number of ms at every BPM (and changes mid-song with the tempo map). So take it from
				// the notes themselves: not a constant, and not Conductor.stepCrochet, which is only the tempo
				// the song happened to be at when the chart was generated.
				// (gap / 100 * 1.5) * speed is the vanilla formula: it is exactly 2.25 * speed at 100 BPM
				// (150 ms steps) and leaves ~2.7% overlap so there are no seams between pieces.
				// Speed is rounded to 2 decimals, same as the scroll in PlayState.update, or they drift apart.
				prevNote.scale.y *= ((strumTime - prevNote.strumTime) / 100 * 0.75) * FlxMath.roundDecimal(PlayState.SONG.speed, 2);
				prevNote.updateHitbox();
				// prevNote.setGraphicSize();
			}
		}
	}

	public function clipToStrumLine(strumLineY:Float, downscroll:Bool = false)
	{
	    if (!isSustainNote || frame == null)
	        return;

	    var center:Float = strumLineY + Note.swagWidth / 2;

	    if (wasGoodHit || (prevNote.wasGoodHit && !canBeHit))
	    {
	        var swagRect:FlxRect = clipRect;

	        if (swagRect == null)
	            swagRect = new FlxRect(0, 0, frameWidth, frameHeight);

	        if (downscroll)
	        {
	            if (y - offset.y * scale.y + height >= center)
	            {
	                swagRect.width = frameWidth;
	                swagRect.height = (center - y) / scale.y;
	                swagRect.y = frameHeight - swagRect.height;
	            }
	        }
	        else if (y + offset.y * scale.y <= center)
	        {
	            swagRect.y = (center - y) / scale.y;
	            swagRect.width = width / scale.x;
	            swagRect.height = (height / scale.y) - swagRect.y;
	        }

	        clipRect = swagRect;
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

	override function update(elapsed:Float)
	{
		super.update(elapsed);

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

			if (strumTime <= Conductor.songPosition)
			{
				wasGoodHit = true;
			}
		}

		if (tooLate)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}
	}
}
