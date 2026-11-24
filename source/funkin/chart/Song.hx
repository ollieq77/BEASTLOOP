package funkin.chart;

import funkin.chart.Section.SwagSection;
import haxe.Json;
import haxe.format.JsonParser;
import openfl.utils.Assets;
import polymod.backends.PolymodAssets;
import funkin.backend.Paths;

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
		var key:String = Paths.songChart(song, difficulty);
		var rawJson:String = null;

		#if sys
		var diskPath:String = Paths.resolve(key);
		if (diskPath != null && diskPath != "" && sys.FileSystem.exists(diskPath))
		{
			rawJson = sys.io.File.getContent(diskPath);
		}
		#end

		if (rawJson == null)
		{
			rawJson = PolymodAssets.getText(key);
		}

		if (rawJson == null)
		{
			throw 'Chart file not found for song "$song" ($difficulty).';
		}

		// Only slice if there is actually trailing junk after the last '}'
		var trimmed:String = StringTools.trim(rawJson);
		if (!StringTools.endsWith(trimmed, "}"))
		{
			var lastBrace:Int = trimmed.lastIndexOf("}");
			if (lastBrace != -1)
			{
				rawJson = trimmed.substr(0, lastBrace + 1);
			}
		}
		else
		{
			rawJson = trimmed;
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
