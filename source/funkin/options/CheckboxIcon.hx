package funkin.options;

import flixel.FlxSprite;
import funkin.backend.Paths;

class CheckboxIcon extends FlxSprite
{
	public var checked(default, null):Bool = false;

	// Starting offsets taken from the atlas pivots. If a state looks nudged, tweak it here.
	static final OFFSETS:Map<String, Array<Float>> = [
		'unchecked' => [0, 0],
		'checking' => [0, 0],
		'unchecking' => [0, 0],
		'checked' => [0, 0]
	];

	static inline var BASE_SCALE:Float = 0.6;

	public function new(checked:Bool)
	{
		super();
		frames = Paths.sparrow('menus/optionsmenu/checkboxanim');
		antialiasing = true;

		animation.addByPrefix('unchecked', 'checkbox0000', 24, false);
		animation.addByPrefix('checking', 'checkbox anim0', 24, false);
		animation.addByPrefix('unchecking', 'checkbox anim reverse', 24, false);
		animation.addByPrefix('checked', 'checkbox finish', 24, false);

		animation.finishCallback = function(name:String)
		{
			if (name == 'checking')
				playAnim('checked');
			else if (name == 'unchecking')
				playAnim('unchecked');
		};

		this.checked = checked;
		playAnim(checked ? 'checked' : 'unchecked');
	}

	// no-op if the value didn't change, so it's safe to call every time
	public function setChecked(value:Bool):Void
	{
		if (value == checked)
			return;
		checked = value;
		playAnim(value ? 'checking' : 'unchecking');
	}

	function playAnim(name:String):Void
	{
		animation.play(name, true);
		scale.set(BASE_SCALE, BASE_SCALE);
		updateHitbox(); // resets offset, so set it after
		var o = OFFSETS.get(name);
		offset.set(o[0] * BASE_SCALE, o[1] * BASE_SCALE);
	}
}
