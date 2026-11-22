package funkin.backend;

import flixel.FlxG;
import flixel.util.FlxSave;

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

    public static function saveSettings():Void
    {
        FlxG.save.data.botPlay = botPlay;
        FlxG.save.data.opponentNoteFlashes = opponentNoteFlashes;
        FlxG.save.data.sustainAnimations = sustainAnimations;
        FlxG.save.data.downscroll = downscroll;
        FlxG.save.data.vanillaStrumOffset = vanillaStrumOffset;
        FlxG.save.data.sustainClipping = sustainClipping;
        FlxG.save.data.classicScoreTxt = classicScoreTxt;
        FlxG.save.data.ghostTapping = ghostTapping;
        FlxG.save.data.noteSplashes = noteSplashes;

        FlxG.save.flush();
    }

    public static function loadPrefs():Void
    {
        if (FlxG.save.data.botPlay != null)
            botPlay = FlxG.save.data.botPlay;

        if (FlxG.save.data.opponentNoteFlashes != null)
            opponentNoteFlashes = FlxG.save.data.opponentNoteFlashes;

        if (FlxG.save.data.sustainAnimations != null)
            sustainAnimations = FlxG.save.data.sustainAnimations;

        if (FlxG.save.data.downscroll != null)
            downscroll = FlxG.save.data.downscroll;

        if (FlxG.save.data.vanillaStrumOffset != null)
            vanillaStrumOffset = FlxG.save.data.vanillaStrumOffset;

        if (FlxG.save.data.sustainClipping != null)
            sustainClipping = FlxG.save.data.sustainClipping;

        if (FlxG.save.data.classicScoreTxt != null)
            classicScoreTxt = FlxG.save.data.classicScoreTxt;

        if (FlxG.save.data.ghostTapping != null)
            ghostTapping = FlxG.save.data.ghostTapping;

        if (FlxG.save.data.noteSplashes != null)
            noteSplashes = FlxG.save.data.noteSplashes;
    }
}