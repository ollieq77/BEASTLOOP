package;

import flixel.FlxG;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxUIState;
import flixel.math.FlxRect;
import flixel.util.FlxTimer;

class MusicBeatState extends FlxUIState
{
	private var lastBeat:Float = 0;
	private var lastStep:Float = 0;

	private var totalBeats:Int = 0;
	private var totalSteps:Int = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;
	private var controls(get, never):Controls;

	private var lastTempoStep:Int = 0;

	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	override function create()
	{
		if (transIn != null)
			trace('reg ' + transIn.region);

		#if (!web)
		TitleState.soundExt = '.ogg';
		#end

		super.create();
	}

	override function update(elapsed:Float)
	{
		everyStep();

		updateCurStep();
		// Needs to be ROUNED, rather than ceil or floor
		updateBeat();

		super.update(elapsed);
	}

	private function updateBeat():Void
	{
		curBeat = Math.round(curStep / 4);
	}

	/**
	 * CHECKS EVERY FRAME
	 */
	private function everyStep():Void
	{
	    if (usesTempoMap())
	    {
	        var targetStep:Int = getStepAtTime(Conductor.songPosition);

	        // Don't dispatch steps during the negative countdown.
	        if (targetStep < 0)
	            return;

	        // Apply the initial section's BPM.
	        if (lastTempoStep == 0)
	        {
	            var initialBPM:Int = getBPMAtStep(0);

	            if (initialBPM > 0 && initialBPM != Conductor.bpm)
	                Conductor.changeBPM(initialBPM);
	        }

	        // Dispatch every step crossed since the previous update.
	        while (lastTempoStep < targetStep)
	        {
	            lastTempoStep++;

	            var stepBPM:Int = getBPMAtStep(lastTempoStep);

	            if (stepBPM > 0 && stepBPM != Conductor.bpm)
	                Conductor.changeBPM(stepBPM);

	            stepHit();
	        }

	        return;
	    }

	    // Original fixed-BPM dispatcher. Leave its behaviour intact.
	    if (Conductor.songPosition > lastStep + Conductor.stepCrochet - Conductor.safeZoneOffset
	        || Conductor.songPosition < lastStep + Conductor.safeZoneOffset)
	    {
	        if (Conductor.songPosition > lastStep + Conductor.stepCrochet)
	            stepHit();
	    }
	}

	private function updateCurStep():Void
	{
	    if (usesTempoMap())
	    {
	        curStep = getStepAtTime(Conductor.songPosition);
	        return;
	    }
	
	    curStep = Math.floor(Conductor.songPosition / Conductor.stepCrochet);
	}

	public function stepHit():Void
	{
	    totalSteps += 1;

	    if (!usesTempoMap())
	    {
	        lastStep += Conductor.stepCrochet;

	        // If the song is at least 3 steps behind
	        if (Conductor.songPosition > lastStep + (Conductor.stepCrochet * 3))
	        {
	            lastStep = Conductor.songPosition;
	            totalSteps = Math.ceil(lastStep / Conductor.stepCrochet);
	        }
	    }

	    if (totalSteps % 4 == 0)
	        beatHit();
	}

	public function beatHit():Void
	{
		lastBeat += Conductor.crochet;
		totalBeats += 1;
	}

	public function usesTempoMap():Bool
	{
	    return false;
	}

	public function getStepAtTime(time:Float):Int
	{
	    return Std.int(Math.floor(time / Conductor.stepCrochet));
	}

	public function getBPMAtStep(step:Int):Int
	{
	    return Conductor.bpm;
	}
}
