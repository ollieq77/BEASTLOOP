package;

import polymod.backends.PolymodAssets;

class Paths
{
    public static inline function resolve(path:String):String
        return PolymodAssets.getPath(path);

    public static inline function image(key:String):String
        return 'assets/images/$key.png';

    public static inline function sound(key:String):String
        return 'assets/sounds/$key.ogg';

    public static inline function music(key:String):String
        return 'assets/music/$key.ogg';

    public static inline function song(song:String):String
        return 'assets/songs/${song.toLowerCase()}/';

    public static inline function songChart(song:String, difficulty:String):String
        return Paths.song(song) + '${difficulty.toLowerCase()}.json';

    public static inline function inst(song:String):String
        return Paths.song(song) + 'Inst${TitleState.soundExt}';
    
    public static inline function voices(song:String):String
        return Paths.song(song) + 'Voices${TitleState.soundExt}';
}