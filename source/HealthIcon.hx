package;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxColor;
import haxe.Json;
import polymod.backends.PolymodAssets;
import funkin.backend.Paths;

/**
 * Health bar icon. Every icon is its own png at images/icons/icon-<name>.png: two frames side by side
 * (normal, losing), like Psych Engine. Mods add icons by putting a png in mods/<mod>/images/icons/.
 *
 * `char` can be a character id or an icon name. If a character json exists for it and has a "healthicon"
 * field, that field is the icon name; otherwise the name is just `char`. An icon that can't be found
 * falls back to icon-face, so there is always an animation to drive (PlayState sets curAnim.curFrame).
 */
class HealthIcon extends FlxSprite
{
	// The icon that is showing right now, after the character json lookup ('bf', 'bf-old', 'face', ...).
	public var iconName(default, null):String = "";

	var isPlayer:Bool;

	public function new(char:String = 'bf', isPlayer:Bool = false)
	{
		super();
		this.isPlayer = isPlayer;

		antialiasing = true;
		scrollFactor.set();

		changeIcon(char);
	}

	public function changeIcon(char:String):Void
	{
		var name:String = resolveName(char);
		var g:FlxGraphic = findGraphic(name);

		if (g == null)
		{
			trace('No icon "$name" (looked for ' + Paths.icon(name) + '), using face');
			name = 'face';
			g = findGraphic(name);
		}

		// loadGraphic resets the hitbox but not the scale; keep the scale (ChartingState shrinks its icons).
		var sx:Float = scale.x;
		var sy:Float = scale.y;

		if (g != null)
		{
			// Two frames side by side. A square image is a single-frame icon: show it for both states.
			var twoFrames:Bool = g.width >= g.height * 2;
			var frameW:Int = twoFrames ? Std.int(g.width / 2) : g.width;

			loadGraphic(g, true, frameW, g.height);
			animation.add('icon', twoFrames ? [0, 1] : [0, 0], 0, false, isPlayer);
		}
		else
		{
			// Not even icon-face.png. A grey square keeps the game running instead of a null crash.
			makeGraphic(150, 150, FlxColor.GRAY);
			animation.add('icon', [0, 0], 0, false, isPlayer);
		}

		animation.play('icon');
		iconName = name;

		scale.set(sx, sy);
		updateHitbox();
	}

	// "healthicon" from the character json if there is one, otherwise the name we were given.
	static function resolveName(char:String):String
	{
		var raw:String = null;

		// getText rather than exists(): Polymod's exists() has the same blind spot for mod-only files as
		// Assets.exists (see Paths.graphic). It can also throw for an id that isn't a character at all.
		try
		{
			raw = PolymodAssets.getText(Paths.character(char));
		}
		catch (e:Dynamic)
		{
			raw = null;
		}

		if (raw != null)
		{
			try
			{
				var json:Dynamic = Json.parse(raw);

				if (json.healthicon != null && json.healthicon != "")
					return Std.string(json.healthicon);
			}
			catch (e:Dynamic) {}
		}

		return char;
	}

	static function findGraphic(name:String):FlxGraphic
	{
		try
		{
			return Paths.graphic(Paths.icon(name));
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}
}
