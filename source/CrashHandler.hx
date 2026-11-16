
package;

import haxe.Exception;
import sys.io.File;
import sys.FileSystem;

class CrashHandler
{
    public static var hasCrashed:Bool = false;

    public static function handle(error:Dynamic):Void
    {
        if (hasCrashed)
            return;

        hasCrashed = true;

        var version:String = "Unknown";

        try
        {
            var configuredVersion = openfl.Lib.application.meta["version"];

            if (configuredVersion != null)
                version = Std.string(configuredVersion);
        }
        catch (e:Dynamic) {}

        var details:String = Std.string(error);

        if (Std.isOfType(error, Exception))
        {
            var exception:Exception = cast error;
            details = exception.details();
        }

        var report:String = "";

        report += "BEASTLOOP CRASH REPORT\n";
        report += "======================\n\n";
        report += 'Version: $version\n';
        report += 'Date: ${Date.now()}\n';
        report += 'Platform: Windows / HXCPP\n\n';
        report += "EXCEPTION\n";
        report += details;
        report += "\n";

        // HXCPP throws null refs as plain Strings (not haxe.Exception), so details()
        // never has a stack - grab it separately
        var stack:String = "";

        try
        {
            stack = haxe.CallStack.toString(haxe.CallStack.exceptionStack(true));
        }
        catch (e:Dynamic) {}

        if (stack != null && stack.length > 0)
        {
            report += "\nSTACK TRACE";
            report += stack;
            report += "\n";
        }

        var reportPath:String = "";

        try
        {
            var directory = "crash-reports";
        
            if (!FileSystem.exists(directory))
                FileSystem.createDirectory(directory);
        
            var filename = 'crash-${Date.now().getTime()}.txt';
        
            reportPath = '$directory/$filename';
        
            File.saveContent(reportPath, report);
        }
        catch (e:Dynamic)
        {
            Sys.println('Could not save crash report: ${Std.string(e)}');
        }
        
        Sys.println(report);
        
        WindowsCrashDialog.show(error, reportPath);
    }
}
