# Modding
This engine supports modding with adding custom songs, weeks, and a whole lot of other things.

## Making your first mod
You want to make a mod for this engine? Go for it! You jsut need to define the correct file structure for polymod to actually load it. So here are the steps you need to take. Here's what I would do as a first time.

```
mods/
└── MyCoolMod/
    ├── data/
    ├── fonts/
    ├── images/
    ├── music/
    ├── songs/
    ├── sounds/
    ├── weeks/
    └── _polymod_meta.json
```
Not every folder is optional, but is required if you want to mod everything possible. So lets go over what you need to put in each file/folder!

## Breaking Down the Files
### `_polymod_meta.json`
This is *ESSENTIAL* for your mod to actually load. If the game can't find this file, your mod won't load. Let's go over what it should look like.
```json
{
    "title": "super epic mod",
    "description": "adds super epic things",
    "author": "me",
    "api_version": "1.0.0",
    "mod_version": "1.0.0"
}
```
What does everything do, you may ask? Let's break it down.
- `title` - The name of your mod.
- `description` - What does this mod do?
- `author` - Who created this mod? (enter your own name!)
- `api_version` - Not sure where this is used.
- `mod_version` - What version is this mod?

Everything here is required for polymod to actually recognise and load your mod.
### `data`
The data folder. This is where configurations, characters, stages, etc go. Lets break down its directory tree. (as of writing this)
- `characters` - The character JSON files that define what a character does.
- `stages` - Your stage data. This also allows stagescripts, which are loaded when that stage loads.
- `weeks` - The week data, what displays in freeplay and story mode.

### `images`
The visuals hub. If you're adding custom characters, stage backgrounds, user interface elements, or health icons, they all go in here. To keep things clean, you'll usually want to structure it like this:
- `characters` - Spritesheets (`.png`) and coordinate atlases (`.xml`) for your playable characters, opponents, and girlfriends.
- `stages` - Background art and layer graphics for your custom stages.
- `gameplay` - Assets used in game.
- `menus` - Assets used in the menus.
- `title` - Assets used in the title screen.
- `weeb` - Stuff used in Week 6.

### `songs`
Where the actual playable music lives. Each song needs its own isolated folder named *strictly* after the song's internal ID (lowercase, no spaces). 
Inside each song folder, you'll need:
- `Inst.ogg` - The instrumental audio track.
- `Voices.ogg` - The vocal track (if your characters actually sing).
- `easy/normal/hard.json` - The actual chart file. This is where the notes live.
- `song.hxc` - OPTIONAL! This is a song script that loads when the song loads.

### `music`
Where the menu music lives. Quite self explanatory. Lets have a quick runthrough of the files.

- `breakfast.ogg` - The Chill Menu / Pause Menu music track.
- `freakyMenu.ogg` - The main menu background theme.
- `gameOver.ogg` / `.mp3` - Plays when the player loses/dies.
- `gameOverEnd.ogg` / `.mp3` - Plays when exiting the game over screen back to the menu.
- `gameOver-pixel.ogg` / `.mp3` - The pixelated/retro variant of the game over track.
- `gameOverEnd-pixel.ogg` / `.mp3` - The pixelated variant of the game over ending track.
- `Lunchbox.ogg` - Cutscene/dialogue music track used in week 6.
- `LunchboxScary.ogg` - Ditto, but EVIL.
- `title.ogg` / `.mp3` - The classic title screen music.
- `titleShoot.ogg` / `.mp3` - Plays during the title screen when you press enter/click.
- `music-goes-here.txt` - A placeholder text file telling you where to drop your files. (You can safely ignore or delete this!)

### `music`
All the sound effects. Not going through this, most are self explanatory.

Thats it for the folders, lets dive into scripting!

## Scripting
This engine uses `.hxc` files that are loaded. Lets dive into what types we have.
- Song Scripts - These live in the songs folder, and loads when the song loads.
- Stage Scripts - These live in the stage folder, and can be used for background characters or dancers.

There is API documentation for all of this, which you can find ([Here](API.md)).

Now. What does a script look like? Let's grab an example and rummage through it all.

