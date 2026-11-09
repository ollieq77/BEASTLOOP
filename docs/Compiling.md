# COMPILING

Now you may ask. How do I actually compile this god damn engine?

Well, for Windows users, it's really simple.

In `./art/`, you'll find a script called `firstTimeSetup.ps1`. This will install all the shit you need to compile this thing.

Open a PowerShell terminal in the **project's root directory** and run:

```powershell
.\art\firstTimeSetup.ps1
```

This will install around... 4GB of crap. It's all essential to getting this up and running.

Once setup has completed, you can compile BEASTLOOP by running:

```powershell
haxelib run lime test windows -debug
```
This will take a while to complete on the first time you run this.

## "But I don't use windows!"
Okay, this may be harder, but still possible.

## Dependencies

Before compiling BEASTLOOP, you'll need to install the following.

### Required software

- **[Haxe 4.2.5](https://haxe.org/download/)** - The programming language BEASTLOOP is written in.
- **Haxelib** - Haxe's package manager. This is included with Haxe.
- **[Git](https://git-scm.com/downloads)** - Required for retrieving Git-based dependencies.

### Windows-specific requirements

If you're compiling on Windows, you'll also need:

- **[Visual Studio 2022 Build Tools](https://visualstudio.microsoft.com/downloads/)** 
  - MSVC v143 C++ build tools (x86/x64).
  - Windows 11 SDK (10.0.26100.0).

### Haxelibs

BEASTLOOP uses the following Haxelibs. Make sure you're using the specified versions.

| Library | Version |
|---|---|
| `lime` | `7.9.0` |
| `openfl` | `9.1.0` |
| `hxcpp` | `4.2.1` |
| `flixel` | `4.11.0` |
| `flixel-addons` | `2.11.0` |
| `flixel-ui` | `2.3.3` |
| `hscript` | `2.4.0` |
| `newgrounds` | `1.1.5` |
| `haxeui-core` | `1.7.0` |
| `haxeui-flixel` | `1.7.0` |
| `polymod` | Git commit `3204f48` |

These versions are pinned to the ones currently used by BEASTLOOP.

## "But I don't use Windows!"

Okay, this may be a little harder, but it's still possible!

Unlike Windows, there is currently no automated setup script for Linux or macOS. You'll need to install a few additional dependencies manually.

### Linux

For Linux, you'll need:

- **Haxe 4.2.5**
- **Git**
- **G++** – The GNU C++ compiler.
- **Make** – Used by the native build process.

Most Linux distributions already have some of these installed. If G++ isn't available, install it through your distribution's package manager.

Once everything is installed, make sure you've also installed the Haxelibs listed in the Dependencies section above.

To compile and launch BEASTLOOP, run:

```bash
haxelib run lime test linux -debug
```

### macOS

For macOS, you'll need:

- **Haxe 4.2.5**
- **Git**
- **Xcode** – Required for its native C++ compiler and development tools.

You can install Xcode through the Mac App Store.

Once everything is installed, make sure you've also installed the Haxelibs listed in the Dependencies section above.

To compile and launch BEASTLOOP, run:

```bash
haxelib run lime test mac -debug
```

### A few things to keep in mind

- Your first compilation will take considerably longer than subsequent builds.
- Make sure you're using the exact Haxelib versions listed above.
- Native desktop builds are intended to be compiled on their respective operating systems. Linux builds require Linux, and macOS builds require macOS.