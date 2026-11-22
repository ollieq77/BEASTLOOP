
package funkin.game;

import flixel.FlxG;
import flixel.FlxSprite;
import funkin.backend.Paths;

class NoteSplash extends FlxSprite
{
    public function new(x:Float = 0, y:Float = 0)
    {
        super(x, y);

        frames = Paths.sparrow('gameplay/NOTESPLASH_assets');

        // Impact 1
        animation.addByPrefix('note1-0', 'note impact 1 blue', 24, false);
        animation.addByPrefix('note2-0', 'note impact 1 green', 24, false);
        animation.addByPrefix('note0-0', 'note impact 1 purple', 24, false);
        animation.addByPrefix('note3-0', 'note impact 1 red', 24, false);

        // Impact 2
        animation.addByPrefix('note1-1', 'note impact 2 blue', 24, false);
        animation.addByPrefix('note2-1', 'note impact 2 green', 24, false);
        animation.addByPrefix('note0-1', 'note impact 2 purple', 24, false);
        animation.addByPrefix('note3-1', 'note impact 2 red', 24, false);
    }

    public function setupNoteSplash(x:Float, y:Float, noteData:Int = 0):Void
    {
        revive();

        setPosition(x, y);
        alpha = 0.6;
        visible = true;
        active = true;

        animation.stop();
        animation.play(
            'note' + (noteData % 4) + '-' + FlxG.random.int(0, 1),
            true
        );

        updateHitbox();
        offset.set(width * 0.3, height * 0.3);
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (animation.curAnim != null && animation.curAnim.finished)
            kill();
    }
}
