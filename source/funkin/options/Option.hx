package funkin.options;

import flixel.FlxG;
import flixel.math.FlxMath;
import funkin.backend.ClientPrefs;

using StringTools;

enum OptionType
{
	// BOOL uses a checkbox, everything else uses a value label
	BOOL;
	INT;
	FLOAT;
	PERCENT;
	STRING;
}

class Option
{
	public var name:String;
	public var description:String = '';
	public var variable:String; // field name in ClientPrefs
	public var type:OptionType;
	public var defaultValue:Dynamic = null;

	public var onChange:Void->Void = null;

	// INT / FLOAT / PERCENT
	public var changeValue:Dynamic = 1; // how much one press changes
	public var minValue:Dynamic = null;
	public var maxValue:Dynamic = null;
	public var decimals:Int = 1; // FLOAT / PERCENT rounding

	// STRING
	public var options:Array<String> = null;
	public var curOption:Int = 0;

	public var displayFormat:String = '%v'; // %v = current value

	public function new(name:String, variable:String, type:OptionType = BOOL, ?options:Array<String>, description:String = '')
	{
		this.name = name;
		this.variable = variable;
		this.type = type;
		this.options = options;
		this.description = description;

		switch (type)
		{
			case BOOL:
				defaultValue = false;
			case INT, FLOAT:
				defaultValue = 0;
			case PERCENT:
				defaultValue = 1;
				changeValue = 0.01;
				minValue = 0;
				maxValue = 1;
				decimals = 2;
			case STRING:
				defaultValue = (options != null && options.length > 0) ? options[0] : '';
		}

		if (getValue() == null)
			setValue(defaultValue);

		if (type == STRING && options != null)
		{
			var num:Int = options.indexOf(getValue());
			if (num > -1)
				curOption = num;
		}
	}

	public function getValue():Dynamic
		return Reflect.field(ClientPrefs, variable);

	public function setValue(value:Dynamic):Void
	{
		Reflect.setField(ClientPrefs, variable, value);
		// also keeps prefs that ClientPrefs.saveSettings() doesn't know about alive
		Reflect.setField(FlxG.save.data, variable, value);
	}

	// dir: -1 / +1 for left / right (BOOL ignores it and just flips)
	public function step(dir:Int):Void
	{
		switch (type)
		{
			case BOOL:
				setValue(getValue() != true);

			case INT, FLOAT, PERCENT:
				var v:Float = getValue();
				var amount:Float = changeValue;
				v += dir * amount;

				if (minValue != null)
				{
					var lo:Float = minValue;
					if (v < lo)
						v = lo;
				}
				if (maxValue != null)
				{
					var hi:Float = maxValue;
					if (v > hi)
						v = hi;
				}

				if (type == INT)
					setValue(Math.round(v));
				else
					setValue(FlxMath.roundDecimal(v, decimals));

			case STRING:
				if (options == null || options.length == 0)
					return;
				curOption = (curOption + dir + options.length) % options.length;
				setValue(options[curOption]);
		}

		if (onChange != null)
			onChange();
	}

	// text shown next to the label (BOOL has none, the checkbox shows it)
	public function getDisplay():String
	{
		var v:Dynamic = getValue();
		var s:String = switch (type)
		{
			case BOOL: '';
			case INT: Std.string(Math.round(v));
			case FLOAT: Std.string(FlxMath.roundDecimal(v, decimals));
			// the alphabet sheet has no % glyph, so percent shows as a plain number (0-100)
			case PERCENT: Std.string(Math.round(v * 100));
			case STRING: Std.string(v);
		}
		return displayFormat.replace('%v', s);
	}
}
