package funkin.backend;

import flixel.FlxG;

class ClientPrefs
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
	public static var noteSplashes:Bool = false;
	public static var spammableInputs:Bool = false;

	public static function saveSettings():Bool
	{
		if (FlxG.save == null || FlxG.save.data == null)
		{
			trace('[ClientPrefs] ERROR: Save failed - FlxG.save is not bound or null!');
			return false;
		}

		FlxG.save.data.botPlay = botPlay;
		FlxG.save.data.opponentNoteFlashes = opponentNoteFlashes;
		FlxG.save.data.sustainAnimations = sustainAnimations;
		FlxG.save.data.downscroll = downscroll;
		FlxG.save.data.vanillaStrumOffset = vanillaStrumOffset;
		FlxG.save.data.sustainClipping = sustainClipping;
		FlxG.save.data.classicScoreTxt = classicScoreTxt;
		FlxG.save.data.ghostTapping = ghostTapping;
		FlxG.save.data.noteSplashes = noteSplashes;
		FlxG.save.data.spammableInputs = spammableInputs;

		var success:Bool = FlxG.save.flush();
		trace('[ClientPrefs] Save flushed (success=$success): ${getSummary()}');
		return success;
	}

	public static function loadPrefs():Void
	{
		if (FlxG.save == null || FlxG.save.data == null)
		{
			trace('[ClientPrefs] ERROR: Load failed - FlxG.save is not bound or null!');
			return;
		}

		var loadedCount:Int = 0;

		if (FlxG.save.data.botPlay != null) { botPlay = FlxG.save.data.botPlay; loadedCount++; }
		if (FlxG.save.data.opponentNoteFlashes != null) { opponentNoteFlashes = FlxG.save.data.opponentNoteFlashes; loadedCount++; }
		if (FlxG.save.data.sustainAnimations != null) { sustainAnimations = FlxG.save.data.sustainAnimations; loadedCount++; }
		if (FlxG.save.data.downscroll != null) { downscroll = FlxG.save.data.downscroll; loadedCount++; }
		if (FlxG.save.data.vanillaStrumOffset != null) { vanillaStrumOffset = FlxG.save.data.vanillaStrumOffset; loadedCount++; }
		if (FlxG.save.data.sustainClipping != null) { sustainClipping = FlxG.save.data.sustainClipping; loadedCount++; }
		if (FlxG.save.data.classicScoreTxt != null) { classicScoreTxt = FlxG.save.data.classicScoreTxt; loadedCount++; }
		if (FlxG.save.data.ghostTapping != null) { ghostTapping = FlxG.save.data.ghostTapping; loadedCount++; }
		if (FlxG.save.data.noteSplashes != null) { noteSplashes = FlxG.save.data.noteSplashes; loadedCount++; }
		if (FlxG.save.data.spammableInputs != null) { spammableInputs = FlxG.save.data.spammableInputs; loadedCount++;}

		if (loadedCount == 0)
			trace('[ClientPrefs] No saved data found (fresh save) - using defaults: ${getSummary()}');
		else
			trace('[ClientPrefs] Loaded $loadedCount settings: ${getSummary()}');
	}

	static function getSummary():String
	{
		return 'botPlay=$botPlay, opponentNoteFlashes=$opponentNoteFlashes, sustainAnimations=$sustainAnimations, '
			+ 'downscroll=$downscroll, vanillaStrumOffset=$vanillaStrumOffset, sustainClipping=$sustainClipping, '
			+ 'classicScoreTxt=$classicScoreTxt, ghostTapping=$ghostTapping, noteSplashes=$noteSplashes';
	}
}