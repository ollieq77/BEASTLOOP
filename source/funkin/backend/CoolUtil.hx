package funkin.backend;

import openfl.utils.Assets;
import polymod.backends.PolymodAssets;

using StringTools;

class CoolUtil
{
	public static function coolTextFile(path:String):Array<String>
	{
		var daList:Array<String> = PolymodAssets.getText(path).trim().split('\n');

		for (i in 0...daList.length)
		{
			daList[i] = daList[i].trim();
		}

		return daList;
	}

	public static function numberArray(max:Int, ?min = 0):Array<Int>
	{
		var dumbArray:Array<Int> = [];
		for (i in min...max)
		{
			dumbArray.push(i);
		}
		return dumbArray;
	}

	public static function formatNumber(number:Float):String
	{
    	var parts = Std.string(Math.round(number)).split('');
    	var result:String = '';
		
    	for (i in 0...parts.length)
    	{
    	    if (i > 0 && (parts.length - i) % 3 == 0)
    	        result += ',';
		
    	    result += parts[i];
    	}
	
    	return result;
	}
}
