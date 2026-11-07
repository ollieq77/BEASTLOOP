
package;

import flixel.FlxCamera;

class CameraAPI
{
    public var game:FlxCamera;
    public var hud:FlxCamera;

    public function new(game:FlxCamera, hud:FlxCamera)
    {
        this.game = game;
        this.hud = hud;
    }

    public function setZoom(zoom:Float, camera:String = "game"):Void
    {
        getCamera(camera).zoom = zoom;
    }

    public function setAngle(angle:Float, camera:String = "game"):Void
    {
        getCamera(camera).angle = angle;
    }

    public function shake(intensity:Float, duration:Float, camera:String = "game"):Void
    {
        getCamera(camera).shake(intensity, duration);
    }

    public function flash(color:Int, duration:Float, camera:String = "game"):Void
    {
        getCamera(camera).flash(color, duration);
    }

    public function fade(color:Int, duration:Float, camera:String = "game"):Void
    {
        getCamera(camera).fade(color, duration);
    }

    function getCamera(camera:String):FlxCamera
    {
        return switch (camera.toLowerCase())
        {
            case "game": game;
            case "hud": hud;
            default: game;
        }
    }
}
