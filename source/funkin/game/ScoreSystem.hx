package funkin.game;

class ScoreSystem
{
    public var songScore:Int = 0;

    public var totalPlayed:Int = 0;
    public var totalNotesHit:Float = 0;

    public var misses:Int = 0;

    public var sick:Int = 0;
    public var good:Int = 0;
    public var bad:Int = 0;
    public var shit:Int = 0;

    public var ratingPercent(get, never):Float;

    function get_ratingPercent():Float
    {
        if (totalPlayed <= 0)
            return 1;

        return totalNotesHit / totalPlayed;
    }

    public function new()
    {
        reset();
    }

    public function addRating(rating:String):Void
    {
        var ratingMod:Float = 0;
        var score:Int = 0;

        switch (rating)
        {
            case "sick":
                ratingMod = 1.0;
                score = 350;
                sick++;

            case "good":
                ratingMod = 0.75;
                score = 200;
                good++;

            case "bad":
                ratingMod = 0.5;
                score = 100;
                bad++;

            case "shit":
                ratingMod = 0.25;
                score = 50;
                shit++;
        }

        totalPlayed++;
        totalNotesHit += ratingMod;
        songScore += score;
    }

    public function addMiss():Void
    {
        totalPlayed++;
        misses++;
    }

    public function reset():Void
    {
        songScore = 0;

        totalPlayed = 0;
        totalNotesHit = 0;

        misses = 0;

        sick = 0;
        good = 0;
        bad = 0;
        shit = 0;
    }
}