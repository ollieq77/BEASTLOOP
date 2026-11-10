package;

import Section.SwagSection;
import haxe.Json;
import haxe.format.JsonParser;
import openfl.utils.Assets;
import polymod.backends.PolymodAssets;

using StringTools;

typedef SwagSong =
{
    var song:String;
    var notes:Array<SwagSection>;
    var bpm:Int;
    var sections:Int;
    var sectionLengths:Array<Dynamic>;
    var needsVoices:Bool;
    var speed:Float;

    @:optional var stage:String;
	@:optional var gfVersion:String;

    var player1:String;
    var player2:String;
    var validScore:Bool;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var bpm:Int;
	public var sections:Int;
	public var sectionLengths:Array<Dynamic> = [];
	public var needsVoices:Bool = true;
	public var speed:Float = 1;
	public var stage:String = 'stage';

	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';

	public function new(song, notes, bpm, sections)
	{
		this.song = song;
		this.notes = notes;
		this.bpm = bpm;
		this.sections = sections;

		for (i in 0...notes.length)
		{
			this.sectionLengths.push(notes[i]);
		}
	}

	public static function loadFromJson(difficulty:String, song:String):SwagSong
	{
	    var rawJson = PolymodAssets.getText(Paths.songChart(song, difficulty)).trim();

	    while (!rawJson.endsWith("}"))
	    {
	        rawJson = rawJson.substr(0, rawJson.length - 1);
	    }

	    return parseJSONshit(rawJson);
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		var swagShit:SwagSong = cast Json.parse(rawJson).song;
		swagShit.validScore = true;

		if (swagShit.stage == null || swagShit.stage.length == 0)
    		swagShit.stage = 'stage';
		return swagShit;
	}
}
