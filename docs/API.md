# API Documentation


## Functions

### `new`

Initializes the StageAPI instance with the active stage reference. 

```haxe
function new(stage:Stage):Void
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `stage` | The active Stage instance being managed. |

---

### `setCharacters`

Assigns the main character instances (Boyfriend, Opponent, and Girlfriend) to the API. 

```haxe
function setCharacters(boyfriend:Boyfriend, dad:Character, gf:Character):Void
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `boyfriend` | The player character instance. |
| `dad` | The opponent character instance. |
| `gf` | The girlfriend character instance. |

---

### `getCharacter`

Retrieves a specific character instance by their string identifier name (case-insensitive). 

```haxe
function getCharacter(name:String):Character
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `name` | The string name of the character ("boyfriend", "dad", or "gf"). |

---

### `setCameras`

Sets up the game and HUD cameras, initializing the internal CameraAPI wrapper. 

```haxe
function setCameras(game:FlxCamera, hud:FlxCamera):Void
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `game` | The main gameplay FlxCamera instance. |
| `hud` | The user interface / HUD FlxCamera instance. |

---

### `getSprite`

Gets a specific FlxSprite from the stage by its name. 

```haxe
function getSprite(name:String):FlxSprite
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `name` | The string identifier of the sprite. |

---

### `getObject`

Gets a generic FlxBasic object from the stage by its name. 

```haxe
function getObject(name:String):FlxBasic
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `name` | The string identifier of the object. |

---

### `addObject`

Adds a basic object to the stage with an assigned name identifier. 

```haxe
function addObject(object:FlxBasic, name:String):Void
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `object` | The FlxBasic object instance to add. |
| `name` | The string identifier key for the object. |

---

### `randomInt`

Returns a random integer between min and max (inclusive). 

```haxe
function randomInt(min:Int, max:Int):Int
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `min` | The minimum integer bound. |
| `max` | The maximum integer bound. |

---

### `randomBool`

Returns true or false based on a given percentage chance (0 to 100). 

```haxe
function randomBool(chance:Float):Bool
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `chance` | The success probability percentage (0 to 100). |

---

### `setGfSpeed`

Sets the dancing/animation speed multiplier for Girlfriend. 

```haxe
function setGfSpeed(value:Int):Void
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `value` | The speed factor integer. |

---

### `setVocalsVolume`

Adjusts the volume level of the song vocals dynamically. 

```haxe
function setVocalsVolume(value:Float):Void
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `value` | The target volume level (0.0 to 1.0). |

---

### `setMusicVolume`

Adjusts the volume level of the instrumental music track dynamically. 

```haxe
function setMusicVolume(value:Float):Void
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `value` | The target volume level (0.0 to 1.0). |

---

### `setCamZooming`

Enables or disables automatic camera zooming on beat hits. 

```haxe
function setCamZooming(value:Bool):Void
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `value` | True to enable beat zooming, false to disable. |

---

### `addCameraZoom`

Adds an instant zoom offset to both the game and HUD cameras. 

```haxe
function addCameraZoom(game:Float, hud:Float):Void
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `game` | The zoom value modifier for the game camera. |
| `hud` | The zoom value modifier for the HUD camera. |

---

### `get_camZooming`

Getter for the current camera zooming status (whether zoom on beat is active). 

```haxe
function get_camZooming():Bool
```

---

### `loadDialogue`

Loads a dialogue script/file into the game state. 

```haxe
function loadDialogue(file:String):Void
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `file` | The filename or path of the dialogue asset. |

---

### `playSound`

Plays a sound effect through the sound manager. 

```haxe
function playSound(key:String, volume:Float = 1, ?onComplete:Dynamic):Void
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `key` | A sound name like 'carPass0' (resolved through Paths.sound) or a full path. |
| `volume` | The playback volume level, default is 1.0. |
| `onComplete` | Optional callback function triggered when the sound finishes playing. |

---

### `playMusic`

Starts a music track and fades it in. 