```hx
var evilTrail:Dynamic;

function onCreatePost():Void
{
    // Load Thorns dialogue.
    api.loadDialogue("thornsDialogue.txt");

    // Trail behind the opponent.
    var dad = api.getCharacter("dad");

    evilTrail = Type.createInstance(FlxTrail, [dad, null, 4, 24, 0.3, 0.069]);

    api.addObject(evilTrail, "evilTrail");
}

function onDialogueCreate(dialogueBox)
{
    api.playMusic('LunchboxScary', 0.8, 1);
    dialogueBox.fadeOutMusicOnEnd = true;

    dialogueBox.setBox('weeb/pixelUI/dialogueBox-evil', 'Spirit Textbox spawn', 11);
    dialogueBox.setColors(0xFF000000, 0xFFFFFFFF, 0xFF000000);

    var face = api.makeImage(320, 170, 'weeb/spiritFaceForward');
    face.setGraphicSize(Std.int(face.width * 6));
    dialogueBox.addBehindBox(face);
}

function onIntro(dialogueBox):Bool
{
    if (!isStoryMode)
        return false;

    var red = api.makeSolid(-100, -100, FlxG.width * 2, FlxG.height * 2, 0xFFFF1B31);
    red.scrollFactor.set();
    api.addToState(red);

    var senpaiEvil = api.makeSparrow(0, 0, 'weeb/senpaiCrazy');
    senpaiEvil.animation.addByPrefix('idle', 'Senpai Pre Explosion', 24, false);
    senpaiEvil.setGraphicSize(Std.int(senpaiEvil.width * daPixelZoom));
    senpaiEvil.updateHitbox();
    senpaiEvil.screenCenter();

    var fade = 1.0;

    api.timer(0.3, function(tmr)
    {
        fade -= 0.15;

        if (fade > 0)
        {
            tmr.reset(0.3);
            return;
        }

        if (dialogueBox == null)
        {
            api.startCountdown();
            return;
        }

        api.setInCutscene(true);

        api.addToState(senpaiEvil);
        senpaiEvil.alpha = 0;

        api.timer(0.3, function(swagTimer)
        {
            senpaiEvil.alpha += 0.15;

            if (senpaiEvil.alpha < 1)
            {
                swagTimer.reset();
            }
            else
            {
                senpaiEvil.animation.play('idle');

                api.playSound('Senpai_Dies', 1, function()
                {
                    api.removeFromState(senpaiEvil);
                    api.removeFromState(red);

                    FlxG.camera.fade(0xFFFFFFFF, 0.01, true, function()
                    {
                        api.addToState(dialogueBox);
                    }, true);
                });

                api.timer(3.2, function(deadTime)
                {
                    FlxG.camera.fade(0xFFFFFFFF, 1.6, false);
                });
            }
        });
    });

    return true;
}
```

Let's break down how this example script uses the API and hooks into the game lifecycle:

### 1. `onCreatePost()`
This function runs right after the game state has finished its basic initialization. 
- **`api.loadDialogue("thornsDialogue.txt");`** - Tells the engine to load a custom dialogue text file when starting up the sequence.
- **`api.getCharacter("dad");`** - Fetches a reference to the opponent character object so we can modify it or attach effects.
- **`Type.createInstance(FlxTrail, [...])`** - A standard Haxe feature used here to create a glowing motion trail behind the opponent.
- **`api.addObject(evilTrail, "evilTrail");`** - Adds the trail object back into the stage tracking list via the API.

### 2. `onDialogueCreate(dialogueBox)`
Triggered when the dialogue box is instantiated, allowing you to customize its text, appearance, and audio.
- **`api.playMusic('LunchboxScary', 0.8, 1);`** - Fades in the creepy dialogue music track over 1 second at 80% volume.
- **`dialogueBox.setBox(...)`** - Configures custom UI asset paths and animation prefixes for the dialogue box graphic.
- **`api.makeImage(...)`** - Spawns a background image element (like the floating Spirit face) and offsets its scale before injecting it behind the box using `dialogueBox.addBehindBox(face)`.

### 3. `onIntro(dialogueBox)`
Controls custom cutscene logic right before the countdown begins in Story Mode.
- **`isStoryMode`** - Checks whether the player is currently playing through Story Mode rather than Freeplay.
- **`api.makeSolid(...)`** & **`api.makeSparrow(...)`** - Spawns a full-screen red tint overlay rectangle and a custom animated Sparrow sprite sheet asset (`senpaiCrazy`).
- **`api.timer(...)`** - Uses the API's built-in asynchronous timer helper to handle timed alpha-fading, cutscene sequencing, and delayed sound triggers without writing manual frame-delta math.
- **`api.playSound('Senpai_Dies', 1, ...)`** - Plays an SFX and queues up a callback function to clean up assets from the state (`api.removeFromState`) once the sound finishes.