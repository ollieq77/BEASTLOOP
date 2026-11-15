
package;

import haxe.Exception;
import haxe.CallStack;

@:cppFileCode('
#include <windows.h>
#include <string>
#pragma comment(lib, "User32.lib")

static void beastloopShowWindowsCrashDialog(const char* text)
{
    int length = MultiByteToWideChar(
        CP_UTF8, 0, text, -1, NULL, 0
    );

    if (length <= 0)
        return;

    std::wstring wideText(length, L\'\\0\');

    MultiByteToWideChar(
        CP_UTF8, 0, text, -1, &wideText[0], length
    );

    MessageBoxW(
        NULL,
        wideText.c_str(),
        L"BEASTLOOP - FATAL ERROR!",
        MB_OK | MB_ICONERROR
    );
}
')
class WindowsCrashDialog
{
    public static function show(error:Dynamic, reportPath:String):Void
    {
        var message:String = Std.string(error);
        var stack:String = "";

        if (Std.isOfType(error, Exception))
        {
            var exception:Exception = cast error;

            message = exception.message;

            var frames = CallStack.toString(exception.stack).split("\n");

            while (frames.length > 0 && StringTools.trim(frames[frames.length - 1]) == "")
                frames.pop();

            var firstFrame = Std.int(Math.max(0, frames.length - 3));
            frames = frames.slice(firstFrame);

            stack = frames.join("\n");
        }

        var dialog = "BEASTLOOP has encountered an unexpected exception.\n\n"
            + "Something went wrong internally and the game needs to close.\n\n"
            + "Please report this issue and include the crash report below.";
        
        if (stack != "")
            dialog += '\n\n$stack';

        if (reportPath != "")
            dialog += '\n\nReport: $reportPath';

        showNative(dialog);

        #if cpp
        Sys.exit(1);
        #end
    }

    @:functionCode('
        beastloopShowWindowsCrashDialog(message.utf8_str());
    ')
    private static function showNative(message:String):Void {}
}