```haxe
function playMusic(key:String, volume:Float = 1, fadeInSeconds:Float = 0):Void
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `key` | The music track name like 'Lunchbox', resolved through Paths.music. |
| `volume` | The target playback volume level. |
| `fadeInSeconds` | Duration in seconds for the music to fade in (0 for instant). |

---

### `soundPath`

Resolves the full path for a sound key, for scripts that need to load one themselves. 

```haxe
function soundPath(key:String):String
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `key` | The sound name or full asset path. |

---

### `imagePath`

Resolves the path for an image key (e.g., 'weeb/senpaiCrazy' with no extension). 

```haxe
function imagePath(key:String):String
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `key` | The image asset key. |

---

### `addToState`

---- State access (draws above the stage and the characters) ---- Adds a custom object directly to the active PlayState so it renders above characters and stage elements. 

```haxe
function addToState(object:FlxBasic):Void
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `object` | The FlxBasic object instance to add to the state. |

---

### `removeFromState`

Removes an object from the active PlayState. 

```haxe
function removeFromState(object:FlxBasic):Void
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `object` | The FlxBasic object instance to remove from the state. |

---

### `startCountdown`

---- Intro / cutscene control ---- Triggers the gameplay countdown sequence to begin. 

```haxe
function startCountdown():Void
```

---

### `setInCutscene`

Sets whether the game is currently in a cutscene state (disabling inputs/gameplay elements). 

```haxe
function setInCutscene(value:Bool):Void
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `value` | True to enter cutscene mode, false to exit. |

---

### `makeSolid`

---- Helpers so scripts don't need FlxColor / FlxEase / FlxTimer ---- Creates a solid colour rectangle sprite. 

```haxe
function makeSolid(x:Float, y:Float, width:Int, height:Int, color:Int):FlxSprite
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `x` | The X position coordinate. |
| `y` | The Y position coordinate. |
| `width` | The pixel width of the rectangle. |
| `height` | The pixel height of the rectangle. |
| `color` | The color hex value (formatted as 0xAARRGGBB). |

---

### `makeImage`

Creates a sprite with a single image loaded from assets/images. 

```haxe
function makeImage(x:Float, y:Float, key:String):FlxSprite
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `x` | The X position coordinate. |
| `y` | The Y position coordinate. |
| `key` | The image name under assets/images, e.g. 'weeb/spiritFaceForward'. |

---

### `makeSparrow`

Creates a sprite with a Sparrow sprite sheet atlas loaded. 

```haxe
function makeSparrow(x:Float, y:Float, key:String):FlxSprite
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `x` | The X position coordinate. |
| `y` | The Y position coordinate. |
| `key` | The shared png/xml asset name under assets/images, e.g. 'weeb/senpaiCrazy'. |

---

### `timer`

Starts a timer with a callback function. The callback receives the FlxTimer so it can call tmr.reset(...). 

```haxe
function timer(seconds:Float, callback:Dynamic, loops:Int = 1):FlxTimer
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `seconds` | Duration of the timer in seconds. |
| `callback` | Function called when the timer fires or loops. |
| `loops` | Number of times the timer should repeat (defaults to 1). |

---

### `tween`

Creates a property tween animation. 

```haxe
function tween(target:Dynamic, values:Dynamic, duration:Float, ease:String = "linear", ?onComplete:Dynamic):FlxTween
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `target` | The object or structure being tweened. |
| `values` | An anonymous object containing target properties and end values. |
| `duration` | Duration of the tween in seconds. |
| `ease` | The easing function name (e.g., linear, quadIn/Out, cubeIn/Out, sineIn/Out). |
| `onComplete` | Optional callback function triggered when the tween finishes. |

---

### `getEase`

Resolves a string ease name into its corresponding FlxEase function reference. 

```haxe
function getEase(name:String):Float
```

**Parameters:**

| Parameter | Description |
| :--- | :--- |
| `name` | The string identifier name of the ease function. |

---

### `get_soundExt`

Getter that returns the audio file extension format used by the title state/game settings. 

```haxe
function get_soundExt():String
```

---

