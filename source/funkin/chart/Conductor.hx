package funkin.chart;

class Conductor
{
	public static var bpm:Int = 100;
	public static var crochet:Float = ((60 / bpm) * 1000); // beats in milliseconds
	public static var stepCrochet:Float = crochet / 4; // steps in milliseconds
	public static var songPosition:Float;
	public static var lastSongPos:Float;
	public static var offset:Float = 0;

	// V-Slice hit windows (in milliseconds)
	public static var sickWindow:Float = 45.0;
	public static var goodWindow:Float = 90.0;
	public static var badWindow:Float = 135.4;
	public static var shitWindow:Float = 180.0;

	public static var safeFrames:Int = 10;
	public static var safeZoneOffset:Float = shitWindow;

	public function new()
	{
	}

	public static function changeBPM(newBpm:Int)
	{
		if (newBpm <= 0)
			return;

		bpm = newBpm;

		crochet = ((60 / bpm) * 1000);
		stepCrochet = crochet / 4;
	}
}