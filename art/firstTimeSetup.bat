@echo off
REM Run this from the ROOT of your BEASTLOOP clone (same folder as Project.xml).
REM It makes a LOCAL .haxelib folder so these old, pinned versions do NOT
REM touch the global libs your other FNF engines use (Codename / Psych etc).
REM i also have no idea why the fuck apistuff.hx is missing from the repo, so this copies it in if it's not there

if not exist Project.xml (
  echo Run this from the BEASTLOOP root folder, bestie.
  exit /b 1
)

if not exist source\APIStuff.hx (
  copy /Y "%~dp0APIStuff.hx" source\APIStuff.hx
)

haxelib newrepo

haxelib install lime 7.9.0
haxelib install openfl 9.1.0
haxelib install hxcpp 4.2.1
haxelib install flixel 4.11.0
haxelib install flixel-addons 2.11.0
haxelib install flixel-ui 2.3.3
haxelib install hscript 2.4.0
haxelib install newgrounds 1.1.5
haxelib git polymod https://github.com/larsiusprime/polymod.git 3204f48

echo.
echo Installed into local .haxelib:
haxelib list
echo.
echo Now try:  haxelib run lime test html5 -debug