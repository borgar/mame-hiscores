# MAME highscore saving

This uses MAME's [built-in Lua scripting](https://github.com/mamedev/mame/blob/master/docs/luaengine.md) to provide high-score saving with the standard *hiscore.dat* file just as older versions did before the feature was removed.

Because this uses MAME's built in scripting language it means you can now save hiscores on a modern default build without having to go through the work of patching it.

**Warning:** This does not take game reset into account, only loading. So resetting the game via MAME interface *may overwrite your highscores*!

## Be aware that ...

* MAME's scripting internals are not yet finalized and they may change so that this script breaks.

* This script only works on recent MAME releases, probably versions 0.154 or newer (I'm guessing here).

* You will need to be running MAME from a command line interface or have a way to add extra arguments to it.


## How to use

1. Place `hiscore.lua` in an accessible directory (such as `~/.mame/`). 

2. Download and extract a fresh copy of *hiscore.dat* (from [highscore.mameworld.info](http://highscore.mameworld.info/)) and place it in an accessible directory (such as `~/.mame/`). 

3. Run MAME with the script active:

        $ mame dkong -autoboot_delay 0 -autoboot_script ~/.mame/hiscore.lua
       
   The `-autoboot_script ~/.mame/hiscore.lua` tells MAME to run our script. And the `-autoboot_delay 0` tells MAME to run it immedately. I don't know why the default is 2 seconds which will cause a visible change in the games if they boot immediately to a visible highscore. 

The script should create the directory `~/.mame/hi/` and place its highscore save files there (so `~/.mame/hi/dkong.hi` in the example above).

These might be compatible with older verions but I've never tested it so no guarantees.

If you don't like the default file paths (`$HOME/.mame/hiscore.dat`, and `$HOME/.mame/hi`) you will have to edit the script. The paths are up top and the `$HOME` magic variable works.
